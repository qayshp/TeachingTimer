// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

@main
struct RuntimeDiagnosticsChecks {
    @MainActor static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("RuntimeDiagnostics.json")
        let journal = RuntimeDiagnostics(fileURL: url, capacity: 3)
        journal.record("start_requested", details: ["runtimeID": "test-session"])
        journal.record("runtime_started", details: [:])
        journal.record("runtime_invalidated", details: ["reason": "resigned_frontmost", "reasonCode": "2"])
        await journal.flush()
        let reopened = RuntimeDiagnostics(fileURL: url, capacity: 3)
        reopened.record("app_launched", details: [:])
        await reopened.flush()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = try decoder.decode([RuntimeDiagnostics.Event].self, from: Data(contentsOf: url))
        assert(entries.map(\.event) == ["runtime_started", "runtime_invalidated", "app_launched"])
        assert(entries[1].details["reason"] == "resigned_frontmost")
        let bad = directory.appendingPathComponent("bad.json")
        try Data("unreadable".utf8).write(to: bad)
        let recovery = RuntimeDiagnostics(fileURL: bad)
        recovery.record("new_event", details: [:])
        await recovery.flush()
        let recovered = try decoder.decode([RuntimeDiagnostics.Event].self, from: Data(contentsOf: bad))
        assert(recovered.map(\.event) == ["journal_recovered", "new_event"])
        let preservedURL = directory.appendingPathComponent(recovered[0].details["preservedFile"]!)
        let preserved = try String(contentsOf: preservedURL, encoding: .utf8)
        assert(preserved == "unreadable")
        print("PASS: durable events, relaunch/reopen, bounded retention, end reason and corrupt-file preservation")
    }
}
