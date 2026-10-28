// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import WatchKit

struct RefreshableCompanionVolumeControl: View {
    let layout: TimerFaceLayout
    let isFocused: Bool
    let backgroundRevision: Int
    let diagnosticSnapshot: [String: String]
    let recordDiagnostic: (String, [String: String]) -> Void
    @State private var refresh = VolumeRefreshState()
    @State private var activation = VolumeActivationState()
    @Environment(\.scenePhase) private var scenePhase

    private struct SetupKey: Equatable {
        let backgroundRevision: Int
        let isActive: Bool
        let isFocused: Bool
    }

    var body: some View {
        let generation = refresh.generation
        let current = activation.isCurrent(backgroundRevision: backgroundRevision)
        var snapshot = diagnosticSnapshot
        snapshot["volumeRequestGeneration"] = String(generation)
        return ZStack {
            if activation.hasControl {
                // Keep native identity across refresh/background setup. Replacing
                // this widget reproduced lost Crown feedback after Home return.
                CompanionVolumeControl(isFocused: isFocused && current,
                    focusGeneration: generation,
                    diagnosticSnapshot: snapshot, recordDiagnostic: recordDiagnostic,
                    focusCallReturned: {
                        guard refresh.focusCallReturned(for: generation) else { return }
                        let source = refresh.source ?? .timerTap
                        recordDiagnostic(source == .timerTap ? "volume_refresh_completed" : "volume_setup_focus_returned", [
                            "source": source.rawValue, "volumeRequestGeneration": String(generation),
                            "completion": "focus_call_returned", "actualFocus": "unobserved",
                            "audioRecovery": "unobserved"
                        ])
                    })
                    .frame(width: layout.volumeSize.width, height: layout.volumeSize.height)
                    .background { Circle().fill(.black).frame(width: 38, height: 38).allowsHitTesting(false) }
            } else {
                ProgressView().controlSize(.mini).tint(.white)
                    .accessibilityHidden(true).allowsHitTesting(false)
            }
            if current {
                Image(systemName: refresh.confirmedGeneration == nil ? "arrow.clockwise" : "checkmark")
                .font(.system(size: 10, weight: .bold))
                .frame(width: 16, height: 16)
                .background(Circle().fill(.black))
                .offset(x: 20, y: 13)
                .allowsHitTesting(false)
            } else if activation.hasControl {
                ProgressView().controlSize(.mini).tint(.white)
                    .offset(x: 20, y: 13).accessibilityHidden(true).allowsHitTesting(false)
            }
            // A tap surface, not a new focusable control: Crown input remains
            // with WatchKit. A horizontal drag still belongs to the TabView.
            Color.clear
                .frame(width: layout.volumeRefreshFrame.width, height: layout.volumeRefreshFrame.height)
                .contentShape(Rectangle())
                .onTapGesture(perform: requestRefresh)
                .offset(y: layout.volumeRefreshFrame.midY - layout.volumeCenter.y)
                .accessibilityHidden(true)
        }
        .frame(width: layout.volumeSize.width, height: layout.volumeSize.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("iPhone playback volume")
        .accessibilityValue(!current ? "Preparing volume control" : (refresh.isRefreshing ? "Refreshing control" :
            (refresh.confirmedGeneration == nil ? "" : "Control refreshed")))
        .accessibilityHint("Turn the Crown to adjust. Double-tap to refresh the volume control.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { requestRefresh() }
        .task(id: SetupKey(backgroundRevision: backgroundRevision, isActive: scenePhase == .active, isFocused: isFocused)) {
            await prepareVolumeControl()
        }
        .task(id: refresh.confirmedGeneration) {
            guard let confirmed = refresh.confirmedGeneration else { return }
            do { try await Task.sleep(for: .seconds(1.5)) }
            catch { return }
            refresh.dismissConfirmation(for: confirmed)
        }
    }

    private func requestRefresh() {
        guard isFocused, activation.isCurrent(backgroundRevision: backgroundRevision),
              let generation = refresh.request() else { return }
        var details = diagnosticSnapshot
        details["source"] = "timer_tap"
        details["previousVolumeRequestGeneration"] = String(generation - 1)
        details["volumeRequestGeneration"] = String(generation)
        details["controlReplaced"] = "false"
        details["failureDetected"] = "unobserved"
        recordDiagnostic("volume_refresh_requested", details)
    }

    @MainActor
    private func prepareVolumeControl() async {
        guard let attempt = activation.begin(backgroundRevision: backgroundRevision,
            isActive: scenePhase == .active, timerIsSelected: isFocused) else { return }
        var details = diagnosticSnapshot
        details["setupAttemptID"] = String(attempt.id)
        details["backgroundRevision"] = String(attempt.backgroundRevision)
        details["source"] = attempt.source.rawValue
        details["settlingSeconds"] = String(VolumeActivationState.settlingSeconds)
        details["failureDetected"] = "unobserved"
        recordDiagnostic("volume_setup_scheduled", details)
        do {
            try await Task.sleep(for: .seconds(VolumeActivationState.settlingSeconds))
            try Task.checkCancellation()
        } catch {
            activation.cancel(attempt)
            details["reason"] = "eligibility_changed_or_view_removed"
            recordDiagnostic("volume_setup_cancelled", details)
            return
        }
        guard activation.complete(attempt), let generation = refresh.request(source: attempt.source) else { return }
        details["previousVolumeRequestGeneration"] = String(generation - 1)
        details["volumeRequestGeneration"] = String(generation)
        details["controlReplaced"] = "false"
        recordDiagnostic("volume_setup_requested", details)
    }
}

