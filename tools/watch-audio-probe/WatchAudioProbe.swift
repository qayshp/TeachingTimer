// SPDX-License-Identifier: MPL-2.0
// Isolated local-audio Simulator fixture. No TeachingTimer production dependency.
import SwiftUI
import WatchKit
import AVFoundation
import MediaPlayer
import NowPlaying
import Observation
import OSLog

#if !os(watchOS) || !targetEnvironment(simulator)
#error("WatchAudioProbe is restricted to watchOS Simulator")
#endif

@available(watchOS 27.0, *)
@Observable @MainActor private final class SessionPublisher: MediaSessionRepresentable {
    let id = "watch-local-silent-pcm-session-180"
    var playbackSnapshot: MediaPlaybackSnapshot?
    var content: (any MediaContentRepresentable)? {
        GenericContent(id: id, title: "Silent Watch PCM Session", subtitle: "Actual local audio", type: .audio, duration: .finite(180), artwork: nil)
    }
    @ObservationIgnored weak var audio: AudioProbe?
    @ObservationIgnored private var session: MediaSession<SessionPublisher>?
    @ObservationIgnored private var activationPending = false
    init(audio: AudioProbe) { self.audio = audio }
    var commands: [MediaCommand] {
        [.play { [weak self] in self?.audio?.sessionCommand("play") },
         .pause { [weak self] in self?.audio?.sessionCommand("pause") },
         .stop { [weak self] in self?.audio?.sessionCommand("stop") },
         .togglePlayPause { [weak self] in self?.audio?.sessionCommand("toggle") },
         .seekToPosition { [weak self] value in self?.audio?.sessionCommand("seek", position: value) }]
    }
    func submit(playing: Bool, position: TimeInterval, stopped: Bool) {
        playbackSnapshot = .init(state: playing ? .playing(rate: 1) : (stopped ? .stopped : .paused), elapsedTime: position, timestamp: Date())
        guard playing else { return }
        if session == nil { session = MediaSession(self) }
        guard let session, !session.isApplicationPrimary, !activationPending else { return }
        activationPending = true
        Task { [weak self] in
            guard let self else { return }
            do {
                try await session.requestToBecomeApplicationPrimary()
                self.activationPending = false
                self.audio?.sessionResult(active: session.isApplicationPrimary, canBecomeActive: session.canBecomeApplicationPrimary, error: nil)
            } catch {
                self.activationPending = false
                self.audio?.sessionResult(active: session.isApplicationPrimary, canBecomeActive: session.canBecomeApplicationPrimary, error: error.localizedDescription)
            }
        }
    }
}

@MainActor final class AudioProbe: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var status = "Preparing silent PCM"
    @Published private(set) var position: TimeInterval = 0
    @Published private(set) var playing = false
    @Published private(set) var metadataCount = 0
    let frequentMetadata = ProcessInfo.processInfo.arguments.contains("--frequent-metadata")
    let sessionAPI = ProcessInfo.processInfo.arguments.contains("--session-api")
    private let session = AVAudioSession.sharedInstance()
    private let logger = Logger(subsystem: "net.qays.TeachingTimer.WatchAudioProbe", category: "AudioProbe")
    private let journal = URL.documentsDirectory.appendingPathComponent("WatchAudioProbe.jsonl")
    private let runID = UUID().uuidString
    private var eventSequence = 0
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var started = false
    private var activationPending = false
    private var wantsPlayback = false
    private var anchorUptime: TimeInterval = 0
    private var anchorPosition: TimeInterval = 0
    private var deadline: TimeInterval?
    private var remoteCount = 0
    private var lastMetadataPosition: TimeInterval = 0
    private var lastMetadataRate: Double = 0
    private var lastMetadataUptime: TimeInterval = 0
    private var sessionPublisher: AnyObject?

    private func argument(_ name: String) -> Double? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: name), args.indices.contains(i + 1),
              let value = Double(args[i + 1]), value.isFinite else { return nil }
        return value
    }
    private var playbackLimit: TimeInterval { min(180, max(1, argument("--playback-limit-seconds") ?? 180)) }
    private var uptime: TimeInterval { ProcessInfo.processInfo.systemUptime }

    func startOnce() {
        guard !started else { return }; started = true
        do {
            guard let url = Bundle.main.url(forResource: "silence", withExtension: "wav") else {
                throw NSError(domain: "WatchAudioProbe", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing silence.wav"])
            }
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio, options: [])
            let audio = try AVAudioPlayer(contentsOf: url)
            audio.delegate = self; audio.numberOfLoops = 0
            guard audio.prepareToPlay() else {
                throw NSError(domain: "WatchAudioProbe", code: 2, userInfo: [NSLocalizedDescriptionKey: "prepareToPlay returned false"])
            }
            player = audio
            anchorPosition = 0; anchorUptime = uptime
            if sessionAPI {
                guard #available(watchOS 27.0, *) else { record("session_api_unavailable_requires_watchOS27"); return }
                sessionPublisher = SessionPublisher(audio: self)
            } else { configureCommands() }
            observeSession()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
            record("ready")
            if let initial = argument("--seek-seconds") { seek(initial, source: "launch_seek") }
            if ProcessInfo.processInfo.arguments.contains("--autoplay") { play("launch_play") }
        } catch { record("setup_error", ["error": error.localizedDescription]) }
    }

    func play(_ source: String = "ui_play") {
        guard player != nil else { record("play_failed_no_player"); return }
        wantsPlayback = true
        guard !activationPending else { record("activation_already_pending"); return }
        activationPending = true; record("activation_requested", ["source": source])
        session.activate(options: []) { [weak self] activated, error in
            let detail = error?.localizedDescription ?? "none"
            Task { @MainActor in
                guard let self else { return }; self.activationPending = false
                self.record("activation_result", ["activated": activated, "error": detail])
                guard activated, error == nil, let player = self.player else { return }
                guard self.wantsPlayback else {
                    try? self.session.setActive(false, options: .notifyOthersOnDeactivation)
                    self.record("activation_cancelled_before_play"); return
                }
                if player.currentTime >= player.duration { player.currentTime = 0 }
                guard player.play() else { self.record("play_failed_returned_false"); return }
                self.reanchor(); self.deadline = self.uptime + self.playbackLimit
                self.publish(source); self.record(source)
            }
        }
    }
    func pause(_ source: String = "ui_pause") {
        wantsPlayback = false; player?.pause(); deadline = nil; reanchor(); publish(source); record(source)
    }
    func stop(_ source: String = "ui_stop") {
        wantsPlayback = false; player?.stop(); player?.currentTime = 0; deadline = nil; reanchor()
        publish(source)
        do { try session.setActive(false, options: .notifyOthersOnDeactivation) }
        catch { record("deactivation_error", ["error": error.localizedDescription]) }
        record(source)
    }
    func seek(_ seconds: TimeInterval, source: String = "ui_seek") {
        guard let player, seconds.isFinite else { return }
        player.currentTime = min(player.duration, max(0, seconds)); reanchor(); publish(source); record(source)
    }
    func advance() { seek((player?.currentTime ?? 0) + 30) }
    private func reanchor() { anchorPosition = player?.currentTime ?? 0; anchorUptime = uptime }

    private func publish(_ reason: String) {
        guard let player else { return }
        lastMetadataPosition = player.currentTime; lastMetadataRate = player.isPlaying ? 1 : 0
        lastMetadataUptime = uptime; metadataCount += 1
        if sessionAPI {
            if #available(watchOS 27.0, *), let publisher = sessionPublisher as? SessionPublisher {
                publisher.submit(playing: player.isPlaying, position: lastMetadataPosition,
                                 stopped: reason == "ui_stop" || reason == "remote_stop" || reason == "session_remote_stop" || reason == "player_finished")
                record("session_snapshot_submitted", ["reason": reason])
            }
            return
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "Silent Watch PCM",
            MPMediaItemPropertyArtist: "Local Simulator fixture",
            MPMediaItemPropertyAlbumTitle: frequentMetadata ? "Frequent metadata comparison" : "Transition metadata only",
            MPMediaItemPropertyPlaybackDuration: player.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: lastMetadataPosition,
            MPNowPlayingInfoPropertyPlaybackRate: lastMetadataRate,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyIsLiveStream: false,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyExternalContentIdentifier: "watch-local-silent-pcm-180"
        ]
        record("metadata_published", ["reason": reason])
    }
    private func tick() {
        if let deadline, uptime >= deadline { pause("playback_limit_reached") }
        // This samples the actual player; it does not feed elapsed time to native UI.
        if frequentMetadata, player?.isPlaying == true { publish("frequent_metadata_tick") }
        record("heartbeat")
    }

    private func configureCommands() {
        let center = MPRemoteCommandCenter.shared()
        for (command, name) in [(center.playCommand, "play"), (center.pauseCommand, "pause"),
                                (center.stopCommand, "stop"), (center.togglePlayPauseCommand, "toggle")] {
            command.isEnabled = true
            command.addTarget { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }; self.remoteCount += 1
                    switch name {
                    case "play": self.play("remote_play")
                    case "pause": self.pause("remote_pause")
                    case "stop": self.stop("remote_stop")
                    default: self.player?.isPlaying == true ? self.pause("remote_toggle_pause") : self.play("remote_toggle_play")
                    }
                }
                return .success
            }
        }
        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let target = event.positionTime
            Task { @MainActor in self?.remoteCount += 1; self?.seek(target, source: "remote_seek") }
            return .success
        }
    }
    func sessionCommand(_ command: String, position: TimeInterval? = nil) {
        remoteCount += 1
        switch command {
        case "play": play("session_remote_play")
        case "pause": pause("session_remote_pause")
        case "stop": stop("session_remote_stop")
        case "seek": if let position { seek(position, source: "session_remote_seek") }
        default: player?.isPlaying == true ? pause("session_remote_toggle_pause") : play("session_remote_toggle_play")
        }
    }
    func sessionResult(active: Bool, canBecomeActive: Bool, error: String?) {
        record("session_activation_result", ["isApplicationPrimary": active, "canBecomeApplicationPrimary": canBecomeActive, "error": error ?? "none"])
    }
    private func observeSession() {
        for name in [AVAudioSession.interruptionNotification, AVAudioSession.routeChangeNotification,
                     AVAudioSession.mediaServicesWereLostNotification, AVAudioSession.mediaServicesWereResetNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: session, queue: .main) { [weak self] note in
                let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue
                let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue
                Task { @MainActor in
                    guard let self else { return }
                    if name == AVAudioSession.interruptionNotification, type == AVAudioSession.InterruptionType.began.rawValue {
                        self.pause("interruption_began")
                    }
                    self.record("audio_session_notification", ["name": name.rawValue, "interruptionType": type.map(String.init) ?? "absent", "routeReason": reason.map(String.init) ?? "absent"])
                }
            })
        }
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }; self.deadline = nil; self.reanchor()
            self.publish("player_finished"); self.record("player_finished", ["success": flag])
        }
    }
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let text = error?.localizedDescription ?? "unknown"
        Task { @MainActor [weak self] in self?.pause("decode_error"); self?.record("decode_error_detail", ["error": text]) }
    }
    func scene(_ phase: ScenePhase) { record("scene", ["phase": String(describing: phase)]) }
    func page(_ page: Int) { record("page", ["selected": page]) }

    private func record(_ event: String, _ extra: [String: Any] = [:]) {
        let now = uptime, current = player?.currentTime ?? 0, isPlaying = player?.isPlaying ?? false
        eventSequence += 1
        position = current; playing = isPlaying
        if event != "heartbeat" && event != "metadata_published" { status = event }
        let expected = min(player?.duration ?? 0, anchorPosition + (isPlaying ? max(0, now - anchorUptime) : 0))
        var row: [String: Any] = ["timestamp": ISO8601DateFormatter().string(from: Date()), "uptime": now,
            "timestampUnix": Date().timeIntervalSince1970, "runID": runID, "pid": ProcessInfo.processInfo.processIdentifier, "eventSequence": eventSequence,
            "event": event, "playing": isPlaying, "playerCurrentTime": current, "duration": player?.duration ?? 0,
            "playerDeviceCurrentTime": player?.deviceCurrentTime ?? 0, "monotonicExpectedPosition": expected,
            "anchorPosition": anchorPosition, "anchorUptime": anchorUptime, "metadataPublishCount": metadataCount,
            "lastMetadataPosition": lastMetadataPosition, "lastMetadataRate": lastMetadataRate,
            "lastMetadataUptime": lastMetadataUptime, "frequentMetadata": frequentMetadata, "remoteCount": remoteCount,
            "publisherAPI": sessionAPI ? "NowPlaying.MediaSession" : "MPNowPlayingInfoCenter",
            "activationPending": activationPending, "routeSharingPolicy": "longFormAudio",
            "outputVolume": session.outputVolume, "route": session.currentRoute.outputs.map { $0.portType.rawValue },
            "audioContent": "all-zero signed16 PCM", "physicalAudioMeasurement": false]
        row.merge(extra) { _, new in new }
        guard let data = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]),
              let line = String(data: data, encoding: .utf8) else { return }
        logger.notice("\(line, privacy: .public)")
        if !FileManager.default.fileExists(atPath: journal.path) { FileManager.default.createFile(atPath: journal.path, contents: nil) }
        do {
            let file = try FileHandle(forWritingTo: journal); defer { try? file.close() }
            try file.seekToEnd(); try file.write(contentsOf: Data((line + "\n").utf8))
        } catch { logger.error("Journal write failed: \(error.localizedDescription, privacy: .public)") }
    }
}

private struct ControlPage: View {
    @ObservedObject var audio: AudioProbe
    var body: some View {
        ScrollView {
            VStack(spacing: 7) {
                Text("Silent local audio").font(.headline)
                Text((audio.sessionAPI ? "Session API · " : "Legacy · ") + (audio.frequentMetadata ? "frequent" : "transitions only")).font(.caption2)
                Text("\(audio.position, specifier: "%.1f") / 180s · \(audio.playing ? "Playing" : "Paused")").monospacedDigit().font(.caption)
                HStack { Button("Play") { audio.play() }; Button("Pause") { audio.pause() } }
                HStack { Button("Stop") { audio.stop() }; Button("+30s") { audio.advance() } }
                Text("Publishes: \(audio.metadataCount) · \(audio.status)").font(.caption2)
            }
        }
    }
}

private struct ProbeView: View {
    let audio: AudioProbe
    @State private var page = ProcessInfo.processInfo.arguments.contains("--now-playing") ? 1 : 0
    @Environment(\.scenePhase) private var phase
    var body: some View {
        TabView(selection: $page) {
            ControlPage(audio: audio).tag(0)
            NowPlayingView().tag(1)
        }
        .tabViewStyle(.page)
        .onAppear { audio.startOnce(); audio.page(page) }
        .onChange(of: phase) { _, value in audio.scene(value) }
        .onChange(of: page) { _, value in audio.page(value) }
    }
}

@main struct WatchAudioProbeApp: App {
    // Own the reference without subscribing this native-page host to heartbeat changes.
    // Only ControlPage observes the published diagnostic fields.
    @State private var audio = AudioProbe()
    var body: some Scene { WindowGroup { ProbeView(audio: audio) } }
}
