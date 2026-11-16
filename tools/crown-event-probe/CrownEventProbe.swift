// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import WatchKit
import OSLog

/// A public Crown-value oracle, deliberately separate from native audio controls.
@MainActor
final class CrownJournal: ObservableObject {
    private struct Event: Codable, Sendable {
        let sequence: Int
        let runID: String
        let timestamp: Date
        let wallTimeSeconds: Double
        let uptimeSeconds: Double
        let event: String
        let fields: [String: String]
    }

    private let runID = UUID().uuidString
    private let writer = DispatchQueue(label: "net.qays.TeachingTimer.CrownProbe.journal", qos: .utility)
    private let logger = Logger(subsystem: "net.qays.TeachingTimer.CrownProbe", category: "Crown")
    private var sequence = 0
    private var events: [Event] = []

    func record(_ name: String, _ fields: [String: String] = [:]) {
        sequence += 1
        let now = Date()
        let event = Event(sequence: sequence, runID: runID, timestamp: now,
                          wallTimeSeconds: now.timeIntervalSince1970,
                          uptimeSeconds: ProcessInfo.processInfo.systemUptime,
                          event: name, fields: fields)
        events.append(event)
        events = Array(events.suffix(1_000))
        logger.notice("\(name, privacy: .public) sequence=\(event.sequence) wallTime=\(event.wallTimeSeconds) uptime=\(event.uptimeSeconds) fields=\(String(describing: fields), privacy: .public)")
        let snapshot = events
        let logger = logger
        writer.async {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let url = URL.documentsDirectory.appendingPathComponent("CrownProbe.json")
                try encoder.encode(snapshot).write(to: url, options: .atomic)
            } catch {
                logger.error("Crown journal write failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

struct CrownProbeView: View {
    @StateObject private var journal = CrownJournal()
    @State private var value = 0.5
    @State private var lastDelta = 0.0
    @State private var lastOffset = 0.0
    @State private var lastVelocity = 0.0
    @FocusState private var crownFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 5) {
            Text("Crown sign probe").font(.caption2)
            VStack(spacing: 1) {
                Text(String(format: "%.5f", value))
                    .font(.system(size: 29, weight: .medium, design: .monospaced))
                Text(String(format: "Change %+.5f", lastDelta))
                    .font(.system(size: 10, design: .monospaced))
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .focusable()
            .focused($crownFocused)
            .digitalCrownRotation($value, from: 0.0, through: 1.0,
                sensitivity: .medium, isContinuous: false,
                isHapticFeedbackEnabled: false,
                onChange: { event in
                    lastOffset = event.offset
                    lastVelocity = event.velocity
                    journal.record("crown_event", ["offset": String(event.offset),
                        "velocity": String(event.velocity), "currentValue": String(value)])
                }, onIdle: {
                    journal.record("crown_idle", ["currentValue": String(value)])
                })
            .onTapGesture { requestFocus(source: "value_tap") }
            Text(String(format: "Offset %+.5f\nVelocity %+.5f", lastOffset, lastVelocity))
                .font(.system(size: 9, design: .monospaced))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
            Text("Test value, not audio volume").font(.system(size: 9))
            Button("Reset 0.5", action: reset)
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .onAppear {
            let device = WKInterfaceDevice.current()
            journal.record("appeared", ["value": String(value), "range": "0...1",
                "sensitivity": "medium", "hapticsEnabled": "false",
                "crownOrientation": String(device.crownOrientation.rawValue),
                "wristLocation": String(device.wristLocation.rawValue),
                "watchOSVersion": device.systemVersion])
            requestFocus(source: "appearance")
        }
        .onChange(of: value) { old, new in
            lastDelta = new - old
            journal.record("value_changed", ["oldValue": String(old),
                "newValue": String(new), "delta": String(new - old)])
        }
        .onChange(of: crownFocused) { old, new in
            journal.record("focus_state_changed", ["old": String(old), "new": String(new)])
        }
        .onChange(of: scenePhase) { _, new in
            journal.record("scene_changed", ["phase": String(describing: new)])
            if new == .active { requestFocus(source: "scene_active") }
        }
    }

    private func requestFocus(source: String) {
        journal.record("focus_requested", ["source": source])
        crownFocused = true
    }

    private func reset() {
        journal.record("reset_requested", ["oldValue": String(value), "newValue": "0.5"])
        value = 0.5
        lastDelta = 0
        lastOffset = 0
        lastVelocity = 0
        crownFocused = false
        DispatchQueue.main.async { requestFocus(source: "reset") }
    }
}

@main
struct CrownEventProbeApp: App {
    var body: some Scene {
        WindowGroup { CrownProbeView() }
    }
}
