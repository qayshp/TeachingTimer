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

        // Several busy teaching days must not let ordinary wrist transitions
        // evict an earlier class. Both files retain bounded, ordered histories.
        let busyURL = directory.appendingPathComponent("busy/RuntimeDiagnostics.json")
        let busy = RuntimeDiagnostics(fileURL: busyURL, interfaceCapacity: 40)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        for day in 0..<6 {
            for number in 0..<3 {
                let id = "day-\(day)-class-\(number)"
                let classStart = start.addingTimeInterval(Double(day * 86400 + number * 7200))
                busy.record("runtime_started", details: ["runtimeID": id], at: classStart)
                for wake in 0..<100 {
                    let date = classStart.addingTimeInterval(Double(wake * 30 + 1))
                    busy.record("scene_state_changed", details: [
                        "sceneState": "inactive", "previousSceneState": "active"
                    ], at: date)
                    busy.record("luminance_changed", details: ["luminanceReduced": "true"], at: date)
                    busy.record("scene_state_changed", details: [
                        "sceneState": "active", "previousSceneState": "inactive"
                    ], at: date.addingTimeInterval(1))
                }
                busy.record("volume_focus_call_returned", details: ["runtimeID": id],
                            at: classStart.addingTimeInterval(3500))
                busy.record("runtime_invalidated", details: ["runtimeID": id, "reason": "resigned_frontmost"],
                            at: classStart.addingTimeInterval(3600))
            }
        }
        await busy.flush()
        let classes = try decoder.decode([RuntimeDiagnostics.Event].self, from: Data(contentsOf: busyURL))
        assert(classes.count == 54)
        assert(classes.first?.details["runtimeID"] == "day-0-class-0")
        assert(classes.filter { $0.event == "volume_focus_call_returned" }.count == 18)
        let transitions = try decoder.decode([RuntimeDiagnostics.Event].self,
                                              from: Data(contentsOf: busy.interfaceFileURL))
        assert(transitions.count == 40)
        assert(transitions.allSatisfy { $0.event == "scene_state_changed" || $0.event == "luminance_changed" })

        // Background entry/exit and initial activation remain durable main-file
        // events with page context; they are not treated as routine wrist wakes.
        for (previous, current) in [("unknown", "active"), ("inactive", "background"), ("background", "inactive")] {
            busy.record("scene_state_changed", details: ["previousSceneState": previous,
                "sceneState": current, "selectedPage": "nowPlaying"], at: start.addingTimeInterval(6 * 86400))
        }
        await busy.flush()
        let withBackground = try decoder.decode([RuntimeDiagnostics.Event].self, from: Data(contentsOf: busyURL))
        assert(withBackground.suffix(3).allSatisfy { $0.event == "scene_state_changed" && $0.details["selectedPage"] == "nowPlaying" })

        // Existing on-disk history is aged on the next write after relaunch.
        // Seven-day boundary is inclusive; a backward clock jump keeps history.
        let ageURL = directory.appendingPathComponent("age/RuntimeDiagnostics.json")
        let age = RuntimeDiagnostics(fileURL: ageURL)
        age.record("old", details: [:], at: start.addingTimeInterval(-1))
        age.record("boundary", details: [:], at: start)
        await age.flush()
        let ageReopened = RuntimeDiagnostics(fileURL: ageURL)
        ageReopened.record("current", details: [:], at: start.addingTimeInterval(7 * 86400))
        await ageReopened.flush()
        let aged = try decoder.decode([RuntimeDiagnostics.Event].self, from: Data(contentsOf: ageURL))
        assert(aged.map(\.event) == ["boundary", "current"])
        ageReopened.record("clock_moved_back", details: [:], at: start)
        await ageReopened.flush()
        let backwards = try decoder.decode([RuntimeDiagnostics.Event].self, from: Data(contentsOf: ageURL))
        assert(backwards.map(\.event) == ["boundary", "current", "clock_moved_back"])
        print("PASS: durable runtime events, relaunch, size/age retention, multi-class wake isolation, background context and corrupt-file preservation")
    }
}
