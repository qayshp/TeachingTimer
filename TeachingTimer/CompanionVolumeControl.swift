// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import WatchKit

struct CompanionVolumeControl: WKInterfaceObjectRepresentable {
    let isFocused: Bool
    let focusGeneration: Int
    let diagnosticSnapshot: [String: String]
    let recordDiagnostic: (String, [String: String]) -> Void
    let focusCallReturned: () -> Void

    func makeWKInterfaceObject(context: Context) -> WKInterfaceVolumeControl {
        let volumeControl = WKInterfaceVolumeControl(origin: .companion)
        // Native tint affects the resting appearance only. System adjustment
        // feedback and unavailable-source presentation remain system-owned.
        volumeControl.setTintColor(.white)
        context.coordinator.diagnostics.lastViewSnapshot = diagnosticSnapshot
        context.coordinator.diagnostics.created()
        return volumeControl
    }

    func updateWKInterfaceObject(
        _ volumeControl: WKInterfaceVolumeControl,
        context: Context
    ) {
        let diagnostics = context.coordinator.diagnostics
        diagnostics.lastViewSnapshot = diagnosticSnapshot
        guard let change = context.coordinator.focusState.update(
            wantsFocus: isFocused, generation: focusGeneration) else { return }
        if change.resignBeforeFocus {
            let resign = diagnostics.requested(false, source: "refocus")
            diagnostics.willInvoke(resign)
            volumeControl.resignFocus()
            diagnostics.didReturn(resign)
        }
        let request = diagnostics.requested(isFocused,
            source: change.resignBeforeFocus ? "refocus" : "update",
            settlingSeconds: change.settlingSeconds)

        let invoke: @MainActor @Sendable () -> Void = {
            guard diagnostics.canInvoke(request) else {
                diagnostics.skipped(request)
                return
            }
            diagnostics.willInvoke(request)
            if isFocused {
                volumeControl.focus()
            } else {
                volumeControl.resignFocus()
            }
            diagnostics.didReturn(request)
            if isFocused { focusCallReturned() }
        }
        if change.settlingSeconds > 0 {
            // Let the explicit resign/tap settle on the retained control.
            // Selection changes/removal invalidate this request before it runs.
            DispatchQueue.main.asyncAfter(deadline: .now() + change.settlingSeconds, execute: invoke)
        } else {
            // Preserve the existing immediate path for media-to-timer returns.
            DispatchQueue.main.async(execute: invoke)
        }
    }

    static func dismantleWKInterfaceObject(
        _ volumeControl: WKInterfaceVolumeControl,
        coordinator: Coordinator
    ) {
        let diagnostics = coordinator.diagnostics
        diagnostics.removed()
        let request = diagnostics.requested(false, source: "dismantle")
        diagnostics.willInvoke(request)
        volumeControl.resignFocus()
        diagnostics.didReturn(request)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(recordDiagnostic: recordDiagnostic)
    }

    @MainActor
    final class Coordinator {
        var focusState = VolumeFocusState()
        let diagnostics: VolumeControlDiagnostics

        init(recordDiagnostic: @escaping (String, [String: String]) -> Void) {
            diagnostics = VolumeControlDiagnostics(record: recordDiagnostic)
        }
    }
}
