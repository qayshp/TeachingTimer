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
        print("PASS: asynchronous journal ordering, flush, bounded retention, reopen and corrupt-history preservation")
    }
}
