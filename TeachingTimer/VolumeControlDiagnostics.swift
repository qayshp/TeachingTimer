// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Passive instrumentation only: never schedules, suppresses, or retries a
/// focus call. WatchKit provides no confirmation of actual focus or volume.
@MainActor
final class VolumeControlDiagnostics {
    struct Request {
        let id = UUID().uuidString
        let focused: Bool
        let source: String
        let instant = ContinuousClock().now
    }

    let controlID = UUID().uuidString
    // Updated by representable callbacks, not an independently observed UI state.
    var lastViewSnapshot: [String: String] = [:]
    private var latestRequestID: String?
    private var latestRequestedFocus: Bool?
    private var dismantled = false
    private let record: (String, [String: String]) -> Void

    init(record: @escaping (String, [String: String]) -> Void) {
        self.record = record
    }

    func created() { emit("volume_control_created") }

    func removed() {
        dismantled = true
        emit("volume_control_dismantled")
    }

    func requested(_ focused: Bool, source: String) -> Request {
        let request = Request(focused: focused, source: source)
        latestRequestID = request.id
        latestRequestedFocus = focused
        emit("volume_focus_requested", request: request)
        return request
    }

    func willInvoke(_ request: Request) {
        emit("volume_focus_call", request: request)
    }

    func didReturn(_ request: Request) {
        // This means the void API returned, NOT that focus/volume is correct.
        emit("volume_focus_call_returned", request: request)
    }

    private func emit(_ event: String, request: Request? = nil) {
        var details = lastViewSnapshot
        details["controlID"] = controlID
        details["origin"] = "companion"
        details["controlDismantled"] = String(dismantled)
        details["latestRequestID"] = latestRequestID ?? "none"
        details["latestRequestedFocus"] = latestRequestedFocus.map { String($0) } ?? "none"
        details["actualFocus"] = "unobserved"
        if let request {
            details["requestID"] = request.id
            details["requestedFocus"] = String(request.focused)
            details["call"] = request.focused ? "focus" : "resignFocus"
            details["source"] = request.source
            details["supersededRequest"] = String(request.id != latestRequestID)
            let duration = request.instant.duration(to: ContinuousClock().now).components
            details["secondsSinceRequest"] = String(Double(duration.seconds) + Double(duration.attoseconds) / 1e18)
        }
        record(event, details)
    }
}
