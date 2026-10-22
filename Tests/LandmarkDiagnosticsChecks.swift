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
        print("PASS: asynchronous journal ordering, flush, bounded retention, reopen and corrupt-history preservation")
    }
}
