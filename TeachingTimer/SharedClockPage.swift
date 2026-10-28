// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import WatchKit

enum ClockFaceLayer { case complete, dial, secondsHand }

struct SharedClockPage: View {
    let date: Date
    @ObservedObject var session: ExtendedRuntimeController
    @ObservedObject var classStore: ClassStore
    @ObservedObject var landmarks: LandmarkController
    let retireOldClass: () -> Bool
    let crownIsActive: Bool
    let volumeBackgroundRevision: Int
    var showsClassProgress = false
    @State private var classSheet: ClassSheetRequest?
    @AppStorage("countVibrationsEnabled") private var countVibrationsEnabled = true
    @AppStorage("showRemainingMinutes") private var showRemainingMinutes = false
    @Environment(\.isLuminanceReduced) private var dimmed
    @ScaledMetric(relativeTo: .caption) private var labelSize = 13.0

    var body: some View {
        let frame = landmarks.frame(at: date)
        GeometryReader { geometry in
            let layout = TimerFaceLayout(size: geometry.size)
            ZStack {
                Button { classSheet = ClassSheetRequest() } label: {
                    HStack(spacing: 3) {
                        Text("Class")
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                    }
                    .font(.system(size: min(labelSize, 14), weight: .semibold))
                    .padding(.horizontal, 7).padding(.vertical, 5)
                    .background(Capsule().fill(.black))
                    .overlay(Capsule().strokeBorder(.primary, lineWidth: 1))
                    .frame(width: 64, height: 44).contentShape(Rectangle())
                }
                    .buttonStyle(.plain).position(x: 38, y: 23)
                    .accessibilityLabel("Class options").accessibilityIdentifier("class-options")
                // The edge-to-edge dial stays visible over the Class capsule.
                // These drawing layers must not intercept the button's touches.
                clockFace(layer: .dial).allowsHitTesting(false)
                ClockAdditions(date: date, context: classStore.context,
                    showsClassProgress: showsClassProgress,
                    landmarkStartAngle: frame.isVisible ? landmarks.startAngle : nil,
                    landmarkProgress: frame.progress)
                    .allowsHitTesting(false)
                RefreshableCompanionVolumeControl(
                    layout: layout,
                    isFocused: crownIsActive && classSheet == nil,
                    backgroundRevision: volumeBackgroundRevision,
                    diagnosticSnapshot: volumeDiagnosticSnapshot,
                    recordDiagnostic: { [weak diagnosticSession = session] event, details in
                        diagnosticSession?.recordInterfaceEvent(event, details: details)
                    }
                )
                    .position(layout.volumeCenter)
                actions(layout: layout).position(x: geometry.size.width / 2, y: layout.actionY)
                Text(faceStatus).lineLimit(1).minimumScaleFactor(0.7)
                    .font(.system(size: min(labelSize, 15)))
                    .frame(width: layout.controlsWidth, height: 18)
                    .position(layout.statusCenter).allowsHitTesting(false)
                WallClockMinuteHand(date: date).allowsHitTesting(false)
                clockFace(layer: .secondsHand).allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .containerBackground(.black, for: .tabView)
        .sheet(item: $classSheet) { _ in
            ClassControlsView(session: session, classStore: classStore, landmarks: landmarks)
        }
#if DEBUG
        .onAppear {
            // Visual check only: opens a draft, never starts a class or runtime.
            if ProcessInfo.processInfo.arguments.contains("--show-class-setup") {
                classSheet = ClassSheetRequest()
            }
        }
#endif
        .onChange(of: classSheet?.id) { _, _ in
            session.recordInterfaceEvent("class_sheet_state_changed", details: volumeDiagnosticSnapshot)
        }
    }

    private var volumeDiagnosticSnapshot: [String: String] {
        ["lastViewTimerPageSelected": String(crownIsActive),
         "lastViewClassSheetRequested": String(classSheet != nil),
         "lastViewLuminanceReduced": String(dimmed)]
    }

    private var faceStatus: String {
        if session.phase == .starting { return "Starting…" }
        if session.phase == .expiring { return session.statusText }
        if classStore.context != nil && !session.isActive { return "Session off" }
        if landmarks.isActive && !landmarks.configuration.hapticsEnabled { return "Visual count" }
        if showRemainingMinutes, let context = classStore.context {
            if date < context.scheduledStart { return "Starts " + context.scheduledStart.formatted(date: .omitted, time: .shortened) }
            let minutes = max(0, Int(ceil(context.scheduledEnd.timeIntervalSince(date) / 60)))
            return minutes > 0 ? "\(minutes) min left" : "Class time reached"
        }
        return ""
    }

    @ViewBuilder private func actions(layout: TimerFaceLayout) -> some View {
        if classStore.context == nil {
            Button { _ = retireOldClass(); classSheet = ClassSheetRequest() } label: {
                ViewThatFits(in: .horizontal) {
                    Text("Start class").fixedSize()
                    Text("Start").fixedSize()
                }
                    .font(.system(size: labelSize, weight: .semibold))
                    .frame(width: layout.controlsWidth, height: layout.actionHeight)
                    .background(.black, in: Capsule())
                    .overlay(Capsule().stroke(.white, lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityIdentifier("class-start")
        } else {
            HStack(spacing: 4) {
                Button {
                    if landmarks.isActive { landmarks.cancel() }
                    else { landmarks.start(configuration: .init(hapticsEnabled: countVibrationsEnabled)) }
                } label: {
                    ViewThatFits(in: .horizontal) {
                        Text(landmarks.isActive ? "Stop count" : "1-min count").fixedSize()
                        Text(landmarks.isActive ? "Stop" : "Count").fixedSize()
                        Image(systemName: landmarks.isActive ? "stop.fill" : "timer")
                    }
                    .font(.system(size: labelSize, weight: .semibold))
                    .padding(.horizontal, 6)
                    .frame(width: session.isActive ? layout.controlsWidth : layout.countWidth,
                           height: layout.actionHeight)
                    .background(.black, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white, lineWidth: landmarks.isActive ? 2 : 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityIdentifier("metronome-toggle")
                .accessibilityLabel(landmarks.isActive ? "Stop count" : "Start one-minute count")
                .accessibilityValue(landmarks.isActive ? (landmarks.configuration.hapticsEnabled ? "Counting" : "Visual count") : "Ready")
                .accessibilityHint("Six ten-second landmarks. Tap again to stop.")
                if !session.isActive {
                    Button { guard !retireOldClass() else { return }; session.start() } label: {
                        Text("Resume")
                            .font(.system(size: min(labelSize, 12), weight: .semibold))
                            .lineLimit(1).minimumScaleFactor(0.75)
                            .padding(.horizontal, 4)
                            .frame(width: layout.optionsWidth, height: layout.actionHeight)
                            .background(.black, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white, lineWidth: 1))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Resume session").accessibilityIdentifier("runtime-toggle")
                }
            }
        }
    }

    @ViewBuilder private func clockFace(layer: ClockFaceLayer) -> some View {
        SquircleIntersectionClockView(date: date, dimmed: dimmed, layer: layer)
    }
}

private struct ClassSheetRequest: Identifiable {
    let id = UUID()
}

