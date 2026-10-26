// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Pure timing/geometry model, also compiled by the command-line checks.
struct LandmarkSchedule {
    var intervalSeconds: Double = 10
    var landmarkCount: Int = 6
    var pulseSpacing: Double = 0.8

    var duration: Double { intervalSeconds * Double(landmarkCount) }
    var completionOffset: Double { pulseOffset(landmark: landmarkCount, pulse: landmarkCount) }
    var lateDiagnosticThreshold: Double { pulseSpacing / 2 }
    var isValid: Bool {
        intervalSeconds.isFinite && intervalSeconds > 0 &&
        (1...6).contains(landmarkCount) && pulseSpacing.isFinite &&
        pulseSpacing >= 0.5 && Double(landmarkCount) * pulseSpacing < intervalSeconds &&
        duration.isFinite && completionOffset.isFinite && completionOffset <= 86400
    }
    func pulseOffset(landmark: Int, pulse: Int) -> Double {
        Double(landmark) * intervalSeconds + Double(pulse) * pulseSpacing
    }
    func progress(elapsed: Double) -> Double { min(1, max(0, elapsed / duration)) }
    static func startAngle(at date: Date) -> Double {
        Double(Calendar.current.component(.second, from: date)) * .pi / 30
    }

    /// A frame may be requested ahead of real time. Project from a *fresh pair*
    /// of wall time and monotonic elapsed time, not the run's original wall date.
    /// A wall-clock correction shifts both frameDate and wallNow equally, so it
    /// cannot reset elapsed time. Minute rollover has no special meaning here.
    func frame(at frameDate: Date, wallNow: Date, elapsedNow: Double) -> LandmarkFrame {
        let elapsed = elapsedNow + frameDate.timeIntervalSince(wallNow)
        return LandmarkFrame(progress: progress(elapsed: elapsed),
                             isVisible: elapsed >= 0 && elapsed < completionOffset)
    }
}

struct LandmarkFrame {
    var progress: Double
    var isVisible: Bool
}

#if canImport(WatchKit) || CONTROLLER_CHECKS
#if !CONTROLLER_CHECKS
import WatchKit
#else
import Combine
#endif
import OSLog

@MainActor
final class LandmarkController: ObservableObject {
    // Legacy values remain decodable, even though new runs no longer emit them.
    enum Result: String {
        case ready, running, completed, stopped, vibrationsStopped, completedWithoutVibrations, interrupted
        var message: String {
            switch self {
            case .ready: ""
            case .running: "Counting"
            case .completed: "Count complete"
            case .stopped: "Count stopped"
            case .vibrationsStopped: "Vibrations off · arc continues"
            case .completedWithoutVibrations: "Count complete · vibrations stopped"
            case .interrupted: "Previous count interrupted"
            }
        }
    }
    struct Configuration {
        var schedule = LandmarkSchedule()
        var hapticsEnabled = true
        var acknowledgement: WKHapticType = .start
        // Physical-device trial: a more distinctive beat than the faint click.
        var beat: WKHapticType = .directionUp
    }
    @Published private(set) var isActive = false
    @Published private(set) var result: Result = .ready
    var lastResult: String { result.message }
    var diagnosticContext: () -> [String: String] = { [:] }
    private let journal: LandmarkDiagnostics
    private let defaults: UserDefaults
    private var runID: String?
    init(defaults: UserDefaults = .standard, journal: LandmarkDiagnostics = LandmarkDiagnostics()) {
        self.defaults = defaults
        self.journal = journal
        if let saved = defaults.string(forKey: "landmarkResult.v2"), let stored = Result(rawValue: saved) {
            // Never claim that a run survived process termination.
            result = [.running, .vibrationsStopped].contains(stored) ? .interrupted : stored
        } else {
            switch defaults.string(forKey: "landmarkLastResult") ?? "" {
            case "Count completed", "Count complete": result = .completed
            case "Count cancelled", "Count stopped": result = .stopped
            case "Count complete · haptics stopped", "Count done · taps off": result = .completedWithoutVibrations
            case "": result = .ready
            default: result = .interrupted
            }
        }
        defaults.set(result.rawValue, forKey: "landmarkResult.v2")
    }
#if CONTROLLER_CHECKS
    var testNow: () -> ContinuousClock.Instant = { ContinuousClock().now }
    var testSleep: (ContinuousClock.Instant) async throws -> Void = { try await ContinuousClock().sleep(until: $0) }
#endif
    private func now() -> ContinuousClock.Instant {
#if CONTROLLER_CHECKS
        testNow()
#else
        ContinuousClock().now
#endif
    }
    private func sleep(until deadline: ContinuousClock.Instant) async throws {
#if CONTROLLER_CHECKS
        try await testSleep(deadline)
#else
        try await ContinuousClock().sleep(until: deadline)
#endif
    }
    // Diagnostic bookkeeping is not displayed. Avoid invalidating all clock
    // pages twice per beat; only active/inactive changes need UI publication.
    private(set) var beatsDelivered = 0
    private(set) var nextScheduledBeat: Date?
    private(set) var configuration = Configuration()
    private(set) var startAngle: Double = 0
    private var anchor: ContinuousClock.Instant?
    private var task: Task<Void, Never>?
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "net.qays.TeachingTimer", category: "Landmarks")
    var beatsRemaining: Int { max(0, configuration.schedule.landmarkCount - beatsDelivered) }
    /// Read by the existing one-second timeline; no per-pulse UI publication.
    var progress: Double {
        guard isActive, let anchor else { return 0 }
        let elapsed = anchor.duration(to: now()).components
        return configuration.schedule.progress(elapsed: Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18)
    }

    /// Use the requested timeline date for drawing, including pre-rendered
    /// Always-On frames. Scheduling/expiry remain on ContinuousClock.
    func frame(at date: Date) -> LandmarkFrame {
        guard isActive, let anchor else { return LandmarkFrame(progress: 0, isVisible: false) }
        let monotonicNow = now()
        let wallNow = Date()
        return configuration.schedule.frame(at: date, wallNow: wallNow,
            elapsedNow: Self.seconds(anchor.duration(to: monotonicNow)))
    }
    func start(configuration: Configuration = Configuration()) {
        guard !isActive, configuration.schedule.isValid else { return }
        self.configuration = configuration
        beatsDelivered = 0
        let anchor = now()
        self.anchor = anchor
        let wallAnchor = Date()
        startAngle = LandmarkSchedule.startAngle(at: wallAnchor)
        let schedule = configuration.schedule
        nextScheduledBeat = configuration.hapticsEnabled ? wallAnchor.addingTimeInterval(schedule.intervalSeconds) : nil
        isActive = true
        setResult(.running)
        let diagnosticRun = UUID().uuidString
        runID = diagnosticRun
        record("landmark_started", extra: ["intervalSeconds": String(schedule.intervalSeconds),
            "landmarkCount": String(schedule.landmarkCount), "pulseSpacing": String(schedule.pulseSpacing),
            "lateDiagnosticThresholdSeconds": String(schedule.lateDiagnosticThreshold),
            "latePolicy": "continue_spaced_skip_obsolete_groups", "hapticsEnabled": String(configuration.hapticsEnabled)])
        if configuration.hapticsEnabled {
        let acknowledgementElapsed = anchor.duration(to: now()).components
        let acknowledgementSeconds = Double(acknowledgementElapsed.seconds) + Double(acknowledgementElapsed.attoseconds) / 1e18
        log.notice("haptic_submit run=\(diagnosticRun, privacy: .public) kind=ack elapsed=\(acknowledgementSeconds) landmark=0 pulse=0 count=0 haptic=\(configuration.acknowledgement.rawValue)")
        WKInterfaceDevice.current().play(configuration.acknowledgement)
        record("haptic_submitted", extra: ["kind": "ack", "scheduledElapsed": "0",
            "actualElapsed": String(acknowledgementSeconds), "lateness": String(acknowledgementSeconds),
            "landmark": "0", "pulse": "0", "count": "0", "hapticType": String(configuration.acknowledgement.rawValue),
            "hapticName": Self.hapticName(configuration.acknowledgement)])
        }
        log.notice("Landmarks activated; first group in \(schedule.intervalSeconds) seconds")
        task = Task { [weak self] in
            var lastSubmission: ContinuousClock.Instant?
            for index in 1...schedule.landmarkCount {
                guard configuration.hapticsEnabled else { break }
                var submittedGroup = true
                for pulse in 0..<index {
                    let offset = schedule.pulseOffset(landmark: index, pulse: pulse)
                    let scheduled = anchor.advanced(by: .seconds(offset))
                    // Keep absolute landmark anchors, but never compress delayed
                    // pulses into a burst. A delayed submission shifts spacing only.
                    let deadline = max(scheduled, lastSubmission?.advanced(by: .seconds(schedule.pulseSpacing)) ?? scheduled)
                    do { try await self?.sleep(until: deadline) } catch { return }
                    guard let self, !Task.isCancelled, self.isActive, self.runID == diagnosticRun else { return }
                    let instant = self.now()
                    let actual = Self.seconds(anchor.duration(to: instant))
                    let lateness = actual - offset
                    // Do not replay an obsolete group across the next landmark
                    // or after the count's original completion. Later groups keep
                    // their original deadlines and are still attempted.
                    let groupEnd = index < schedule.landmarkCount
                        ? Double(index + 1) * schedule.intervalSeconds : schedule.completionOffset
                    let remaining = Double(index - pulse - 1) * schedule.pulseSpacing
                    guard actual + remaining < groupEnd else {
                        submittedGroup = false
                        self.record("landmark_group_skipped", extra: ["reason": "group_window_elapsed",
                            "landmark": String(index), "pulse": String(pulse + 1), "count": String(index),
                            "scheduledElapsed": String(offset), "actualElapsed": String(actual),
                            "lateness": String(lateness), "windowEnd": String(groupEnd)], flush: true)
                        break
                    }
                    if lateness >= schedule.lateDiagnosticThreshold {
                        self.record("landmark_pulse_late", extra: ["landmark": String(index),
                            "pulse": String(pulse + 1), "count": String(index),
                            "scheduledElapsed": String(offset), "actualElapsed": String(actual),
                            "lateness": String(lateness), "action": "submit_and_continue"])
                    }
                    lastSubmission = instant
                    let diagnosticElapsed = anchor.duration(to: self.now()).components
                    let diagnosticSeconds = Double(diagnosticElapsed.seconds) + Double(diagnosticElapsed.attoseconds) / 1e18
                    self.log.notice("haptic_submit run=\(diagnosticRun, privacy: .public) kind=landmark elapsed=\(diagnosticSeconds) landmark=\(index) pulse=\(pulse + 1) count=\(index) haptic=\(configuration.beat.rawValue)")
                    WKInterfaceDevice.current().play(configuration.beat)
                    self.record("haptic_submitted", extra: ["kind": "landmark", "landmark": String(index),
                        "pulse": String(pulse + 1), "count": String(index),
                        "hapticType": String(configuration.beat.rawValue),
                        "hapticName": Self.hapticName(configuration.beat),
                        "scheduledElapsed": String(schedule.pulseOffset(landmark: index, pulse: pulse)),
                        "actualElapsed": String(diagnosticSeconds),
                        "lateness": String(diagnosticSeconds - schedule.pulseOffset(landmark: index, pulse: pulse))])
                    self.log.notice("Landmark \(index), pulse \(pulse + 1)")
                }
                guard let self, !Task.isCancelled else { return }
                if submittedGroup { self.beatsDelivered += 1 }
                self.nextScheduledBeat = index < schedule.landmarkCount
                    ? wallAnchor.addingTimeInterval(schedule.intervalSeconds * Double(index + 1)) : nil
            }
            // Original visual lifetime: full at 60s, finished at 64.8s.
            // No re-anchoring, run-wide timeout, or compressed catch-up pulses.
            let end = schedule.completionOffset
            do { try await self?.sleep(until: anchor.advanced(by: .seconds(end))) } catch { return }
            guard let self, !Task.isCancelled, self.runID == diagnosticRun else { return }
            self.cancel(reason: "completed")
        }
    }
    private static func seconds(_ duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }
    private func setResult(_ value: Result) {
        result = value
        defaults.set(value.rawValue, forKey: "landmarkResult.v2")
    }
    private static func hapticName(_ type: WKHapticType) -> String {
        switch type {
        case .start: "start"
        case .directionUp: "directionUp"
        case .click: "click"
        case .stop: "stop"
        default: "raw_\(type.rawValue)"
        }
    }

    private func record(_ event: String, extra: [String: String] = [:], flush: Bool = false) {
        var details = diagnosticContext().merging(extra) { _, value in value }
        details["runID"] = runID ?? "none"
        details["appStateCode"] = String(WKApplication.shared().applicationState.rawValue)
        details["groupsDelivered"] = String(beatsDelivered)
        if let anchor { details["elapsedSeconds"] = String(Self.seconds(anchor.duration(to: now()))) }
        journal.record(event, details: details, flush: flush)
    }

    func cancel(reason: String = "user_cancelled", extra: [String: String] = [:]) {
        guard isActive else { return }
        record("landmark_ended", extra: extra.merging(["reason": reason]) { _, value in value }, flush: true)
        setResult(reason == "completed" ? .completed : .stopped)
        task?.cancel(); task = nil; anchor = nil; isActive = false; nextScheduledBeat = nil
        runID = nil
        log.notice("Landmarks ended: \(reason, privacy: .public)")
    }
}
#endif
