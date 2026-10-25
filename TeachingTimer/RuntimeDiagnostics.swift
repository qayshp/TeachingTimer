// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Runtime events use the same ordered, off-main writer as landmark events.
/// Record returns after queuing; a sudden process kill may lose the last events.
final class RuntimeDiagnostics: @unchecked Sendable {
    typealias Event = LandmarkDiagnostics.Event
    static let retentionInterval: TimeInterval = 7 * 24 * 60 * 60
    static let defaultCapacity = 10_000
    let fileURL: URL
    let interfaceFileURL: URL
    private let writer: LandmarkDiagnostics
    private let interfaceWriter: LandmarkDiagnostics

    init(fileURL: URL = URL.documentsDirectory.appendingPathComponent("RuntimeDiagnostics.json"),
         capacity: Int = RuntimeDiagnostics.defaultCapacity,
         interfaceCapacity: Int = 4000) {
        self.fileURL = fileURL
        interfaceFileURL = fileURL.deletingLastPathComponent().appendingPathComponent("InterfaceDiagnostics.json")
        writer = LandmarkDiagnostics(url: fileURL, capacity: capacity, label: "RuntimeJournal",
                                     retentionInterval: Self.retentionInterval)
        interfaceWriter = LandmarkDiagnostics(url: interfaceFileURL, capacity: interfaceCapacity,
                                              label: "InterfaceJournal", retentionInterval: 24 * 60 * 60)
    }

    func record(_ name: String, details: [String: String], at date: Date = Date()) {
        if Self.isRoutineInterfaceEvent(name, details: details) {
            // Keep exact wake/dim timestamps available for focused investigations
            // without displacing earlier classes in the operational journal.
            interfaceWriter.record(name, details: details, at: date)
        } else {
            let urgent = name == "app_launched" || name == "stop_requested"
                || name == "start_requested" || name == "runtime_started"
                || name == "runtime_invalidated" || name == "runtime_will_expire"
                || name == "scene_state_changed"
            // Batch ordinary callbacks (including focus request/call/return)
            // into the writer's 250 ms window instead of rewriting per callback.
            writer.record(name, details: details, at: date, flush: urgent)
        }
    }

    private static func isRoutineInterfaceEvent(_ name: String, details: [String: String]) -> Bool {
        if name == "luminance_changed" { return true }
        guard name == "scene_state_changed" else { return false }
        // Background entry/exit and initial state remain in the main journal.
        // Only ordinary active <-> inactive transitions go to the detail file.
        let ordinaryStates = ["active", "inactive"]
        return ordinaryStates.contains(details["sceneState"] ?? "")
            && ordinaryStates.contains(details["previousSceneState"] ?? "")
    }

    func flush() async {
        await writer.flush()
        await interfaceWriter.flush()
    }
}
