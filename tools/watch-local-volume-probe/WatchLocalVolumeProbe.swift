// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// Historical October 24 local-volume comparison, made explicitly opt-in/bounded.
import SwiftUI
import WatchKit
import AVFoundation
import MediaPlayer
import OSLog

#if !os(watchOS) || !targetEnvironment(simulator)
#error("WatchLocalVolumeProbe is restricted to watchOS Simulator")
#endif

final class Journal {
    static let shared = Journal()
    private let log = Logger(subsystem: "net.qays.TeachingTimer.WatchLocalVolumeProbe", category: "probe")
    private let queue = DispatchQueue(label: "WatchLocalVolumeProbe.journal")
    private var rows: [[String: Any]] = []
    private let file = URL.documentsDirectory.appendingPathComponent("LocalVolumeProbe.json")
    func record(_ event: String, _ fields: [String: Any] = [:]) {
        var row = fields
        row["event"] = event
        row["timestamp"] = Date().timeIntervalSince1970
        row["uptime"] = ProcessInfo.processInfo.systemUptime
        queue.async { [self] in
            guard let data = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]) else { return }
            log.info("\(String(decoding: data, as: UTF8.self), privacy: .public)")
            rows.append(row)
            if rows.count > 1_000 { rows.removeFirst(rows.count - 1_000) }
            if let saved = try? JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys]) {
                try? saved.write(to: file, options: .atomic)
            }
        }
    }
}

@MainActor final class AudioProbe: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var status = "Ready; tone paused"
    @Published private(set) var outputVolume: Float = 0
    @Published private(set) var playing = false
    private let session = AVAudioSession.sharedInstance()
    private var player: AVAudioPlayer?
    private var observation: NSKeyValueObservation?
    private var timer: Timer?
    private var started = false
    private var activationPending = false
    private var generation = 0
    private var deadline: TimeInterval?
    private var notifications: [NSObjectProtocol] = []
    private var playbackLimit: TimeInterval {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--playback-limit-seconds"), args.indices.contains(i + 1),
              let value = Double(args[i + 1]), value.isFinite else { return 30 }
        return min(120, max(1, value))
    }

    func startOnce() {
        guard !started else { return }; started = true
        observation = session.observe(\.outputVolume, options: [.initial, .new]) { [weak self] _, change in
            let volume = change.newValue ?? -1
            Task { @MainActor [weak self] in
                self?.outputVolume = volume
                Journal.shared.record("output_volume_observed", ["volume": volume])
            }
        }
        for name in [AVAudioSession.routeChangeNotification, AVAudioSession.interruptionNotification] {
            notifications.append(NotificationCenter.default.addObserver(forName: name, object: session, queue: .main) { note in
                Journal.shared.record("audio_notification", ["name": note.name.rawValue, "details": String(describing: note.userInfo)])
            })
        }
        MPRemoteCommandCenter.shared().pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.stop("remote_pause") }
            return .success
        }
        snapshot("ready", ["watchOS": WKInterfaceDevice.current().systemVersion,
                           "crownOrientation": WKInterfaceDevice.current().crownOrientation.rawValue,
                           "wristLocation": WKInterfaceDevice.current().wristLocation.rawValue])
        if ProcessInfo.processInfo.arguments.contains("--autoplay") { play() }
    }

    func play() {
        guard !activationPending, !playing else { return }
        do {
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio, options: [])
            guard let url = Bundle.main.url(forResource: "tone", withExtension: "wav") else {
                throw NSError(domain: "WatchLocalVolumeProbe", code: 1)
            }
            let audio = try AVAudioPlayer(contentsOf: url)
            audio.numberOfLoops = 0; audio.delegate = self
            guard audio.prepareToPlay() else { throw NSError(domain: "WatchLocalVolumeProbe", code: 2) }
            player = audio; activationPending = true; generation += 1
            let request = generation
            status = "Activating…"
            snapshot("activation_requested", ["limitSeconds": playbackLimit])
            session.activate(options: []) { [weak self] activated, error in
                let detail = error.map(String.init(describing:)) ?? "none"
                Task { @MainActor in
                    guard let self else { return }; self.activationPending = false
                    self.snapshot("activation_result", ["activated": activated, "error": detail])
                    guard request == self.generation else {
                        try? self.session.setActive(false)
                        self.snapshot("activation_cancelled_before_play"); return
                    }
                    guard activated, error == nil else { self.status = "Activation failed"; return }
                    self.playing = self.player?.play() == true
                    self.status = self.playing ? "Playing quiet tone" : "Play failed"
                    guard self.playing else { self.stop("play_failed"); return }
                    self.deadline = ProcessInfo.processInfo.systemUptime + self.playbackLimit
                    // Preserve the old local-volume fixture's live-stream metadata;
                    // finite-progress/extrapolation tests belong to WatchAudioProbe.
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = [
                        MPMediaItemPropertyTitle: "Watch local tone",
                        MPMediaItemPropertyArtist: "Local volume comparison",
                        MPNowPlayingInfoPropertyPlaybackRate: 1.0,
                        MPNowPlayingInfoPropertyIsLiveStream: true
                    ]
                    self.snapshot("play_result")
                    self.timer?.invalidate()
                    self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                        Task { @MainActor in self?.tick() }
                    }
                }
            }
        } catch { status = "Setup failed"; snapshot("setup_error", ["error": String(describing: error)]) }
    }

    private func tick() {
        if let deadline, ProcessInfo.processInfo.systemUptime >= deadline { stop("playback_limit_reached") }
        else { snapshot("heartbeat") }
    }
    private func snapshot(_ event: String, _ fields: [String: Any] = [:]) {
        outputVolume = session.outputVolume
        Journal.shared.record(event, fields.merging([
            "outputVolume": outputVolume, "playing": player?.isPlaying ?? false,
            "playerTime": player?.currentTime ?? -1, "playerGain": player?.volume ?? -1,
            "route": session.currentRoute.outputs.map { "\($0.portType.rawValue):\($0.portName)" }.joined(separator: ",")
        ]) { _, current in current })
    }
    func stop(_ reason: String = "ui_stop") {
        generation += 1; player?.stop(); playing = false; status = "Stopped"
        timer?.invalidate(); timer = nil; deadline = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        do { try session.setActive(false) }
        catch { Journal.shared.record("deactivation_error", ["error": String(describing: error)]) }
        snapshot(reason)
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.stop(flag ? "file_finished" : "file_failed") }
    }
}

struct LocalVolume: WKInterfaceObjectRepresentable {
    let active: Bool
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeWKInterfaceObject(context: Context) -> WKInterfaceVolumeControl {
        Journal.shared.record("volume_created", ["origin": "local"])
        return WKInterfaceVolumeControl(origin: .local)
    }
    func updateWKInterfaceObject(_ control: WKInterfaceVolumeControl, context: Context) {
        guard context.coordinator.focused != active else { return }
        context.coordinator.focused = active
        DispatchQueue.main.async {
            if active { control.focus() } else { control.resignFocus() }
            Journal.shared.record("volume_focus_returned", ["focused": active])
        }
    }
    static func dismantleWKInterfaceObject(_ control: WKInterfaceVolumeControl, coordinator: Coordinator) {
        control.resignFocus(); Journal.shared.record("volume_removed")
    }
    final class Coordinator { var focused = false }
}

@main struct WatchLocalVolumeProbe: App {
    @StateObject private var probe = AudioProbe()
    @State private var page = 0
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            TabView(selection: $page) {
                VStack(spacing: 4) {
                    Text("Local volume probe").font(.caption2)
                    LocalVolume(active: page == 0 && phase == .active).frame(width: 80, height: 52)
                    Text(String(format: "Session %.2f", probe.outputVolume)).font(.caption.monospacedDigit())
                    Text(probe.status).font(.caption2)
                    HStack {
                        Button("Play tone") { probe.play() }
                        Button("Stop") { probe.stop() }
                    }.font(.caption2)
                }.tag(0)
                NowPlayingView().tag(1)
            }
            .tabViewStyle(.page)
            .onAppear { probe.startOnce() }
            .onChange(of: phase) { _, new in Journal.shared.record("scene", ["phase": String(describing: new)]) }
            .onChange(of: page) { _, new in Journal.shared.record("page", ["page": new]) }
        }
    }
}
