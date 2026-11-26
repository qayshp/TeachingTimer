// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import WatchKit

enum ClockFaceLayer { case complete, dial, secondsHand }

struct SharedClockPage: View {
    let clockTimelineAnchor: Date
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
        GeometryReader { geometry in
            let layout = TimerFaceLayout(size: geometry.size)
            ZStack {
                // Ticks sit behind the translucent settings backing and native time.
                // Drawing must not intercept the button's touches or Crown focus.
                // Dial geometry is independent of the sampled clock date.
                clockFace(at: clockTimelineAnchor, layer: .dial).allowsHitTesting(false)
                Button { classSheet = ClassSheetRequest() } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: min(labelSize + 3, 19), weight: .semibold))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(.black.opacity(1 - SquircleClockTuning.obscuredTickOpacity)))
                        .overlay(Circle().strokeBorder(.primary, lineWidth: 1))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                    .buttonStyle(.plain).position(layout.classControlCenter)
                    .accessibilityLabel("Class options and settings")
                    .accessibilityHint("Opens class timing, session controls, and settings.")
                    .accessibilityIdentifier("class-options")
                // Native volume stays in the stable page host, outside timeline
                // rendering. Its retained identity and focus inputs are unchanged.
                RefreshableCompanionVolumeControl(
                    layout: layout,
                    isFocused: crownIsActive && classSheet == nil && !classStore.needsRecoveryNotice,
                    backgroundRevision: volumeBackgroundRevision,
                    diagnosticSnapshot: volumeDiagnosticSnapshot,
                    recordDiagnostic: { [weak diagnosticSession = session] event, details in
                        diagnosticSession?.recordInterfaceEvent(event, details: details)
                    }
                )
                    .position(layout.volumeCenter)
                TimelineView(.periodic(from: clockTimelineAnchor, by: 1)) { context in
                    let date = context.date
                    let frame = landmarks.frame(at: date)
                    ZStack {
                        // These perimeter markings stay clear of the volume
                        // target. One sampled date drives all changing graphics.
                        ClockAdditions(date: date, context: classStore.context,
                            showsClassProgress: showsClassProgress,
                            landmarkStartAngle: frame.isVisible ? landmarks.startAngle : nil,
                            landmarkProgress: frame.progress)
                            .allowsHitTesting(false)
                        actions(layout: layout, at: date)
                            .position(x: geometry.size.width / 2, y: layout.actionY)
                        // Preserve both hands above controls, including volume.
                        WallClockMinuteHand(date: date).allowsHitTesting(false)
                        clockFace(at: date, layer: .secondsHand).allowsHitTesting(false)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .NSSystemClockDidChange)) { _ in
                        context.invalidateTimelineContent()
                    }
                    .onChange(of: landmarks.isActive) { _, _ in
                        context.invalidateTimelineContent()
                    }
                    .onChange(of: classStore.context) { _, _ in
                        context.invalidateTimelineContent()
                    }
                }
            }
        }
        .ignoresSafeArea()
        .containerBackground(.black, for: .tabView)
        .sheet(item: $classSheet) { _ in
            ClassControlsView(session: session, classStore: classStore, landmarks: landmarks,
                              retireOldClass: retireOldClass)
        }
        .alert("Class not restored", isPresented: Binding(
            get: { classStore.needsRecoveryNotice },
            set: { if !$0 { classStore.acknowledgeRecoveryNotice() } }
        )) {
            Button("Start class") { classSheet = ClassSheetRequest() }
            Button("Later", role: .cancel) { classStore.acknowledgeRecoveryNotice() }
        } message: {
            Text("Start a new class to continue.")
        }
#if DEBUG
        .onAppear {
            // Visual check only: opens a draft, never starts a class or runtime.
            if ProcessInfo.processInfo.arguments.contains("--show-class-setup") || ProcessInfo.processInfo.arguments.contains("--show-settings") {
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
         "lastViewClassRecoveryNotice": String(classStore.needsRecoveryNotice),
         "lastViewLuminanceReduced": String(dimmed)]
    }

    private func faceStatus(at date: Date) -> String {
        if session.phase == .starting { return "Starting…" }
        if session.phase == .expiring { return session.statusText }
        if landmarks.isActive && !landmarks.configuration.hapticsEnabled { return "Visual count" }
        if showRemainingMinutes, let context = classStore.context {
            if date < context.scheduledStart { return "Starts " + context.scheduledStart.formatted(date: .omitted, time: .shortened) }
            let minutes = max(0, Int(ceil(context.scheduledEnd.timeIntervalSince(date) / 60)))
            return minutes > 0 ? "\(minutes) min left" : "Class time reached"
        }
        return ""
    }

    @ViewBuilder private func actions(layout: TimerFaceLayout, at date: Date) -> some View {
        let faceStatus = faceStatus(at: date)
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
            .buttonStyle(.plain)
            .accessibilityLabel("Start class").accessibilityIdentifier("class-start")
        } else {
            HStack(spacing: 4) {
                Button {
                    if landmarks.isActive { landmarks.cancel() }
                    else { landmarks.start(configuration: .init(hapticsEnabled: countVibrationsEnabled)) }
                } label: {
                    VStack(spacing: session.isActive ? 2 : 1) {
                        ViewThatFits(in: .horizontal) {
                            Text(landmarks.isActive ? "Stop count" : "1-min count").fixedSize()
                            Text(landmarks.isActive ? "Stop" : "Count").fixedSize()
                            Image(systemName: landmarks.isActive ? "stop.fill" : "timer")
                        }
                        .font(.system(size: min(labelSize, session.isActive ? (faceStatus.isEmpty ? 22 : 17) : 14), weight: .semibold))
                        if !faceStatus.isEmpty {
                            Text(faceStatus)
                                // Keep count information with the count control;
                                // the separate session action explains recovery.
                                .font(.system(size: min(labelSize, session.isActive ? 12 : 10)))
                                .lineLimit(session.isActive ? 1 : 2)
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.8)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 6)
                    .frame(width: session.isActive ? layout.controlsWidth : layout.countWidth,
                           height: layout.actionHeight)
                    .background(.black, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white, lineWidth: landmarks.isActive ? 2 : 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityIdentifier("metronome-toggle")
                .accessibilityLabel(landmarks.isActive ? "Stop count" : "Start one-minute count")
                .accessibilityValue((landmarks.isActive ? (landmarks.configuration.hapticsEnabled ? "Counting" : "Visual count") : "Ready")
                    + (faceStatus.isEmpty ? "" : ". " + faceStatus))
                .accessibilityHint("Six ten-second landmarks. Tap again to stop.")
                if !session.isActive {
                    Button { guard !retireOldClass() else { return }; session.start() } label: {
                        VStack(spacing: 1) {
                            ForEach(session.actionTitle(hasClass: true).split(separator: " "), id: \.self) { word in
                                Text(String(word)).lineLimit(1).minimumScaleFactor(0.75)
                            }
                        }
                            .font(.system(size: min(labelSize, 11), weight: .semibold))
                            .padding(.horizontal, 4)
                            .frame(width: layout.optionsWidth, height: layout.actionHeight)
                            .background(.black, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white, lineWidth: 1))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(session.actionTitle(hasClass: true))
                    .accessibilityHint("Starts the session for wrist-down updates. Class timing is unchanged.")
                    .accessibilityIdentifier("runtime-toggle")
                }
            }
        }
    }

    @ViewBuilder private func clockFace(at date: Date, layer: ClockFaceLayer) -> some View {
        SquircleIntersectionClockView(date: date, dimmed: dimmed, layer: layer)
    }
}

private struct ClassSheetRequest: Identifiable {
    let id = UUID()
}
