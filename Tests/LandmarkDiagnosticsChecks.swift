// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

@main struct LandmarkDiagnosticsChecks {
    static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("LandmarkDiagnostics.json")
        let journal = LandmarkDiagnostics(url: url, capacity: 3)
        journal.record("landmark_started", details: ["runID": "old"])
        journal.record("haptic_submitted", details: ["landmark": "5", "pulse": "2", "lateness": "0.01"])
        journal.record("landmark_ended", details: ["reason": "missed_deadline", "lateness": "0.41"], flush: true)
        await journal.flush()
        let reopened = LandmarkDiagnostics(url: url, capacity: 3)
        reopened.record("landmark_started", details: ["runID": "new"])
        await reopened.flush()
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let events = try decoder.decode([LandmarkDiagnostics.Event].self, from: Data(contentsOf: url))
        assert(events.count == 3 && events[1].details["reason"] == "missed_deadline")
        assert(events.last?.details["runID"] == "new")
        let corrupt = directory.appendingPathComponent("corrupt.json")
        try Data("not JSON".utf8).write(to: corrupt)
        let bad = LandmarkDiagnostics(url: corrupt)
        bad.record("new_event", details: [:]); await bad.flush()
        let recovered = try decoder.decode([LandmarkDiagnostics.Event].self, from: Data(contentsOf: corrupt))
        assert(recovered.map(\.event) == ["journal_recovered", "new_event"])
        let backup = directory.appendingPathComponent(recovered[0].details["preservedFile"]!)
        let preserved = try String(contentsOf: backup, encoding: .utf8)
        assert(preserved == "not JSON")
        // An unavailable directory must not drop queued diagnostics. A file
        // blocking the parent is deterministic even when run with elevated rights.
        let blockedParent = directory.appendingPathComponent("blocked-parent")
        let sentinel = Data("leave this unrelated file alone".utf8)
        try sentinel.write(to: blockedParent)
        let retryURL = blockedParent.appendingPathComponent("retry.json")
        let retry = LandmarkDiagnostics(url: retryURL, capacity: 3)
        for index in 0..<5 {
            retry.record("queued-\(index)", details: ["bounded": String(repeating: "é", count: 1200)])
        }
        await retry.flush()
        let untouched = try Data(contentsOf: blockedParent)
        assert(untouched == sentinel)
        assert(!FileManager.default.fileExists(atPath: retryURL.path))
        try FileManager.default.removeItem(at: blockedParent)
        await retry.flush() // A retry needs no new event, and keeps latest entries.
        let retried = try decoder.decode([LandmarkDiagnostics.Event].self, from: Data(contentsOf: retryURL))
        assert(retried.map(\.event) == ["queued-2", "queued-3", "queued-4"])
        assert(retried.allSatisfy { $0.details["bounded"]?.count == 1000 })
        let firstWrite = try Data(contentsOf: retryURL)
        await retry.flush()
        let afterEmptyFlush = try Data(contentsOf: retryURL)
        assert(afterEmptyFlush == firstWrite) // Empty flush adds no duplicates.

        // Producers may arrive from different queues. Only per-producer order is
        // guaranteed; each event must survive exactly once without races.
        let concurrentURL = directory.appendingPathComponent("concurrent.json")
        let concurrent = LandmarkDiagnostics(url: concurrentURL, capacity: 500)
        await withTaskGroup(of: Void.self) { group in
            for producer in 0..<4 {
                group.addTask {
                    for sequence in 0..<100 {
                        concurrent.record("concurrent", details: ["producer": String(producer), "sequence": String(sequence)])
                    }
                }
            }
        }
        await concurrent.flush()
        let concurrentEvents = try decoder.decode([LandmarkDiagnostics.Event].self, from: Data(contentsOf: concurrentURL))
        assert(concurrentEvents.count == 400)
        for producer in 0..<4 {
            let sequence = concurrentEvents.filter { $0.details["producer"] == String(producer) }
                .map { Int($0.details["sequence"]!)! }
            assert(sequence == Array(0..<100))
        }
        // Production defaults, seven days of 3 classes x 20 counts.
        // 45 events/count includes acknowledgement, all 21 late timing pulses,
        // their separate late diagnostics, start and end. No old class is evicted.
        let weekURL = directory.appendingPathComponent("week.json")
        let week = LandmarkDiagnostics(url: weekURL)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        for day in 0..<7 {
            for number in 0..<3 {
                for count in 0..<20 {
                    let runID = "\(day)-\(number)-\(count)"
                    let date = start.addingTimeInterval(Double(day * 86400 + number * 7200 + count * 90))
                    week.record("landmark_started", details: ["runID": runID], at: date)
                    week.record("haptic_submitted", details: ["runID": runID, "kind": "ack"], at: date)
                    for pulse in 1...21 {
                        for name in ["landmark_pulse_late", "haptic_submitted"] {
                            week.record(name, details: ["runID": runID], at: date.addingTimeInterval(Double(pulse * 3)))
                        }
                    }
                    week.record("landmark_ended", details: ["runID": runID], at: date.addingTimeInterval(65))
                }
            }
            await week.flush()
        }
        let fullWeek = try decoder.decode([LandmarkDiagnostics.Event].self, from: Data(contentsOf: weekURL))
        assert(fullWeek.count == 18_900)
        assert(Set(fullWeek.compactMap { $0.details["runID"] }).count == 420)
        let ageURL = directory.appendingPathComponent("age.json")
        let age = LandmarkDiagnostics(url: ageURL)
        age.record("old", details: [:], at: start.addingTimeInterval(-1))
        age.record("boundary", details: [:], at: start)
        await age.flush()
        let ageAgain = LandmarkDiagnostics(url: ageURL)
        ageAgain.record("current", details: [:], at: start.addingTimeInterval(7 * 86400))
        await ageAgain.flush()
        var aged = try decoder.decode([LandmarkDiagnostics.Event].self, from: Data(contentsOf: ageURL))
        assert(aged.map(\.event) == ["boundary", "current"])
        ageAgain.record("clock_back", details: [:], at: start)
        await ageAgain.flush()
        aged = try decoder.decode([LandmarkDiagnostics.Event].self, from: Data(contentsOf: ageURL))
        assert(aged.map(\.event) == ["boundary", "current", "clock_back"])
        print("PASS: asynchronous/concurrent journal ordering, failed-write retry, bounded pending data, flush, retention, reopen and corrupt-history preservation")
    }
}
