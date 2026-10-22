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
    init() { Self.instances.append(self) }
    func start() {} // Success/failure is independently driven by the test.
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
            return ExtendedRuntimeController(journal: RuntimeDiagnostics(fileURL: directory.appendingPathComponent(UUID().uuidString)))
        }
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
        old.end(.error); old.warn(); await drain()
        assert(foreground.phase == .running)
        // Explicit Stop while start is awaiting didStart must invalidate it,
        // without allowing any automatic successor.
        let starting = try controller(); starting.start()
        let inFlight = WKExtendedRuntimeSession.instances.last!
        starting.stop(); inFlight.confirmStart(); await drain()
        assert(inFlight.invalidationRequests == 1)
        inFlight.end(.none); await drain(); starting.applicationBecameActive()
        assert(starting.phase == .stopped && WKExtendedRuntimeSession.instances.last === inFlight)
        assert(starting.actionTitle(hasClass: true) == "Start session")
        print("PASS: early handoff ordering, inactive deferral, observed expiration error, rejected replacement no-loop, explicit reset, manual policy, narrow time/error boundaries")
    }
}
