import Foundation
import WatchKit

@MainActor
final class ExtendedRuntimeController: NSObject, ObservableObject {
    enum Phase: Equatable {
        case idle
        case starting
        case running
        case ending
        case ended(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var startedAt: Date?

    private var runtimeSession: WKExtendedRuntimeSession?

    var isActive: Bool {
        switch phase {
        case .starting, .running, .ending:
            true
        case .idle, .ended:
            false
        }
    }

    func start() {
        guard !isActive else { return }

        // A WKExtendedRuntimeSession can't be restarted after invalidation.
        let newSession = WKExtendedRuntimeSession()
        newSession.delegate = self
        runtimeSession = newSession
        startedAt = nil
        phase = .starting
        newSession.start()
    }

    func stop() {
        guard isActive else { return }
        phase = .ending
        runtimeSession?.invalidate()
    }
}

extension ExtendedRuntimeController: WKExtendedRuntimeSessionDelegate {
    nonisolated func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        Task { @MainActor in
            guard extendedRuntimeSession === runtimeSession else { return }
            // Elapsed time is anchored to the delegate-confirmed runtime start.
            startedAt = Date()
            phase = .running
        }
    }

    nonisolated func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        Task { @MainActor in
            guard extendedRuntimeSession === runtimeSession else { return }
            phase = .ending
        }
    }

    nonisolated func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: (any Error)?
    ) {
        Task { @MainActor in
            guard extendedRuntimeSession === runtimeSession else { return }
            let detail = error?.localizedDescription ?? Self.description(for: reason)
            phase = .ended(detail)
            runtimeSession = nil
        }
    }

    nonisolated private static func description(
        for reason: WKExtendedRuntimeSessionInvalidationReason
    ) -> String {
        switch reason {
        case .none: "Stopped"
        case .sessionInProgress: "Another session is already running"
        case .expired: "One-hour session limit reached"
        case .resignedFrontmost: "App left the foreground"
        case .suppressedBySystem: "Stopped by the system"
        case .error: "Runtime session error"
        @unknown default: "Runtime session ended"
        }
    }
}
