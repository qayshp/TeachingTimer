// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

// Minimal WatchKit boundary double. Tests exercise the actual controller,
// including asynchronous delegate callbacks, not a duplicate state machine.
enum WKApplicationState: Int { case active, inactive, background }
final class WKApplication {
    static let instance = WKApplication()
    static func shared() -> WKApplication { instance }
    var applicationState: WKApplicationState = .active
}
enum WKExtendedRuntimeSessionInvalidationReason: Int { case error = -1, none, sessionInProgress, expired, resignedFrontmost, suppressedBySystem }
enum WKExtendedRuntimeSessionState { case notStarted, running, invalid }
protocol WKExtendedRuntimeSessionDelegate: AnyObject {
    func extendedRuntimeSessionDidStart(_ session: WKExtendedRuntimeSession)
    func extendedRuntimeSessionWillExpire(_ session: WKExtendedRuntimeSession)
    func extendedRuntimeSession(_ session: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: (any Error)?)
}
final class WKExtendedRuntimeSession {
    static var instances: [WKExtendedRuntimeSession] = []
    weak var delegate: WKExtendedRuntimeSessionDelegate?
    var state: WKExtendedRuntimeSessionState = .notStarted
    var expirationDate: Date? = Date().addingTimeInterval(3600)
    var invalidationRequests = 0
    var startRequests = 0
    init() { Self.instances.append(self) }
    func start() { startRequests += 1 } // Success/failure is independently driven by the test.
    func invalidate() { invalidationRequests += 1 }
    func confirmStart() { state = .running; delegate?.extendedRuntimeSessionDidStart(self) }
    func warn() { delegate?.extendedRuntimeSessionWillExpire(self) }
    func end(_ reason: WKExtendedRuntimeSessionInvalidationReason, error: NSError? = nil) {
        state = .invalid
        delegate?.extendedRuntimeSession(self, didInvalidateWith: reason, error: error)
    }
}

@main struct RuntimeRenewalChecks {
    @MainActor static func drain() async { for _ in 0..<30 { await Task.yield() } }
    @MainActor static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        func controller() throws -> ExtendedRuntimeController {
            WKApplication.shared().applicationState = .active
            let controller = ExtendedRuntimeController(journal: RuntimeDiagnostics(fileURL: directory.appendingPathComponent(UUID().uuidString)))
            controller.applicationStateChanged("active")
            return controller
        }
        let diagnosticSuite = "PersistenceIntent." + UUID().uuidString
        let diagnosticDefaults = UserDefaults(suiteName: diagnosticSuite)!
        defer { diagnosticDefaults.removePersistentDomain(forName: diagnosticSuite) }
        let absentIntent = RuntimeIntentStore(defaults: diagnosticDefaults)
        assert(absentIntent.takePersistenceEvents().first?.details["state"] == "absent")
        diagnosticDefaults.set(Data("broken-intent".utf8), forKey: "teachingRuntimeIntent.v1")
        let brokenIntent = RuntimeIntentStore(defaults: diagnosticDefaults)
        assert(brokenIntent.value == nil)
        assert(brokenIntent.takePersistenceEvents().first?.name == "persistence_read_failed")
        assert(diagnosticDefaults.dictionary(forKey: "teachingRuntimeIntent.v1.unreadable.v1")?["bytes"] as? Data == Data("broken-intent".utf8))
        brokenIntent.save(RuntimeIntent(classID: Date(), state: .stopped))
        assert(brokenIntent.takePersistenceEvents().first?.name == "persistence_saved")
        assert(RuntimeIntentStore(defaults: diagnosticDefaults).value?.state == .stopped)
        let now = Date(timeIntervalSince1970: 10000)
        assert(RuntimeRenewalRules.canHandoff(warned: true, expiration: now.addingTimeInterval(8), now: now, active: true, automatic: true, stopped: false))
        for delta in [-1.0, 0, 21] {
            assert(!RuntimeRenewalRules.canHandoff(warned: true, expiration: now.addingTimeInterval(delta), now: now, active: true, automatic: true, stopped: false))
        }
        for delta in [-3.0, 31] {
            assert(!RuntimeRenewalRules.isExpirationError(warned: true, expiration: now.addingTimeInterval(-delta), now: now, domain: "RBSAssertionErrorDomain", code: 1))
        }
        assert(!RuntimeRenewalRules.isExpirationError(warned: false, expiration: now, now: now, domain: "RBSAssertionErrorDomain", code: 1))
        assert(!RuntimeRenewalRules.isExpirationError(warned: true, expiration: now, now: now, domain: "other", code: 1))
        assert(!RuntimeRenewalRules.isExpirationError(warned: true, expiration: now, now: now, domain: "RBSAssertionErrorDomain", code: 2))
        // Boundary values and every eligibility gate matter: background,
        // explicit Stop and manual policy must never permit an early handoff.
        for remaining in [0.0, 0.001, 20.0, 20.001] {
            for warned in [false, true] {
                for active in [false, true] {
                    for automatic in [false, true] {
                        for stopped in [false, true] {
                            let eligible = warned && active && automatic && !stopped
                                && remaining > 0 && remaining <= 20
                            assert(RuntimeRenewalRules.canHandoff(warned: warned,
                                expiration: now.addingTimeInterval(remaining), now: now,
                                active: active, automatic: automatic, stopped: stopped) == eligible)
                        }
                    }
                }
            }
        }
        assert(!RuntimeRenewalRules.canHandoff(warned: true, expiration: nil, now: now,
            active: true, automatic: true, stopped: false))
        for delta in [-2.001, -2.0, 0.0, 30.0, 30.001] {
            assert(RuntimeRenewalRules.isExpirationError(warned: true,
                expiration: now.addingTimeInterval(-delta), now: now,
                domain: "RBSAssertionErrorDomain", code: 1) == (delta >= -2 && delta <= 30))
        }
        // Early active handoff: no overlap, only one invalidate request.
        let early = try controller()
        assert(early.actionTitle(hasClass: false) == "Start class")
        assert(early.actionTitle(hasClass: true) == "Start session")
        early.start()
        assert(early.actionTitle(hasClass: true) == "Starting…")
        let first = WKExtendedRuntimeSession.instances.last!
        first.confirmStart(); await drain()
        assert(early.actionTitle(hasClass: true) == "Stop session")
        first.expirationDate = Date().addingTimeInterval(15)
        first.warn(); await drain()
        assert(first.invalidationRequests == 1)
        let count = WKExtendedRuntimeSession.instances.count
        early.applicationBecameActive(); early.applicationBecameActive()
        assert(WKExtendedRuntimeSession.instances.count == count && first.invalidationRequests == 1)
        // Wrist lowers during handoff; wait for activation after invalidation.
        WKApplication.shared().applicationState = .inactive
        first.end(.none); await drain()
        assert(WKExtendedRuntimeSession.instances.count == count)
        WKApplication.shared().applicationState = .active
        early.applicationBecameActive()
        assert(WKExtendedRuntimeSession.instances.count == count + 1)
        let replacement = WKExtendedRuntimeSession.instances.last!
        replacement.end(.error, error: NSError(domain: "RBSAssertionErrorDomain", code: 1)); await drain()
        early.applicationBecameActive(); early.applicationBecameActive()
        assert(WKExtendedRuntimeSession.instances.count == count + 1 && early.needsRestart)
        // Early handoff must use the same scene/native readiness as restored
        // recovery. Do not invalidate a working runtime on native state alone.
        let sceneHandoff = try controller(); sceneHandoff.start()
        let sceneOld = WKExtendedRuntimeSession.instances.last!
        sceneOld.confirmStart(); await drain()
        sceneHandoff.applicationStateChanged("inactive")
        sceneOld.expirationDate = Date().addingTimeInterval(15)
        sceneOld.warn(); await drain()
        sceneHandoff.applicationBecameActive()
        assert(sceneOld.invalidationRequests == 0)
        sceneHandoff.applicationStateChanged("active")
        sceneHandoff.applicationBecameActive(); sceneHandoff.applicationBecameActive()
        assert(sceneOld.invalidationRequests == 1)
        let beforeSceneSuccessor = WKExtendedRuntimeSession.instances.count
        sceneHandoff.applicationStateChanged("inactive")
        sceneOld.end(.none); await drain()
        assert(WKExtendedRuntimeSession.instances.count == beforeSceneSuccessor)
        sceneHandoff.applicationStateChanged("active")
        sceneHandoff.applicationBecameActive(); sceneHandoff.applicationBecameActive()
        assert(WKExtendedRuntimeSession.instances.count == beforeSceneSuccessor + 1)
        // Reproduce the captured expiration-shaped error while inactive.
        let late = try controller(); late.start()
        let second = WKExtendedRuntimeSession.instances.last!
        second.confirmStart(); await drain()
        WKApplication.shared().applicationState = .inactive
        second.expirationDate = Date().addingTimeInterval(-1)
        second.warn(); await drain()
        second.end(.error, error: NSError(domain: "RBSAssertionErrorDomain", code: 1)); await drain()
        let beforeRestart = WKExtendedRuntimeSession.instances.count
        WKApplication.shared().applicationState = .active
        late.applicationBecameActive()
        assert(WKExtendedRuntimeSession.instances.count == beforeRestart + 1)
        WKExtendedRuntimeSession.instances.last!.confirmStart(); await drain()
        assert(late.phase == .running)
        // Explicit stop during handoff wins over pending renewal.
        let stopped = try controller(); stopped.start()
        let third = WKExtendedRuntimeSession.instances.last!
        third.confirmStart(); await drain()
        third.expirationDate = Date().addingTimeInterval(10)
        third.warn(); await drain()
        stopped.stop(source: "new_class_reset")
        third.end(.none); await drain()
        let afterStop = WKExtendedRuntimeSession.instances.count
        stopped.applicationBecameActive()
        assert(stopped.phase == .stopped && WKExtendedRuntimeSession.instances.count == afterStop)
        assert(stopped.actionTitle(hasClass: true) == "Resume session")
        assert(stopped.actionTitle(hasClass: false) == "Start class")
        // An aged-out class cancels pending foreground recovery before it runs.
        let retired = try controller(); retired.start()
        let retirementSession = WKExtendedRuntimeSession.instances.last!
        retirementSession.confirmStart(); await drain()
        WKApplication.shared().applicationState = .inactive
        retirementSession.end(.resignedFrontmost); await drain()
        let beforeRetirement = WKExtendedRuntimeSession.instances.count
        retired.stop(source: "class_retired", details: ["classDurationMinutes": "60"])
        WKApplication.shared().applicationState = .active
        retired.applicationBecameActive(); await drain()
        assert(retired.phase == .stopped && WKExtendedRuntimeSession.instances.count == beforeRetirement)
        // User-initiated policy never performs an early handoff or automatic restart.
        let manual = try controller(); manual.renewalPolicy = .userInitiated; manual.start()
        let fourth = WKExtendedRuntimeSession.instances.last!
        fourth.confirmStart(); await drain()
        fourth.expirationDate = Date().addingTimeInterval(10)
        fourth.warn(); await drain()
        assert(fourth.invalidationRequests == 0)
        fourth.end(.expired); await drain()
        manual.applicationBecameActive()
        assert(WKExtendedRuntimeSession.instances.last === fourth && manual.needsRestart)
        // Ordinary errors do not renew. A warning far from expiration also
        // cannot turn an unrelated failure into a renewable expiration.
        for warned in [false, true] {
            let failure = try controller(); failure.start()
            let current = WKExtendedRuntimeSession.instances.last!
            current.confirmStart(); await drain()
            if warned { current.warn(); await drain() }
            current.end(.error, error: NSError(domain: "RBSAssertionErrorDomain", code: 1)); await drain()
            failure.applicationBecameActive()
            assert(WKExtendedRuntimeSession.instances.last === current && failure.needsRestart)
        }
        // Existing foreground-loss recovery still works, and stale callbacks
        // from the old object cannot disturb the new running session.
        let foreground = try controller(); foreground.start()
        let old = WKExtendedRuntimeSession.instances.last!
        old.confirmStart(); await drain()
        old.end(.resignedFrontmost); await drain()
        let fresh = WKExtendedRuntimeSession.instances.last!
        assert(fresh !== old)
        fresh.confirmStart(); await drain()
        old.end(.error); old.warn(); old.confirmStart(); await drain()
        assert(foreground.phase == .running)
        // Queued delegate identity tokens retain their native object just until
        // delivery, so a stale callback cannot alias a new object's reused address.
        // They must neither mutate the current runtime nor leak the stale session.
        var unrelated: WKExtendedRuntimeSession? = WKExtendedRuntimeSession()
        weak let pendingCallbackSession = unrelated
        foreground.extendedRuntimeSessionDidStart(unrelated!)
        foreground.extendedRuntimeSessionWillExpire(unrelated!)
        foreground.extendedRuntimeSession(unrelated!, didInvalidateWith: .error, error: nil)
        WKExtendedRuntimeSession.instances.removeAll { $0 === unrelated }
        unrelated = nil
        assert(pendingCallbackSession != nil)
        await drain()
        assert(pendingCallbackSession == nil)
        assert(foreground.phase == .running && fresh.invalidationRequests == 0)

        // Explicit Stop while start is awaiting didStart must invalidate it,
        // without allowing any automatic successor.
        let starting = try controller(); starting.start()
        let inFlight = WKExtendedRuntimeSession.instances.last!
        starting.stop(); inFlight.confirmStart(); await drain()
        assert(inFlight.invalidationRequests == 1)
        inFlight.end(.none); await drain(); starting.applicationBecameActive()
        assert(starting.phase == .stopped && WKExtendedRuntimeSession.instances.last === inFlight)
        assert(starting.actionTitle(hasClass: true) == "Start session")
        // End class and immediately Start a new class before the old session's
        // invalidation callback arrives. The explicit Start must wait, not vanish
        // or overlap the old object. Exercise both start-in-flight and running
        // predecessors, and either order of invalidation / active callbacks.
        for oldDidStart in [false, true] {
            for inactiveAtInvalidation in [false, true] {
                let queued = try controller()
                let previousClass = ClassContext(pressedAt: Date(), scheduledStart: Date())
                queued.synchronizeClass(previousClass)
                queued.start()
                let ending = WKExtendedRuntimeSession.instances.last!
                if oldDidStart { ending.confirmStart(); await drain() }
                queued.stop(source: "new_class_reset")
                queued.synchronizeClass(nil)
                let nextClass = ClassContext(pressedAt: previousClass.initialStartPressedAt.addingTimeInterval(1),
                                             scheduledStart: Date())
                queued.synchronizeClass(nextClass)
                queued.start(); queued.start() // Duplicate taps cannot queue two objects.
                let beforeQueuedStart = WKExtendedRuntimeSession.instances.count
                queued.applicationBecameActive()
                assert(WKExtendedRuntimeSession.instances.count == beforeQueuedStart)
                if !oldDidStart {
                    ending.confirmStart(); await drain()
                    assert(ending.invalidationRequests == 1)
                }
                if inactiveAtInvalidation { WKApplication.shared().applicationState = .inactive }
                ending.end(.none); await drain()
                if inactiveAtInvalidation {
                    assert(queued.phase == .stopped && WKExtendedRuntimeSession.instances.count == beforeQueuedStart)
                    WKApplication.shared().applicationState = .active
                    queued.applicationBecameActive()
                }
                assert(WKExtendedRuntimeSession.instances.count == beforeQueuedStart + 1)
                let successor = WKExtendedRuntimeSession.instances.last!
                successor.confirmStart(); await drain()
                queued.applicationBecameActive(); ending.end(.none); await drain()
                assert(queued.phase == .running && WKExtendedRuntimeSession.instances.last === successor)
            }
        }
        // A later explicit Stop, reset, different class, or retirement cancels
        // the queued request. The old callback must not resurrect that intent.
        for cancellation in ["stop", "reset", "different_class", "retirement"] {
            let queued = try controller()
            let initial = ClassContext(pressedAt: Date(), scheduledStart: Date())
            queued.synchronizeClass(initial)
            queued.start()
            let ending = WKExtendedRuntimeSession.instances.last!
            ending.confirmStart(); await drain()
            queued.stop()
            let next = ClassContext(pressedAt: initial.initialStartPressedAt.addingTimeInterval(1),
                                    scheduledStart: Date())
            queued.synchronizeClass(next)
            queued.start()
            switch cancellation {
            case "stop": queued.stop()
            case "reset": queued.synchronizeClass(nil)
            case "different_class":
                queued.synchronizeClass(ClassContext(pressedAt: initial.initialStartPressedAt.addingTimeInterval(2),
                                                      scheduledStart: Date()))
            default:
                queued.synchronizeClass(ClassContext(pressedAt: next.initialStartPressedAt,
                                                      scheduledStart: Date().addingTimeInterval(-10000)))
            }
            let beforeCancelledStart = WKExtendedRuntimeSession.instances.count
            ending.end(.none); await drain()
            queued.applicationBecameActive(); await drain()
            assert(queued.phase == .stopped && WKExtendedRuntimeSession.instances.count == beforeCancelledStart)
        }
        // A queued explicit Start is still asynchronous: the scene may become
        // inactive before the old runtime invalidates even while native state
        // says active. Preserve the request through either callback order and
        // require both readiness signals before creating its one successor.
        for activationComesFirst in [false, true] {
            let queued = try controller()
            queued.renewalPolicy = .userInitiated // This remains an explicit request.
            let initial = ClassContext(pressedAt: Date(), scheduledStart: Date())
            queued.synchronizeClass(initial); queued.start()
            let ending = WKExtendedRuntimeSession.instances.last!
            ending.confirmStart(); await drain(); queued.stop()
            let next = ClassContext(pressedAt: initial.initialStartPressedAt.addingTimeInterval(1), scheduledStart: Date())
            queued.synchronizeClass(next); queued.start()
            queued.applicationStateChanged("inactive")
            let before = WKExtendedRuntimeSession.instances.count
            queued.applicationBecameActive()
            assert(WKExtendedRuntimeSession.instances.count == before)
            if activationComesFirst {
                queued.applicationStateChanged("active")
                queued.applicationBecameActive()
                assert(WKExtendedRuntimeSession.instances.count == before) // Old object still exists.
                ending.end(.none); await drain()
            } else {
                ending.end(.none); await drain()
                queued.applicationBecameActive(); queued.applicationBecameActive()
                assert(queued.phase == .stopped && WKExtendedRuntimeSession.instances.count == before)
                WKApplication.shared().applicationState = .inactive
                queued.applicationStateChanged("active")
                queued.applicationBecameActive()
                assert(WKExtendedRuntimeSession.instances.count == before) // Scene readiness alone is insufficient.
                WKApplication.shared().applicationState = .active
                queued.applicationBecameActive()
            }
            assert(WKExtendedRuntimeSession.instances.count == before + 1)
            let successor = WKExtendedRuntimeSession.instances.last!
            successor.confirmStart(); await drain()
            queued.applicationBecameActive(); ending.end(.none); await drain()
            assert(queued.phase == .running && WKExtendedRuntimeSession.instances.last === successor)
        }
        // Cancellation after the old invalidation, while scene readiness is
        // still pending, also wins. No delayed callback may resurrect the Start.
        for cancellation in ["stop", "reset", "different_class", "retirement"] {
            let queued = try controller()
            let initial = ClassContext(pressedAt: Date(), scheduledStart: Date())
            queued.synchronizeClass(initial); queued.start()
            let ending = WKExtendedRuntimeSession.instances.last!
            ending.confirmStart(); await drain(); queued.stop()
            let next = ClassContext(pressedAt: initial.initialStartPressedAt.addingTimeInterval(1), scheduledStart: Date())
            queued.synchronizeClass(next); queued.start()
            queued.applicationStateChanged("inactive")
            let before = WKExtendedRuntimeSession.instances.count
            ending.end(.none); await drain()
            assert(WKExtendedRuntimeSession.instances.count == before)
            switch cancellation {
            case "stop": queued.stop()
            case "reset": queued.synchronizeClass(nil)
            case "different_class":
                queued.synchronizeClass(ClassContext(pressedAt: initial.initialStartPressedAt.addingTimeInterval(2), scheduledStart: Date()))
            default:
                queued.synchronizeClass(ClassContext(pressedAt: next.initialStartPressedAt, scheduledStart: Date().addingTimeInterval(-10000)))
            }
            queued.applicationStateChanged("active")
            queued.applicationBecameActive(); ending.end(.none); await drain()
            assert(queued.phase == .stopped && WKExtendedRuntimeSession.instances.count == before)
        }
        // Process recreation restores *intent*, never a WatchKit object. The
        // same defaults suite models storage shared by successive launches.
        let suite = "TeachingTimerRecoveryChecks." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let savedClass = ClassContext(pressedAt: Date(), scheduledStart: Date())
        func launch(_ context: ClassContext? = savedClass) -> ExtendedRuntimeController {
            let controller = ExtendedRuntimeController(
                journal: RuntimeDiagnostics(fileURL: directory.appendingPathComponent(UUID().uuidString)),
                intentStore: RuntimeIntentStore(defaults: UserDefaults(suiteName: suite)!))
            controller.applicationStateChanged("active")
            controller.synchronizeClass(context)
            return controller
        }
        WKApplication.shared().applicationState = .active
        let original = launch()
        let beforeLegacy = WKExtendedRuntimeSession.instances.count
        original.applicationBecameActive()
        assert(WKExtendedRuntimeSession.instances.count == beforeLegacy) // migration never guesses
        original.start(); WKExtendedRuntimeSession.instances.last!.confirmStart(); await drain()
        assert(RuntimeIntentStore(defaults: defaults).value?.state == .running)
        // No invalidation callback: model a force-killed old process.
        WKApplication.shared().applicationState = .inactive
        let reopened = launch()
        let beforeRecovery = WKExtendedRuntimeSession.instances.count
        reopened.applicationBecameActive()
        assert(WKExtendedRuntimeSession.instances.count == beforeRecovery)
        WKApplication.shared().applicationState = .active
        reopened.applicationBecameActive()
        reopened.synchronizeClass(savedClass); reopened.applicationBecameActive()
        assert(WKExtendedRuntimeSession.instances.count == beforeRecovery + 1)
        let recovered = WKExtendedRuntimeSession.instances.last!
        recovered.confirmStart(); await drain()
        assert(reopened.phase == .running)
        // Editing the schedule keeps identity and saved intent.
        let edited = ClassContext(pressedAt: savedClass.initialStartPressedAt,
                                  durationMinutes: 75, scheduledStart: savedClass.scheduledStart)
        reopened.synchronizeClass(edited)
        assert(RuntimeIntentStore(defaults: defaults).value?.state == .running)
        // Explicit stop survives death while invalidate is still pending.
        reopened.stop()
        let stoppedLaunch = launch(edited)
        stoppedLaunch.applicationBecameActive()
        assert(stoppedLaunch.phase == .stopped && WKExtendedRuntimeSession.instances.last === recovered)
        stoppedLaunch.start(); let resumed = WKExtendedRuntimeSession.instances.last!
        resumed.confirmStart(); await drain()
        let resumedLaunch = launch(edited)
        resumedLaunch.renewalPolicy = .userInitiated
        resumedLaunch.applicationBecameActive()
        assert(WKExtendedRuntimeSession.instances.last === resumed)
        resumedLaunch.renewalPolicy = .automatic
        resumedLaunch.applicationBecameActive()
        let rejected = WKExtendedRuntimeSession.instances.last!
        rejected.end(.error); await drain()
        let rejectedCount = WKExtendedRuntimeSession.instances.count
        resumedLaunch.synchronizeClass(edited); resumedLaunch.applicationBecameActive()
        launch(edited).applicationBecameActive()
        assert(WKExtendedRuntimeSession.instances.count == rejectedCount)
        assert(RuntimeIntentStore(defaults: defaults).value?.state == .manualRecovery)
        // Manual resume clears failure suppression; missing/new/retired class
        // cannot inherit the previous class's permission to run.
        resumedLaunch.start()
        assert(RuntimeIntentStore(defaults: defaults).value?.state == .running)
        let otherClass = ClassContext(pressedAt: Date().addingTimeInterval(1))
        let beforeOther = WKExtendedRuntimeSession.instances.count
        launch(otherClass).applicationBecameActive()
        assert(WKExtendedRuntimeSession.instances.count == beforeOther)
        assert(RuntimeIntentStore(defaults: defaults).value == nil)
        defaults.set(Data("invalid".utf8), forKey: "teachingRuntimeIntent.v1")
        launch().applicationBecameActive()
        assert(WKExtendedRuntimeSession.instances.count == beforeOther)
        RuntimeIntentStore(defaults: defaults).save(RuntimeIntent(classID: savedClass.initialStartPressedAt, state: .running))
        launch(nil).applicationBecameActive()
        assert(RuntimeIntentStore(defaults: defaults).value == nil)
        let expiredClass = ClassContext(pressedAt: savedClass.initialStartPressedAt,
                                       scheduledStart: Date().addingTimeInterval(-10000))
        RuntimeIntentStore(defaults: defaults).save(RuntimeIntent(classID: savedClass.initialStartPressedAt, state: .running))
        launch(expiredClass).applicationBecameActive()
        assert(WKExtendedRuntimeSession.instances.count == beforeOther)
        assert(RuntimeIntentStore(defaults: defaults).value == nil)
        // Dimmed relaunch regression: WatchKit's native application state can
        // be active before SwiftUI's scene is active. Do not consume restored
        // running intent or create a runtime until BOTH observations are active.
        let deferredClass = ClassContext(pressedAt: Date(), scheduledStart: Date())
        for cancellation in ["none", "stop", "reset", "different_class", "retirement", "manual_policy"] {
            RuntimeIntentStore(defaults: defaults).save(RuntimeIntent(classID: deferredClass.initialStartPressedAt, state: .running))
            let deferred = ExtendedRuntimeController(
                journal: RuntimeDiagnostics(fileURL: directory.appendingPathComponent(UUID().uuidString)),
                intentStore: RuntimeIntentStore(defaults: defaults))
            WKApplication.shared().applicationState = .active
            deferred.applicationStateChanged("inactive", details: ["luminanceReduced": "true"])
            deferred.synchronizeClass(deferredClass)
            let before = WKExtendedRuntimeSession.instances.count
            deferred.applicationBecameActive(); deferred.applicationBecameActive()
            assert(WKExtendedRuntimeSession.instances.count == before)
            assert(RuntimeIntentStore(defaults: defaults).value?.state == .running)
            switch cancellation {
            case "stop": deferred.stop()
            case "reset": deferred.synchronizeClass(nil)
            case "different_class":
                deferred.synchronizeClass(ClassContext(pressedAt: deferredClass.initialStartPressedAt.addingTimeInterval(1), scheduledStart: Date()))
            case "retirement":
                deferred.synchronizeClass(ClassContext(pressedAt: deferredClass.initialStartPressedAt, scheduledStart: Date().addingTimeInterval(-10000)))
            case "manual_policy": deferred.renewalPolicy = .userInitiated
            default: break
            }
            // A SwiftUI active transition alone is insufficient too.
            WKApplication.shared().applicationState = .inactive
            deferred.applicationStateChanged("active", details: ["luminanceReduced": "false"])
            deferred.applicationBecameActive()
            assert(WKExtendedRuntimeSession.instances.count == before)
            WKApplication.shared().applicationState = .active
            deferred.applicationBecameActive(); deferred.applicationBecameActive()
            if cancellation == "none" {
                assert(WKExtendedRuntimeSession.instances.count == before + 1)
                let recovered = WKExtendedRuntimeSession.instances.last!
                recovered.confirmStart(); await drain()
                assert(deferred.phase == .running)
                assert(RuntimeIntentStore(defaults: defaults).value == RuntimeIntent(classID: deferredClass.initialStartPressedAt, state: .running))
                deferred.applicationBecameActive()
                assert(WKExtendedRuntimeSession.instances.last === recovered)
            } else {
                assert(WKExtendedRuntimeSession.instances.count == before)
            }
        }
        await checkPersistedDimmedRelaunch(in: directory)
        // UI observations share launch/runtime correlation without starting,
        // invalidating, renewing, or publishing any session state.
        let diagnosticURL = directory.appendingPathComponent("interface.json")
        let journal = RuntimeDiagnostics(fileURL: diagnosticURL)
        let instrumented = ExtendedRuntimeController(journal: journal)
        var publications = 0
        let observation = instrumented.objectWillChange.sink { publications += 1 }
        let initialSessions = WKExtendedRuntimeSession.instances.count
        instrumented.recordInterfaceEvent("page_appeared", details: ["observedPage": "classProgress"])
        assert(instrumented.phase == .idle && publications == 0)
        assert(WKExtendedRuntimeSession.instances.count == initialSessions)
        instrumented.start()
        let active = WKExtendedRuntimeSession.instances.last!
        active.confirmStart(); await drain()
        let publishedBefore = publications
        let contextBefore = instrumented.diagnosticContext
        instrumented.recordInterfaceEvent("volume_focus_call", details: ["controlID": "test-control"])
        instrumented.recordInterfaceEvent("page_selection_changed", details: ["selectedPage": "nowPlaying"])
        assert(instrumented.phase == .running && !instrumented.needsRestart)
        assert(publications == publishedBefore && active.invalidationRequests == 0)
        assert(instrumented.diagnosticContext == contextBefore)
        assert(WKExtendedRuntimeSession.instances.count == initialSessions + 1)
        await journal.flush()
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let entries = try decoder.decode([RuntimeDiagnostics.Event].self, from: Data(contentsOf: diagnosticURL))
        let uiEvents = entries.filter { $0.details["category"] == "interface" }
        assert(uiEvents.count == 3)
        assert(Set(uiEvents.compactMap { $0.details["launchID"] }).count == 1)
        assert(uiEvents[1].details["runtimeID"] == contextBefore["runtimeID"])
        assert(uiEvents[1].details["phase"] == "running")
        assert(uiEvents[1].details["sceneState"] == contextBefore["sceneState"])
        assert(uiEvents[1].details["launchElapsedSeconds"] != nil)
        observation.cancel()
        await checkActiveDiagnosticSnapshot(in: directory)
        await checkSeededTransitions(in: directory)
        print("PASS: relaunch recovery, inactive deferral, duplicate activation, persistent Stop, manual resume, schedule edits, failed-start suppression across launches, legacy/missing/corrupt/mismatched/expired intent")
        print("PASS: early handoff ordering, inactive deferral, observed expiration error, rejected replacement no-loop, explicit reset, manual policy, narrow time/error boundaries, passive UI/runtime correlation")
        print("PASS: explicit new-class Start survives pending old invalidation without overlap; Stop/reset/class changes/retirement cancel it")
        print("PASS: automatic recovery waits for both scene/native readiness; deferred intent survives and Stop/reset/class changes/retirement/manual policy prevent recovery")
        print("PASS: queued explicit Start waits for scene/native readiness in both invalidation orders, respects user-initiated policy, and cancels while awaiting wake")
    }

    @MainActor private static func checkActiveDiagnosticSnapshot(in directory: URL) async {
        let suite = "ActiveDiagnosticSnapshot." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let classStore = ClassStore(defaults: defaults)
        classStore.begin(at: Date(), scheduledStart: Date().addingTimeInterval(-120), durationMinutes: 75)
        let originalClass = classStore.context!
        let classBytes = defaults.data(forKey: "teachingClassContext.v1")!
        let intentStore = RuntimeIntentStore(defaults: defaults)
        let model = ExtendedRuntimeController(
            journal: RuntimeDiagnostics(fileURL: directory.appendingPathComponent(UUID().uuidString)),
            intentStore: intentStore)
        WKApplication.shared().applicationState = .active
        model.applicationStateChanged("active")
        model.synchronizeClass(originalClass)
        model.start()
        let native = WKExtendedRuntimeSession.instances.last!
        native.confirmStart(); await drain()
        assert(model.phase == .running && native.startRequests == 1)
        let nativeCount = WKExtendedRuntimeSession.instances.count
        let intent = intentStore.value
        let intentBytes = defaults.data(forKey: "teachingRuntimeIntent.v1")!
        let startedAt = model.startedAt
        let context = model.diagnosticContext
        var publications = 0
        let observation = model.objectWillChange.sink { publications += 1 }
        defer { observation.cancel() }

        for _ in 0..<3 {
            let snapshot = await model.diagnosticSnapshots()
            assert(snapshot.runtime.events.contains { $0.event == "runtime_started" })
            assert(snapshot.runtime.events.last?.details["runtimeID"] == context["runtimeID"])
            assert(model.phase == .running && !model.needsRestart && model.startedAt == startedAt)
            assert(model.diagnosticContext == context && publications == 0)
            assert(WKExtendedRuntimeSession.instances.count == nativeCount)
            assert(WKExtendedRuntimeSession.instances.last === native)
            assert(native.state == .running && native.startRequests == 1 && native.invalidationRequests == 0)
            assert(classStore.context == originalClass && defaults.data(forKey: "teachingClassContext.v1") == classBytes)
            assert(intentStore.value == intent && defaults.data(forKey: "teachingRuntimeIntent.v1") == intentBytes)
        }
        print("PASS: active diagnostic snapshots preserve runtime identity, start/invalidation counts, class bytes, saved intent and observed state")
    }

    /// Replay issue #7's initial native-active / scene-inactive observation
    /// against fresh stores, including intentional Stop saved before death.
    /// The boundary double supplies recovery callbacks explicitly; this tests
    /// the controller's response, not delivery of native watchOS notifications.
    @MainActor private static func checkPersistedDimmedRelaunch(in directory: URL) async {
        for state: RuntimeIntent.State in [.running, .stopped, .manualRecovery] {
            for nativeReadyFirst in [false, true] {
                for rejectedStart in state == .running ? [false, true] : [false] {
                    let suite = "PersistedDimmedRelaunch." + UUID().uuidString
                    let defaults = UserDefaults(suiteName: suite)!
                    defer { defaults.removePersistentDomain(forName: suite) }
                    let classStore = ClassStore(defaults: defaults)
                    let now = Date()
                    classStore.begin(at: now, scheduledStart: now.addingTimeInterval(-120), durationMinutes: 75)
                    let savedClass = classStore.context!
                    let originalClassBytes = defaults.data(forKey: "teachingClassContext.v1")!
                    let originalIntent = RuntimeIntent(classID: savedClass.initialStartPressedAt, state: state)
                    RuntimeIntentStore(defaults: defaults).save(originalIntent)
                    let originalIntentBytes = defaults.data(forKey: "teachingRuntimeIntent.v1")!
                    func relaunch(scene: String) -> ExtendedRuntimeController {
                        let freshDefaults = UserDefaults(suiteName: suite)!
                        let model = ExtendedRuntimeController(
                            journal: RuntimeDiagnostics(fileURL: directory.appendingPathComponent(UUID().uuidString)),
                            intentStore: RuntimeIntentStore(defaults: freshDefaults))
                        model.applicationStateChanged(scene, details: ["luminanceReduced": String(scene != "active")])
                        model.synchronizeClass(ClassStore(defaults: freshDefaults).context)
                        return model
                    }
                    WKApplication.shared().applicationState = .active
                    let reopened = relaunch(scene: "inactive")
                    let before = WKExtendedRuntimeSession.instances.count
                    reopened.applicationBecameActive(); reopened.applicationBecameActive()
                    assert(WKExtendedRuntimeSession.instances.count == before)
                    assert(defaults.data(forKey: "teachingRuntimeIntent.v1") == originalIntentBytes)
                    if !nativeReadyFirst {
                        WKApplication.shared().applicationState = .inactive
                    }
                    reopened.applicationStateChanged("active", details: ["luminanceReduced": "false"])
                    reopened.applicationBecameActive()
                    if !nativeReadyFirst {
                        assert(WKExtendedRuntimeSession.instances.count == before)
                        WKApplication.shared().applicationState = .active
                        reopened.applicationBecameActive()
                    }
                    if state == .running {
                        assert(WKExtendedRuntimeSession.instances.count == before + 1)
                        let recovery = WKExtendedRuntimeSession.instances.last!
                        if rejectedStart {
                            // Match the captured error, before didStart. Even
                            // this failure must remain a bounded manual fallback.
                            recovery.end(.error, error: NSError(domain: "WKExtendedRuntimeSessionErrorDomain", code: 3))
                            await drain()
                            let expected = RuntimeIntent(classID: savedClass.initialStartPressedAt, state: .manualRecovery)
                            assert(RuntimeIntentStore(defaults: defaults).value == expected)
                            assert(reopened.needsRestart && !reopened.isActive)
                            let retryLaunch = relaunch(scene: "inactive")
                            retryLaunch.applicationBecameActive()
                            retryLaunch.applicationStateChanged("active")
                            retryLaunch.applicationBecameActive(); retryLaunch.applicationBecameActive()
                            assert(RuntimeIntentStore(defaults: defaults).value == expected)
                        } else {
                            recovery.confirmStart(); await drain()
                            assert(reopened.phase == .running && !reopened.needsRestart)
                            assert(defaults.data(forKey: "teachingRuntimeIntent.v1") == originalIntentBytes)
                        }
                        reopened.applicationBecameActive(); reopened.applicationBecameActive()
                        assert(WKExtendedRuntimeSession.instances.count == before + 1)
                    } else {
                        assert(WKExtendedRuntimeSession.instances.count == before)
                        assert(defaults.data(forKey: "teachingRuntimeIntent.v1") == originalIntentBytes)
                        if state == .stopped { assert(reopened.phase == .stopped && !reopened.needsRestart) }
                        else { assert(reopened.needsRestart && !reopened.isActive) }
                    }
                    assert(defaults.data(forKey: "teachingClassContext.v1") == originalClassBytes)
                    assert(ClassStore(defaults: defaults).context == savedClass)
                }
            }
        }
        print("PASS: eight persisted dimmed-relaunch cases preserve class bytes, respect saved Stop/manual recovery, recover once when ready, and bound captured code-3 failure across relaunch")
    }

    /// Mixed event histories supplement the named regression cases above.
    /// Fixed seeds plus the last 24 actions make a failure reproducible in CI.
    @MainActor private static func checkSeededTransitions(in directory: URL) async {
        let seeds: [UInt64] = [1, 7, 42, 99, 2026, 104729, 0xC0FFEE, 0xDEADBEEF]
        for seed in seeds {
            var random = SeededEvents(state: seed)
            let suite = "RuntimeSequences." + UUID().uuidString
            let defaults = UserDefaults(suiteName: suite)!
            let intent = RuntimeIntentStore(defaults: defaults)
            let journal = RuntimeDiagnostics(fileURL: directory
                .appendingPathComponent("seed-\(seed)/RuntimeDiagnostics.json"))
            let model = ExtendedRuntimeController(journal: journal, intentStore: intent)
            let firstInstance = WKExtendedRuntimeSession.instances.count
            let anchor = Date()
            var classRevision = 0
            var context: ClassContext? = ClassContext(pressedAt: anchor, scheduledStart: anchor)
            var stoppedClassID: Date?
            var trace: [String] = []
            WKApplication.shared().applicationState = .active
            model.applicationStateChanged("active")
            model.synchronizeClass(context)
            model.start()
            WKExtendedRuntimeSession.instances.last!.confirmStart()
            await drain()

            for step in 0..<160 {
                let instances = Array(WKExtendedRuntimeSession.instances.dropFirst(firstInstance))
                let live = instances.last { $0.state != .invalid }
                let before = WKExtendedRuntimeSession.instances.count
                let action = random.next(16)
                var description: String
                switch action {
                case 0, 1:
                    description = "foreground"
                    WKApplication.shared().applicationState = .active
                    model.applicationStateChanged("active")
                    model.applicationBecameActive()
                case 2, 3:
                    let background = action == 3
                    description = background ? "background" : "dim"
                    WKApplication.shared().applicationState = background ? .background : .inactive
                    model.applicationStateChanged(background ? "background" : "inactive")
                case 4:
                    description = "explicit_start"
                    if context?.shouldRetire(at: Date()) == false { stoppedClassID = nil }
                    model.start()
                case 5:
                    description = "explicit_stop"
                    stoppedClassID = context?.initialStartPressedAt
                    model.stop()
                case 6:
                    description = "new_class_and_start"
                    classRevision += 1
                    context = ClassContext(pressedAt: anchor.addingTimeInterval(Double(classRevision)),
                                           scheduledStart: anchor)
                    stoppedClassID = nil
                    model.synchronizeClass(context)
                    model.start()
                case 7:
                    description = "clear_class"
                    context = nil
                    stoppedClassID = nil
                    model.synchronizeClass(nil)
                case 8:
                    description = "confirm_start"
                    if live?.state == .notStarted { live?.confirmStart() }
                case 9:
                    description = "expiration_warning"
                    if live?.state == .running {
                        live?.expirationDate = Date().addingTimeInterval(10)
                        live?.warn()
                    }
                case 10:
                    let reasons: [WKExtendedRuntimeSessionInvalidationReason] = [
                        .none, .expired, .resignedFrontmost, .suppressedBySystem, .error
                    ]
                    let reason = reasons[random.next(reasons.count)]
                    description = "invalidate_\(reason)"
                    live?.end(reason)
                case 11:
                    description = "stale_callbacks"
                    if let stale = instances.first(where: { $0.state == .invalid }) {
                        model.extendedRuntimeSessionDidStart(stale)
                        model.extendedRuntimeSessionWillExpire(stale)
                        model.extendedRuntimeSession(stale, didInvalidateWith: .error, error: nil)
                    }
                case 12:
                    description = "edit_schedule"
                    if let current = context, !current.shouldRetire(at: Date()) {
                        context = ClassContext(pressedAt: current.initialStartPressedAt,
                            durationMinutes: current.durationMinutes == 60 ? 75 : 60,
                            scheduledStart: anchor.addingTimeInterval(900))
                        model.synchronizeClass(context)
                    }
                case 13:
                    let automatic = random.next(2) == 0
                    description = automatic ? "automatic_policy" : "manual_policy"
                    model.renewalPolicy = automatic ? .automatic : .userInitiated
                case 14:
                    description = "native_active_scene_inactive"
                    WKApplication.shared().applicationState = .active
                    model.applicationStateChanged("inactive")
                    model.applicationBecameActive()
                default:
                    description = "retire_class"
                    if let current = context {
                        context = ClassContext(pressedAt: current.initialStartPressedAt,
                                               scheduledStart: anchor.addingTimeInterval(-10000))
                        model.synchronizeClass(context)
                        model.applicationBecameActive()
                    }
                }
                await drain()
                trace.append("\(step): \(description) -> \(model.phase)")
                trace = Array(trace.suffix(24))
                func require(_ valid: Bool, _ invariant: String) {
                    precondition(valid, "Runtime seed \(seed), step \(step): \(invariant)\n" + trace.joined(separator: "\n"))
                }
                let after = WKExtendedRuntimeSession.instances.count
                let liveAfter = WKExtendedRuntimeSession.instances.dropFirst(firstInstance)
                    .filter { $0.state != .invalid }
                require(liveAfter.count <= 1, "runtime objects must never overlap")
                require(after - before <= 1, "one event must not create multiple successors")
                if after > before {
                    require(context?.shouldRetire(at: Date()) == false, "a successor requires a current class")
                    require(WKApplication.shared().applicationState == .active, "a start requires native active state")
                    require(stoppedClassID != context?.initialStartPressedAt, "explicit Stop prevents automatic restart")
                    if action != 4 && action != 6 {
                        require(model.lastSceneState == "active", "deferred recovery requires scene readiness too")
                    }
                }
                if let stoppedClassID, stoppedClassID == context?.initialStartPressedAt,
                   context?.shouldRetire(at: Date()) == false {
                    require(intent.value?.state == .stopped, "callbacks cannot overwrite explicit Stop intent")
                }
                if model.phase == .running {
                    require(liveAfter.last?.state == .running, "running presentation requires a confirmed live object")
                }
            }
            model.stop(source: "test_cleanup")
            if let live = WKExtendedRuntimeSession.instances.dropFirst(firstInstance).last(where: { $0.state != .invalid }) {
                live.end(.none)
            }
            await drain()
            await journal.flush()
            defaults.removePersistentDomain(forName: suite)
        }
        print("PASS: 1,280 mixed runtime events across eight fixed seeds preserve no-overlap, current-class, explicit-Stop, readiness, and confirmed-running invariants")
    }

    private struct SeededEvents {
        var state: UInt64
        mutating func next(_ upperBound: Int) -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int((state >> 32) % UInt64(upperBound))
        }
    }
}
