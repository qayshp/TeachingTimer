// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Typed request values and queue outcomes shared by phone and Watch.
enum DiagnosticRequest {
    enum Window: String, CaseIterable, Identifiable, Sendable {
        case lastTwoHours, lastDay, allRetained
        var id: String { rawValue }
        var title: String {
            switch self {
            case .lastTwoHours: "Last 2 hours"
            case .lastDay: "Last 24 hours"
            case .allRetained: "All retained events"
            }
        }
    }

    enum Outcome: String, Sendable {
        case queued
        case transportNotReady = "transport-not-ready"
        case preparationFailed = "preparation-failed"
    }

    @MainActor
    static func enqueue(window: Window,
                        prepare: @MainActor (Window) async throws -> URL,
                        send: @MainActor (URL) -> Bool) async -> Outcome {
        do {
            let file = try await prepare(window)
            return send(file) ? .queued : .transportNotReady
        } catch { return .preparationFailed }
    }
}
