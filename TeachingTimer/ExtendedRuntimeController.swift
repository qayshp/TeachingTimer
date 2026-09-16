import Foundation
import WatchKit
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

    override init() {
        super.init()
        do { diagnostics = try RuntimeDiagnostics() }
        catch { log.error("Cannot open persistent runtime journal: \(error.localizedDescription, privacy: .public)") }
        record("app_launched", extra: [
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "os": ProcessInfo.processInfo.operatingSystemVersionString
        ])
    }

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
        record("scene_state_changed", extra: ["sceneState": state])
    }
    var isActive: Bool {
        switch phase { case .starting, .running, .expiring: true; default: false }
    }
    var statusText: String {
        switch phase {
        case .idle: ""
        case .starting: "Starting runtime…"
        case .running: "Runtime active"
        case .expiring: "Runtime expiring"
        case .expired: "Runtime expired · tap Restart"
        case .interrupted: "Runtime ended · tap Restart"
        case .stopped: "Runtime stopped"
        case .failed(let message):
            message == "Raise wrist, then restart runtime"
                ? "Raise wrist · tap Restart"
                : (startedAt == nil ? "Couldn't start · tap Restart" : "Runtime failed · tap Restart")
        }
    }
    func start() {
        guard !isActive, runtimeSession == nil else { return }
        runtimeID = UUID().uuidString
        startedAt = nil
        record("start_requested")
        guard WKApplication.shared().applicationState == .active else {
            needsRestart = true
            phase = .failed("Raise wrist, then restart runtime")
            log.error("Runtime start deferred: application is not active")
            record("start_rejected_inactive")
            return
        }
        stopRequested = false
        renewalPending = false
        needsRestart = false
        startedAt = nil
        let replacement = WKExtendedRuntimeSession()
        replacement.delegate = self
        runtimeSession = replacement
        phase = .starting
        log.notice("Requesting runtime; awaiting delegate confirmation")
        replacement.start()
    }
    func stop(source: String = "runtime_button") {
        record("stop_requested", extra: ["source": source])
        stopRequested = true
        renewalPending = false
        needsRestart = false
        // A start in flight is invalidated only after didStart confirms it.
        if runtimeSession?.state == .running { runtimeSession?.invalidate() }
        if runtimeSession == nil { phase = .stopped }
    }
    func applicationBecameActive() {
        guard renewalPending, renewalPolicy == .automatic, runtimeSession == nil, !stopRequested else { return }
        guard WKApplication.shared().applicationState == .active else { return }
        record("automatic_restart_attempt")
        // Consume the intent before trying: a rejected start keeps the manual
        // fallback rather than retrying on every later scene transition.
        renewalPending = false
        start()
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
            log.notice("Runtime confirmed running")
        }
    }
    nonisolated func extendedRuntimeSessionWillExpire(_ session: WKExtendedRuntimeSession) {
        Task { @MainActor in
            guard session === runtimeSession, !stopRequested else { return }
            phase = .expiring
            renewalPending = renewalPolicy == .automatic
            record("runtime_will_expire")
            log.notice("Runtime expiring; replacement waits for invalidation")
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
            runtimeSession = nil
            if stopRequested { phase = .stopped; return }
            needsRestart = true
            if reason == .expired || reason == .resignedFrontmost {
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
                log.error("Runtime or renewal failed: \(message, privacy: .public)")
            }
        }
    }
}
