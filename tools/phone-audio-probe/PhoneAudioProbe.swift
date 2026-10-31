// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// Isolated Simulator fixture; no TeachingTimer production dependency.
import UIKit
import AVFoundation
import MediaPlayer
import OSLog

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Probe", sessionRole: session.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = ProbeController()
        self.window = window
        window.makeKeyAndVisible()
    }
}

final class ProbeController: UIViewController {
    let logger = Logger(subsystem: "net.qays.TeachingTimer.PhoneAudioProbe", category: "MediaProbe")
    let audioSession = AVAudioSession.sharedInstance()
    var player: AVAudioPlayer?
    var timer: Timer?
    var observation: NSKeyValueObservation?
    var track = 1
    var playbackDeadline: TimeInterval?
    var playbackLimitSeconds: TimeInterval {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--playback-limit-seconds"),
              args.indices.contains(index + 1), let value = Double(args[index + 1]), value.isFinite
        else { return 120 }
        return min(120, max(1, value))
    }
    var ticks = 0
    var remoteCount = 0
    var lastEvent = "Ready"
    let status = UILabel()
    let events = UILabel()
    let journalURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("MediaProbe.jsonl")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24)
        ])
        let title = UILabel()
        title.text = "Native audio probe"
        title.font = .preferredFont(forTextStyle: .title1)
        title.adjustsFontForContentSizeCategory = true
        stack.addArrangedSubview(title)
        let note = UILabel()
        note.text = "Quiet local tone · no account\nSeparate from TeachingTimer"
        note.numberOfLines = 0
        note.font = .preferredFont(forTextStyle: .body)
        stack.addArrangedSubview(note)
        status.numberOfLines = 0
        status.font = .monospacedSystemFont(ofSize: 17, weight: .regular)
        stack.addArrangedSubview(status)
        for (title, action) in [("Play", #selector(playTapped)), ("Pause", #selector(pauseTapped)),
                                ("Previous tone", #selector(previousTapped)), ("Next tone", #selector(nextTapped))] {
            let button = UIButton(type: .system)
            button.configuration = .filled()
            button.setTitle(title, for: .normal)
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
            button.addTarget(self, action: action, for: .touchUpInside)
            stack.addArrangedSubview(button)
        }
        let volumeTitle = UILabel()
        volumeTitle.text = "System volume (native control)"
        volumeTitle.font = .preferredFont(forTextStyle: .caption1)
        stack.addArrangedSubview(volumeTitle)
        let volume = MPVolumeView()
        volume.heightAnchor.constraint(equalToConstant: 36).isActive = true
        stack.addArrangedSubview(volume)
        events.numberOfLines = 0
        events.font = .preferredFont(forTextStyle: .caption1)
        stack.addArrangedSubview(events)
        do {
            try audioSession.setCategory(.playback, mode: .default)
            guard let file = Bundle.main.url(forResource: "tone", withExtension: "wav") else {
                throw NSError(domain: "MediaProbe", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing tone.wav"])
            }
            player = try AVAudioPlayer(contentsOf: file)
            player?.numberOfLoops = -1
            player?.prepareToPlay()
            configureCommands()
            observation = audioSession.observe(\.outputVolume, options: [.new]) { [weak self] _, _ in
                DispatchQueue.main.async { self?.record("system_volume_changed") }
            }
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.ticks += 1
                if let deadline = self.playbackDeadline,
                   ProcessInfo.processInfo.systemUptime >= deadline {
                    self.pause("playback_limit_reached")
                }
                self.render()
                if self.ticks % 5 == 0 { self.record("heartbeat") }
            }
            record("ready")
        } catch { record("setup_error: \(error.localizedDescription)") }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.shared.beginReceivingRemoteControlEvents()
        becomeFirstResponder()
        if ProcessInfo.processInfo.arguments.contains("--autoplay"), lastEvent == "ready" { play("launch_play") }
    }

    override var canBecomeFirstResponder: Bool { true }

    func configureCommands() {
        let center = MPRemoteCommandCenter.shared()
        let actions: [(MPRemoteCommand, String)] = [(center.playCommand, "play"), (center.pauseCommand, "pause"),
            (center.togglePlayPauseCommand, "toggle"), (center.nextTrackCommand, "next"), (center.previousTrackCommand, "previous")]
        for (command, name) in actions {
            command.isEnabled = true
            command.addTarget { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.remoteCount += 1
                    switch name {
                    case "play": self.play("remote_play")
                    case "pause": self.pause("remote_pause")
                    case "toggle": self.player?.isPlaying == true ? self.pause("remote_toggle_pause") : self.play("remote_toggle_play")
                    case "next": self.changeTrack(1, event: "remote_next")
                    default: self.changeTrack(-1, event: "remote_previous")
                    }
                }
                return .success
            }
        }
        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            DispatchQueue.main.async {
                self?.remoteCount += 1
                self?.player?.currentTime = event.positionTime
                self?.publish()
                self?.record("remote_seek")
            }
            return .success
        }
    }

    func publish() {
        guard let player else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "Native Probe Tone \(track)",
            MPMediaItemPropertyArtist: "Local Simulator fixture",
            MPMediaItemPropertyAlbumTitle: "No AirPlay test",
            MPMediaItemPropertyPlaybackDuration: player.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player.currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: player.isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyExternalContentIdentifier: "local-tone-\(track)"
        ]
    }

    func play(_ event: String) {
        do {
            try audioSession.setActive(true)
            guard player?.play() == true else { record("play_failed"); return }
            playbackDeadline = ProcessInfo.processInfo.systemUptime + playbackLimitSeconds
            publish()
            record(event)
        } catch { record("play_error: \(error.localizedDescription)") }
    }
    func pause(_ event: String) { player?.pause(); playbackDeadline = nil; publish(); record(event) }
    func changeTrack(_ direction: Int, event: String) {
        track = (track == 1 ? 2 : 1)
        player?.currentTime = 0
        play(event)
    }
    @objc func playTapped() { play("local_play") }
    @objc func pauseTapped() { pause("local_pause") }
    @objc func nextTapped() { changeTrack(1, event: "local_next") }
    @objc func previousTapped() { changeTrack(-1, event: "local_previous") }

    func render() {
        status.text = "Tone \(track) · \(player?.isPlaying == true ? "Playing" : "Paused")\nPosition: \(String(format: "%.1f", player?.currentTime ?? 0)) s\nSystem volume: \(Int(audioSession.outputVolume * 100))%\nRemote commands: \(remoteCount)"
        events.text = "Last event: \(lastEvent)\nJournal: Documents/MediaProbe.jsonl\nSystem volume is a simulator value, not an AirPlay measurement."
    }
    func record(_ event: String) {
        if event != "heartbeat" { lastEvent = event }
        let data: [String: Any] = ["timestamp": ISO8601DateFormatter().string(from: Date()),
            "uptime": ProcessInfo.processInfo.systemUptime, "event": event, "track": track,
            "playing": player?.isPlaying ?? false, "position": player?.currentTime ?? 0,
            "outputVolume": audioSession.outputVolume, "remoteCount": remoteCount,
            "route": audioSession.currentRoute.outputs.map { $0.portType.rawValue }]
        if let bytes = try? JSONSerialization.data(withJSONObject: data, options: [.sortedKeys]),
           let line = String(data: bytes, encoding: .utf8) {
            logger.notice("\(line, privacy: .public)")
            if !FileManager.default.fileExists(atPath: journalURL.path) {
                FileManager.default.createFile(atPath: journalURL.path, contents: nil)
            }
            if let file = try? FileHandle(forWritingTo: journalURL) {
                defer { try? file.close() }
                _ = try? file.seekToEnd()
                try? file.write(contentsOf: Data((line + "\n").utf8))
            }
        }
        render()
    }
}
