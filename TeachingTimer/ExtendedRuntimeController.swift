import Foundation
#if !CONTROLLER_CHECKS
import WatchKit
#else
import Combine
#endif
import OSLog

@MainActor
final class ExtendedRuntimeController: NSObject, ObservableObject {
    enum Phase: Equatable { case idle, starting, running, expiring, expired, interrupted, stopped, failed(String) }
    enum RenewalPolicy { case automatic, userInitiated }
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var needsRestart = false
    @Published private(set) var startedAt: Date?
    var renewalPolicy: RenewalPolicy = .automatic
    private var runtimeSession: WKExtendedRuntimeSession?
    private var renewalPending = false
    private var stopRequested = false
    private let log = Logger(subsystem: "com.qayshp.TeachingTimer", category: "Runtime")
    private var diagnostics: RuntimeDiagnostics?
    private let launchID = UUID().uuidString
    private var runtimeID: String?
    private var expirationWarningReceived = false
    private var earlyHandoffRequested = false
    private var automaticReplacement = false
    private(set) var lastSceneState = "unknown"

    var diagnosticContext: [String: String] {
        ["runtimeID": runtimeID ?? "none", "runtimePhase": String(describing: phase),
         "sceneState": lastSceneState]
    }

    override init() {
        super.init()
        do { diagnostics = try RuntimeDiagnostics() }
        catch { log.error("Cannot open persistent runtime journal: \(error.localizedDescription, privacy: .public)") }
        record("app_launched", extra: [
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "os": ProcessInfo.processInfo.operatingSystemVersionString
        ])
    }

#if CONTROLLER_CHECKS
    init(journal: RuntimeDiagnostics) {
        super.init()
        diagnostics = journal
    }
#endif

    private func record(_ event: String, extra: [String: String] = [:]) {
        var details = extra
        details["launchID"] = launchID
        details["runtimeID"] = runtimeID
        details["phase"] = String(describing: phase)
        switch WKApplication.shared().applicationState {
        case .active: details["appState"] = "active"
        case .inactive: details["appState"] = "inactive"
        case .background: details["appState"] = "background"
        @unknown default: details["appState"] = "unknown"
        }
        details["appStateCode"] = String(WKApplication.shared().applicationState.rawValue)
        details["uptimeSeconds"] = String(ProcessInfo.processInfo.systemUptime)
        details["renewalPolicy"] = String(describing: renewalPolicy)
        details["renewalPending"] = String(renewalPending)
        details["stopRequested"] = String(stopRequested)
        details["expirationWarningReceived"] = String(expirationWarningReceived)
        details["earlyHandoffRequested"] = String(earlyHandoffRequested)
        details["automaticReplacement"] = String(automaticReplacement)
        if let startedAt {
            details["startedAt"] = ISO8601DateFormatter().string(from: startedAt)
            details["elapsedWallSeconds"] = String(Date().timeIntervalSince(startedAt))
        }
        if let expiration = runtimeSession?.expirationDate {
            details["expirationDate"] = ISO8601DateFormatter().string(from: expiration)
        }
        do { try diagnostics?.record(event, details: details) }
        catch { log.error("Cannot persist runtime event: \(error.localizedDescription, privacy: .public)") }
    }

    func applicationStateChanged(_ state: String) {
        lastSceneState = state
        record("scene_state_changed", extra: ["sceneState": state])
    }
    var isActive: Bool {
        switch phase { case .starting, .running, .expiring: true; default: false }
    }
    func actionTitle(hasClass: Bool) -> String {
        if phase == .starting { return "Starting…" }
        if isActive { return "Stop session" }
        if !hasClass { return "Start class" }
        return startedAt == nil ? "Start session" : "Resume session"
    }
    var statusText: String {
        switch phase {
        case .idle: ""
        case .starting: "Starting session…"
        case .running: "Session active"
        case .expiring: "Session ending"
        case .expired: "Session ended"
        case .interrupted: "Session interrupted"
        case .stopped: "Session stopped"
        case .failed(let message):
            message == "Raise wrist, then restart runtime"
                ? "Raise wrist to resume"
                : (startedAt == nil ? "Couldn’t start session" : "Session interrupted")
        }
    }
    func start(automatically: Bool = false) {
        guard !isActive, runtimeSession == nil else { return }
        let parentID = runtimeID
        automaticReplacement = automatically
        expirationWarningReceived = false
        earlyHandoffRequested = false
        runtimeID = UUID().uuidString
        startedAt = nil
        record("start_requested", extra: ["replacesRuntimeID": automatically ? (parentID ?? "none") : "none"])
        guard WKApplication.shared().applicationState == .active else {
            needsRestart = true
            phase = .failed("Raise wrist, then restart runtime")
            log.error("Runtime start deferred: application is not active")
            record("start_rejected_inactive")
            if automatically { record("automatic_restart_failed", extra: ["cause": "inactive_before_start"]) }
            return
        }
        stopRequested = false
        renewalPending = false
        needsRestart = false
        earlyHandoffRequested = false
        startedAt = nil
        let replacement = WKExtendedRuntimeSession()
        replacement.delegate = self
        runtimeSession = replacement
        phase = .starting
        log.notice("Requesting runtime; awaiting delegate confirmation")
        replacement.start()
    }
    func stop(source: String = "runtime_button", details: [String: String] = [:]) {
        record("stop_requested", extra: details.merging(["source": source]) { _, source in source })
        stopRequested = true
        renewalPending = false
        needsRestart = false
        // A start in flight is invalidated only after didStart confirms it.
        if runtimeSession?.state == .running { runtimeSession?.invalidate() }
        if runtimeSession == nil { phase = .stopped }
    }
    func applicationBecameActive() {
        if attemptEarlyHandoff() { return }
        guard renewalPending, renewalPolicy == .automatic, runtimeSession == nil, !stopRequested else { return }
        guard WKApplication.shared().applicationState == .active else { return }
        record("automatic_restart_attempt")
        // Consume the intent before trying: a rejected start keeps the manual
        // fallback rather than retrying on every later scene transition.
        renewalPending = false
        start(automatically: true)
    }

    @discardableResult
    private func attemptEarlyHandoff() -> Bool {
        guard let session = runtimeSession, session.state == .running else { return false }
        if earlyHandoffRequested { return true }
        guard RuntimeRenewalRules.canHandoff(
            warned: expirationWarningReceived, expiration: session.expirationDate, now: Date(),
            active: WKApplication.shared().applicationState == .active,
            automatic: renewalPolicy == .automatic, stopped: stopRequested) else { return false }
        earlyHandoffRequested = true
        renewalPending = true
        record("early_handoff_requested", extra: ["secondsRemaining": String(session.expirationDate?.timeIntervalSinceNow ?? 0)])
        // Keep the old object until its delegate confirms invalidation. Never overlap sessions.
        session.invalidate()
        return true
    }
}

extension ExtendedRuntimeController: WKExtendedRuntimeSessionDelegate {
    nonisolated func extendedRuntimeSessionDidStart(_ session: WKExtendedRuntimeSession) {
        Task { @MainActor in
            guard session === runtimeSession else { return }
            if stopRequested { session.invalidate(); return }
            startedAt = Date()
            phase = .running
            needsRestart = false
            record("runtime_started")
            if automaticReplacement { record("automatic_restart_succeeded") }
            log.notice("Runtime confirmed running")
        }
    }
    nonisolated func extendedRuntimeSessionWillExpire(_ session: WKExtendedRuntimeSession) {
        Task { @MainActor in
            guard session === runtimeSession, !stopRequested else { return }
            phase = .expiring
            expirationWarningReceived = true
            renewalPending = renewalPolicy == .automatic
            record("runtime_will_expire")
            if !attemptEarlyHandoff() {
                record("early_handoff_deferred", extra: ["cause": "inactive_or_policy_or_outside_window"])
            }
        }
    }
    nonisolated func extendedRuntimeSession(_ session: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: (any Error)?) {
        Task { @MainActor in
            guard session === runtimeSession else { return }
            let failure = error as NSError?
            let reasonName: String
            switch reason {
            case .none: reasonName = "normal_end"
            case .error: reasonName = "error"
            case .expired: reasonName = "expired"
            case .resignedFrontmost: reasonName = "resigned_frontmost"
            case .suppressedBySystem: reasonName = "suppressed_by_system"
            case .sessionInProgress: reasonName = "session_already_in_progress"
            @unknown default: reasonName = "unknown"
            }
            var details = ["reason": reasonName, "reasonCode": String(reason.rawValue)]
            if let failure {
                details["errorDomain"] = failure.domain
                details["errorCode"] = String(failure.code)
                details["errorDescription"] = failure.localizedDescription
                if let underlying = failure.userInfo[NSUnderlyingErrorKey] as? NSError {
                    details["underlyingErrorDomain"] = underlying.domain
                    details["underlyingErrorCode"] = String(underlying.code)
                    details["underlyingErrorDescription"] = underlying.localizedDescription
                }
            }
            // Persist before replacing the session or taking the manual-stop branch.
            record("runtime_invalidated", extra: details)
            log.notice("Runtime invalidated: reason=\(reason.rawValue), domain=\(failure?.domain ?? "none", privacy: .public), code=\(failure?.code ?? 0), appState=\(WKApplication.shared().applicationState.rawValue)")
            let wasRunning = startedAt != nil
            let expirationError = reason == .error && RuntimeRenewalRules.isExpirationError(
                warned: expirationWarningReceived, expiration: session.expirationDate,
                now: Date(), domain: failure?.domain, code: failure?.code)
            let earlyEnd = earlyHandoffRequested && reason == .none
            let eligible = wasRunning && (earlyEnd || expirationError || reason == .expired || reason == .resignedFrontmost)
            record("renewal_decision", extra: ["eligible": String(eligible && !stopRequested && renewalPolicy == .automatic),
                "cause": stopRequested ? "explicit_stop" : (!wasRunning ? "session_never_started" :
                    (earlyEnd ? "early_handoff" : (expirationError ? "expiration_associated_error" : reasonName)))])
            runtimeSession = nil
            earlyHandoffRequested = false
            if stopRequested { phase = .stopped; return }
            needsRestart = true
            if eligible {
                phase = reason == .expired ? .expired : .interrupted
                renewalPending = renewalPolicy == .automatic
                record("runtime_restart_evaluated", extra: ["trigger": reasonName])
                log.notice("Runtime ended with renewable reason; evaluating restart")
                if renewalPending {
                    // The active-scene callback may precede this invalidation
                    // callback. Handle that ordering here as well as on return.
                    if WKApplication.shared().applicationState == .active { applicationBecameActive() }
                    else {
                        record("renewal_deferred_inactive")
                        log.error("Renewal deferred while inactive; Restart fallback available")
                    }
                }
            } else {
                renewalPending = false
                let message = error?.localizedDescription ?? "Runtime ended (reason \(reason.rawValue))"
                phase = .failed(message)
                if automaticReplacement && !wasRunning { record("automatic_restart_failed", extra: ["cause": reasonName]) }
                log.error("Runtime or renewal failed: \(message, privacy: .public)")
            }
        }
    }
}
