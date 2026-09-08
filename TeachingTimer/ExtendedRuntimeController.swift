import Foundation
import WatchKit
import OSLog

@MainActor
final class ExtendedRuntimeController: NSObject, ObservableObject {
    enum Phase: Equatable { case idle, starting, running, expiring, expired, stopped, failed(String) }
    enum RenewalPolicy { case automatic, userInitiated }
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var needsRestart = false
    @Published private(set) var startedAt: Date?
    var renewalPolicy: RenewalPolicy = .automatic
    private var runtimeSession: WKExtendedRuntimeSession?
    private var renewalPending = false
    private var stopRequested = false
    private let log = Logger(subsystem: "com.qayshp.TeachingTimer", category: "Runtime")
    var isActive: Bool {
        switch phase { case .starting, .running, .expiring: true; default: false }
    }
    func start() {
        guard !isActive, runtimeSession == nil else { return }
        guard WKApplication.shared().applicationState == .active else {
            needsRestart = true
            phase = .failed("Raise wrist, then restart runtime")
            log.error("Runtime start deferred: application is not active")
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
    func stop() {
        stopRequested = true
        renewalPending = false
        needsRestart = false
        // A start in flight is invalidated only after didStart confirms it.
        if runtimeSession?.state == .running { runtimeSession?.invalidate() }
        if runtimeSession == nil { phase = .stopped }
    }
    func applicationBecameActive() {
        guard renewalPending, renewalPolicy == .automatic, runtimeSession == nil, !stopRequested else { return }
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
            log.notice("Runtime confirmed running")
        }
    }
    nonisolated func extendedRuntimeSessionWillExpire(_ session: WKExtendedRuntimeSession) {
        Task { @MainActor in
            guard session === runtimeSession, !stopRequested else { return }
            phase = .expiring
            renewalPending = renewalPolicy == .automatic
            log.notice("Runtime expiring; replacement waits for invalidation")
        }
    }
    nonisolated func extendedRuntimeSession(_ session: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: (any Error)?) {
        Task { @MainActor in
            guard session === runtimeSession else { return }
            runtimeSession = nil
            if stopRequested { phase = .stopped; return }
            needsRestart = true
            if reason == .expired {
                phase = .expired
                renewalPending = renewalPolicy == .automatic
                log.notice("Runtime expired; evaluating renewal")
                if renewalPending {
                    if WKApplication.shared().applicationState == .active { start() }
                    else { log.error("Renewal deferred while inactive; Restart fallback available") }
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
