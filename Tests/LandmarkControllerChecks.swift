// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

enum WKHapticType: Int { case start, directionUp, click, stop, other }
enum WKApplicationState: Int { case active, inactive, background }
final class WKApplication {
    static let instance = WKApplication()
    static func shared() -> WKApplication { instance }
    var applicationState: WKApplicationState = .inactive
}
final class WKInterfaceDevice {
    static let instance = WKInterfaceDevice()
    static func current() -> WKInterfaceDevice { instance }
    var submissions: [WKHapticType] = []
    func play(_ type: WKHapticType) { submissions.append(type) }
}

@MainActor final class ManualClock {
    var now = ContinuousClock().now
    var waits: [(ContinuousClock.Instant, CheckedContinuation<Void, any Error>)] = []
    func sleep(until deadline: ContinuousClock.Instant) async throws {
        try await withCheckedThrowingContinuation { waits.append((deadline, $0)) }
    }
    func advanceNext(lateness: Double = 0) {
        let next = waits.removeFirst()
        now = next.0.advanced(by: .seconds(lateness))
        next.1.resume()
    }
}

@main struct LandmarkControllerChecks {
    @MainActor static func drain() async { for _ in 0..<30 { await Task.yield() } }
    @MainActor static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "LandmarkTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        let journalURL = directory.appendingPathComponent("LandmarkDiagnostics.json")
        let journal = LandmarkDiagnostics(url: journalURL)
        let model = LandmarkController(defaults: defaults, journal: journal)
        let clock = ManualClock()
        model.testNow = { clock.now }
        model.testSleep = { try await clock.sleep(until: $0) }
        model.diagnosticContext = { ["runtimePhase": "running", "sceneState": "inactive"] }
        let device = WKInterfaceDevice.current()

        // Cancel partway into group 5, then group 6. Resume a stale suspended
        // task after the fresh run has started: it must submit no old pulses.
        for group in [5, 6] {
            model.start(); await drain()
            let pulsesBeforeGroup = (group - 1) * group / 2
            for _ in 0..<(pulsesBeforeGroup + 2) { clock.advanceNext(); await drain() }
            model.cancel()
            let afterCancel = device.submissions.count
            model.start(); await drain()
            assert(device.submissions.count == afterCancel + 1) // new acknowledgement only
            clock.advanceNext(); await drain() // stale old-generation waiter
            assert(device.submissions.count == afterCancel + 1)
            clock.advanceNext(); await drain() // new run's first landmark
            assert(device.submissions.count == afterCancel + 2)
            model.cancel(reason: "new_class_reset")
            clock.advanceNext(); await drain()
        }
        // Exact lateness boundary stops haptics only; below it submits a beat.
        model.start(); await drain()
        clock.advanceNext(lateness: 0.399); await drain()
        assert(model.isActive)
        let beforeLate = device.submissions.count
        clock.advanceNext(lateness: 0.4); await drain()
        assert(model.isActive && model.hapticsStopped && device.submissions.count == beforeLate)
        assert(model.result == .vibrationsStopped)
        assert(LandmarkController(defaults: defaults, journal: journal).result == .interrupted)
        let originalAngle = model.startAngle
        let progressAtFailure = model.progress
        // Exercise the production drawing entry point, not just its underlying
        // elapsed-time getter: silent runs must still supply visible frames.
        let frameAtFailure = model.frame(at: Date())
        let futureFrame = model.frame(at: Date().addingTimeInterval(10))
        assert(frameAtFailure.isVisible && futureFrame.isVisible)
        assert(abs(frameAtFailure.progress - progressAtFailure) < 0.001)
        assert(abs(futureFrame.progress - (progressAtFailure + 10.0 / 60)) < 0.001)
        assert(!model.frame(at: Date().addingTimeInterval(100)).isVisible)
        clock.now = clock.now.advanced(by: .seconds(10))
        assert(model.progress > progressAtFailure && model.startAngle == originalAngle)
        assert(device.submissions.count == beforeLate) // no more pulse deadlines queued
        clock.advanceNext(); await drain() // original 64.8s completion, not a new minute
        assert(!model.isActive && model.result == .completedWithoutVibrations)
        assert(device.submissions.count == beforeLate)
        // Both explicit end actions also cancel a silent visual run immediately.
        for reason in ["user_cancelled", "new_class_reset"] {
            model.start(); await drain()
            clock.advanceNext(lateness: 0.41); await drain()
            assert(model.isActive && model.hapticsStopped)
            model.cancel(reason: reason)
            assert(!model.isActive && model.progress == 0)
            assert(!model.frame(at: Date()).isVisible)
            clock.advanceNext(); await drain() // cancelled completion must not overwrite result
            assert(model.lastResult == "Count stopped")
        }
        // Full original schedule: 21 timed pulses, then completion at 64.8s.
        model.start(); await drain()
        let anchor = clock.now
        let beforeFull = device.submissions.count
        for _ in 0..<21 { clock.advanceNext(); await drain() }
        assert(model.isActive && device.submissions.count == beforeFull + 21)
        assert(anchor.duration(to: clock.now) == .seconds(64))
        clock.advanceNext(); await drain()
        assert(anchor.duration(to: clock.now) == .seconds(64.8))
        assert(!model.isActive && model.lastResult == "Count complete")
        // Arc-only preference makes no acknowledgement or timed haptic requests;
        // it retains the same 60-second arc and 64.8-second visual lifetime.
        let beforeSilent = device.submissions.count
        model.start(configuration: .init(hapticsEnabled: false)); await drain()
        assert(model.isActive && !model.hapticsStopped && model.nextScheduledBeat == nil)
        assert(model.frame(at: Date().addingTimeInterval(30)).isVisible)
        clock.advanceNext(); await drain()
        assert(!model.isActive && model.result == .completed)
        assert(device.submissions.count == beforeSilent)
        assert(defaults.string(forKey: "landmarkResult.v2") == "completed")
        await journal.flush()
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let events = try decoder.decode([LandmarkDiagnostics.Event].self, from: Data(contentsOf: journalURL))
        for reason in ["user_cancelled", "new_class_reset", "completed"] {
            assert(events.contains { $0.event == "landmark_ended" && $0.details["reason"] == reason })
        }
        let late = events.first { $0.details["reason"] == "missed_deadline" }!
        assert(late.event == "landmark_haptics_stopped")
        assert(!events.contains { $0.event == "landmark_ended" && $0.details["reason"] == "missed_deadline" })
        assert(late.details["runtimePhase"] == "running" && late.details["sceneState"] == "inactive")
        assert(late.details["pulse"] == "1" && late.details["landmark"] == "2")
        assert(events.contains { $0.details["hapticName"] == "directionUp" })
        print("PASS: groups 5/6 cancellation and restart isolation, late haptics stop independently, arc/anchor survive, explicit Stop/Reset cancel both, 21 pulses, 64.8s completion, persistent end reasons")
    }
}
