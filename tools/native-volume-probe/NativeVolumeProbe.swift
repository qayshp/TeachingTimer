// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
import SwiftUI
import WatchKit
import OSLog

/// Deliberately isolated: no class, runtime, landmarks, audio player or custom Crown handler.
@MainActor final class Probe: ObservableObject {
    @Published var page = 0
    @Published var ready = false
    @Published var generation = 0
    @Published var requestRevision = 0
    let replaces = ProcessInfo.processInfo.arguments.contains("--replace")
    let staged = ProcessInfo.processInfo.arguments.contains("--staged")
    let delay: TimeInterval = ProcessInfo.processInfo.arguments.contains("--immediate") ? 0 : 0.25
    private var pending: Task<Void, Never>?
    private var seenBackground = false
    private struct Event: Codable, Sendable {
        let timestamp: Date
        let event: String
        let details: [String: String]
    }
    private var events: [Event] = []
    private let writer = DispatchQueue(label: "net.qays.TeachingTimer.VolumeProbe.journal", qos: .utility)
    private let logger = Logger(subsystem: "net.qays.TeachingTimer.VolumeProbe", category: "Lifecycle")
    var mode: String { replaces ? "Replace" : "Retain" }
    func record(_ event: String, _ details: [String: String] = [:]) {
        let fields = details.merging(["mode": mode, "page": String(page), "generation": String(generation),
                                     "actualFocus": "unobserved", "phoneVolume": "unobserved"]) { a, _ in a }
        events.append(Event(timestamp: Date(), event: event, details: fields))
        events = Array(events.suffix(1000))
        logger.notice("\(event, privacy: .public) \(String(describing: fields), privacy: .public)")
        let snapshot = events
        let logger = logger
        writer.async {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(snapshot).write(to: URL.documentsDirectory.appendingPathComponent("VolumeProbe.json"), options: .atomic)
            } catch { logger.error("Probe journal write failed: \(error.localizedDescription, privacy: .public)") }
        }
    }
    func refresh(_ source: String) {
        record("refresh_requested", ["source": source])
        if replaces { generation += 1 }
        requestRevision += 1
    }
    func prepare(_ source: String) {
        pending?.cancel()
        pending = Task { [weak self] in
            guard let self else { return }
            if staged { do { try await Task.sleep(for: .seconds(1)) } catch { return } }
            guard !Task.isCancelled else { return }
            if ready { refresh(source) } else { ready = true; record("ready", ["source": source]) }
        }
    }
    func scene(_ value: ScenePhase) {
        record("scene", ["state": String(describing: value)])
        if value == .background { seenBackground = true; pending?.cancel() }
        if value == .active && seenBackground { seenBackground = false; prepare("background_return") }
    }
}

struct NativeVolume: WKInterfaceObjectRepresentable {
    @ObservedObject var probe: Probe
    let focused: Bool
    final class Coordinator {
        let id = UUID().uuidString
        var focus: Bool?
        var revision: Int?
        var token = 0
        var removed = false
        let probe: Probe
        init(_ probe: Probe) { self.probe = probe }
    }
    func makeCoordinator() -> Coordinator { Coordinator(probe) }
    func makeWKInterfaceObject(context: Context) -> WKInterfaceVolumeControl {
        probe.record("created", ["controlID": context.coordinator.id])
        return WKInterfaceVolumeControl(origin: .companion)
    }
    func updateWKInterfaceObject(_ control: WKInterfaceVolumeControl, context: Context) {
        let c = context.coordinator
        guard c.focus != focused || c.revision != probe.requestRevision else { return }
        let revisionChanged = c.revision != nil && c.revision != probe.requestRevision
        let delay = focused && (revisionChanged || (c.focus == nil && probe.requestRevision > 0)) ? probe.delay : 0
        if focused && revisionChanged {
            probe.record("resign_call", ["controlID": c.id]); control.resignFocus()
        }
        c.focus = focused; c.revision = probe.requestRevision; c.token += 1
        let token = c.token
        probe.record("focus_requested", ["controlID": c.id, "focused": String(focused), "delay": String(delay)])
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard !c.removed, c.token == token else { c.probe.record("superseded", ["controlID": c.id]); return }
            c.probe.record("focus_call", ["controlID": c.id, "focused": String(focused)])
            if focused { control.focus() } else { control.resignFocus() }
            c.probe.record("focus_returned", ["controlID": c.id])
        }
    }
    static func dismantleWKInterfaceObject(_ control: WKInterfaceVolumeControl, coordinator: Coordinator) {
        coordinator.removed = true; coordinator.token += 1
        control.resignFocus()
        coordinator.probe.record("dismantled", ["controlID": coordinator.id])
    }
}

struct ProbeView: View {
    @StateObject private var probe = Probe()
    @Environment(\.scenePhase) private var scene
    var body: some View {
        TabView(selection: $probe.page) {
            VStack(spacing: 8) {
                Text(probe.mode + (probe.staged ? " · staged" : " · direct")).font(.caption2)
                if probe.ready {
                    NativeVolume(probe: probe, focused: probe.page == 0)
                        .id(probe.generation).frame(height: 65)
                } else { Text("Preparing…").frame(height: 65) }
                Button("Refresh") { probe.refresh("tap") }.frame(minHeight: 44)
                Text("iPhone · \(probe.delay, specifier: "%.2f")s").font(.caption2)
            }.tag(0)
            NowPlayingView().tag(1)
        }.tabViewStyle(.page)
        .onAppear { probe.record("launched"); probe.prepare("startup") }
        .onChange(of: scene) { _, value in probe.scene(value) }
        .onChange(of: probe.page) { old, new in probe.record("page_changed", ["previous": String(old), "selected": String(new)]) }
    }
}
@main struct NativeVolumeProbeApp: App {
    var body: some Scene { WindowGroup { ProbeView() } }
}
