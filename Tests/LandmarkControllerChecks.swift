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
        now = max(now, next.0.advanced(by: .seconds(lateness)))
        next.1.resume()
    }
}

@main struct LandmarkControllerChecks {
    static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
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

        // Reject malformed future presets before changing state, writing a run,
        // scheduling work, or submitting even the acknowledgement haptic.
        for schedule in [LandmarkSchedule(intervalSeconds: .nan),
                         LandmarkSchedule(landmarkCount: 0),
                         LandmarkSchedule(pulseSpacing: 2)] {
            model.start(configuration: .init(schedule: schedule))
            await drain()
            assert(!model.isActive && model.result == .ready)
            assert(device.submissions.isEmpty && clock.waits.isEmpty)
        }
        model.start(); await drain()
        let originalStartAngle = model.startAngle
        let originalWait = clock.waits.first!.0
        let submittedAtStart = device.submissions.count
        model.start(configuration: .init(hapticsEnabled: false)); await drain()
        assert(model.isActive && model.configuration.hapticsEnabled)
        assert(model.startAngle == originalStartAngle)
        assert(clock.waits.count == 1 && clock.waits.first!.0 == originalWait)
        assert(device.submissions.count == submittedAtStart)
        model.cancel(); clock.advanceNext(); await drain()

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
        // Former 0.4-second cutoff is diagnostic only. Even a two-second
        // delay submits the pulse and preserves later absolute group anchors.
        model.start(); await drain()
        clock.advanceNext(lateness: 2); await drain()
        assert(model.isActive)
        let beforeLate = device.submissions.count
        clock.advanceNext(lateness: 0.4); await drain()
        assert(model.isActive && device.submissions.count == beforeLate + 1)
        assert(model.result == .running)
        assert(LandmarkController(defaults: defaults, journal: journal).result == .interrupted)
        let originalAngle = model.startAngle
        let progressAtFailure = model.progress
        let frameAtFailure = model.frame(at: Date())
        let futureFrame = model.frame(at: Date().addingTimeInterval(10))
        assert(frameAtFailure.isVisible && futureFrame.isVisible)
        assert(abs(frameAtFailure.progress - progressAtFailure) < 0.001)
        assert(abs(futureFrame.progress - (progressAtFailure + 10.0 / 60)) < 0.001)
        assert(!model.frame(at: Date().addingTimeInterval(100)).isVisible)
        let previousPulse = clock.now
        clock.advanceNext(); await drain()
        assert(previousPulse.duration(to: clock.now) >= .seconds(0.8))
        assert(model.startAngle == originalAngle)
        model.cancel(); clock.advanceNext(); await drain()

        // After suspension past several groups, skip obsolete groups but do not
        // disable the rest of the run or submit a burst of overdue pulses.
        model.start(); await drain()
        let longAnchor = clock.now
        let beforeSuspension = device.submissions.count
        clock.advanceNext(lateness: 25); await drain() // group 1 wakes at 35s
        assert(device.submissions.count == beforeSuspension)
        clock.advanceNext(); await drain() // group 2 is obsolete too
        assert(device.submissions.count == beforeSuspension)
        clock.advanceNext(); await drain() // group 3 can still fit before 40s
        assert(device.submissions.count == beforeSuspension + 1)
        clock.advanceNext(); await drain()
        assert(abs(seconds(longAnchor.duration(to: clock.now)) - 35.8) < 0.000001)
        model.cancel(); clock.advanceNext(); await drain()
        // Explicit Stop and Reset still cancel immediately, even after lateness.
        for reason in ["user_cancelled", "new_class_reset"] {
            model.start(); await drain()
            clock.advanceNext(lateness: 0.41); await drain()
            assert(model.isActive)
            model.cancel(reason: reason)
            assert(!model.isActive && model.progress == 0)
            assert(!model.frame(at: Date()).isVisible)
            clock.advanceNext(); await drain()
            assert(model.lastResult == "Count stopped")
        }
        // A run resumed after its entire lifetime emits no old haptics.
        model.start(); await drain()
        let afterAck = device.submissions.count
        for _ in 0..<6 { clock.advanceNext(lateness: 100); await drain() }
        clock.advanceNext(); await drain()
        assert(!model.isActive && device.submissions.count == afterAck)
        // Full original schedule: 21 timed pulses, then completion at 64.8s.
        model.start(); await drain()
        let anchor = clock.now
        let beforeFull = device.submissions.count
        for _ in 0..<21 { clock.advanceNext(); await drain() }
        assert(model.isActive && device.submissions.count == beforeFull + 21)
        assert(abs(seconds(anchor.duration(to: clock.now)) - 64) < 0.000001)
        clock.advanceNext(); await drain()
        assert(abs(seconds(anchor.duration(to: clock.now)) - 64.8) < 0.000001)
        assert(!model.isActive && model.lastResult == "Count complete")
        // Arc-only preference makes no acknowledgement or timed haptic requests;
        // it retains the same 60-second arc and 64.8-second visual lifetime.
        let beforeSilent = device.submissions.count
        model.start(configuration: .init(hapticsEnabled: false)); await drain()
        assert(model.isActive && model.nextScheduledBeat == nil)
        assert(model.frame(at: Date().addingTimeInterval(30)).isVisible)
        clock.advanceNext(); await drain()
        assert(!model.isActive && model.result == .completed)
        assert(device.submissions.count == beforeSilent)
        assert(defaults.string(forKey: "landmarkResult.v2") == "completed")
        // Cancel an arc-only run, then restart before its old completion wakes.
        // The old completion must neither end the new run nor submit haptics.
        model.start(configuration: .init(hapticsEnabled: false)); await drain()
        model.cancel()
        model.start(); await drain()
        let freshAck = device.submissions.count
        clock.advanceNext(); await drain() // Old silent completion is now stale.
        assert(model.isActive && model.result == .running)
        assert(device.submissions.count == freshAck)
        model.cancel(); clock.advanceNext(); await drain()
        // Legacy saved outcomes remain readable after removing unreachable live state.
        defaults.set("completedWithoutVibrations", forKey: "landmarkResult.v2")
        assert(LandmarkController(defaults: defaults, journal: journal).result == .completedWithoutVibrations)
        defaults.set("vibrationsStopped", forKey: "landmarkResult.v2")
        assert(LandmarkController(defaults: defaults, journal: journal).result == .interrupted)
        await journal.flush()
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let events = try decoder.decode([LandmarkDiagnostics.Event].self, from: Data(contentsOf: journalURL))
        for reason in ["user_cancelled", "new_class_reset", "completed"] {
            assert(events.contains { $0.event == "landmark_ended" && $0.details["reason"] == reason })
        }
        let late = events.first { $0.event == "landmark_pulse_late" }!
        assert(!events.contains { $0.event == "landmark_haptics_stopped" })
        assert(late.details["runtimePhase"] == "running" && late.details["sceneState"] == "inactive")
        assert(late.details["pulse"] == "1" && late.details["landmark"] == "1")
        assert(events.contains { $0.event == "landmark_group_skipped" })
        assert(events.contains { $0.details["hapticName"] == "directionUp" })
        print("PASS: groups 5/6 cancellation and restart isolation, late pulses continue with spacing, obsolete groups skip without disabling, arc/anchor survive, explicit Stop/Reset cancel both, 21 pulses, 64.8s completion, persistent end reasons")
    }
}
