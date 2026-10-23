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
                }
                    .frame(width: 64, height: 44).contentShape(Rectangle())
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
                CompanionVolumeControl(
                    isFocused: crownIsActive && classSheet == nil,
                    diagnosticSnapshot: volumeDiagnosticSnapshot,
                    recordDiagnostic: { [weak diagnosticSession = session] event, details in
                        diagnosticSession?.recordInterfaceEvent(event, details: details)
                    }
                )
                    .frame(width: layout.volumeSize.width, height: layout.volumeSize.height)
                    .background { Circle().fill(.black).frame(width: 38, height: 38).allowsHitTesting(false) }
                    .position(layout.volumeCenter)
                    .accessibilityLabel("iPhone playback volume")
                actions(layout: layout).position(x: geometry.size.width / 2, y: layout.actionY)
                HStack(spacing: 3) {
                    if landmarks.hapticsStopped {
                        Image(systemName: "hand.raised.slash").frame(width: 13).accessibilityHidden(true)
                    }
                    Text(faceStatus).lineLimit(1).minimumScaleFactor(0.7)
                }
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
        if landmarks.hapticsStopped { return "Vibrations off" }
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
            Button("Start class") { _ = retireOldClass(); classSheet = ClassSheetRequest() }
                .font(.system(size: labelSize, weight: .semibold))
                .frame(width: layout.controlsWidth, height: layout.actionHeight)
                .background(.black, in: Capsule())
                .overlay(Capsule().stroke(.white, lineWidth: 1))
                .contentShape(Rectangle()).buttonStyle(.plain)
                .accessibilityIdentifier("class-start")
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
                    .frame(width: session.isActive ? layout.controlsWidth : layout.countWidth,
                           height: layout.actionHeight)
                    .background(.black, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white, lineWidth: landmarks.isActive ? 2 : 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityIdentifier("metronome-toggle")
                .accessibilityLabel(landmarks.isActive ? "Stop count" : "Start one-minute count")
                .accessibilityValue(landmarks.hapticsStopped ? "Counting without vibrations" : (landmarks.isActive ? "Counting" : "Ready"))
                .accessibilityHint("Six ten-second landmarks. Tap again to stop.")
                if !session.isActive {
                    Button("Resume") { guard !retireOldClass() else { return }; session.start() }
                        .font(.system(size: min(labelSize, 12), weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.75)
                        .frame(width: layout.optionsWidth, height: layout.actionHeight)
                        .contentShape(Rectangle()).buttonStyle(.plain)
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

/// Secondary management UI owns its draft and dismissal; runtime state remains independent.
private struct ClassControlsView: View {
    enum Mode { case summary, create, adjustNew, edit }
    @ObservedObject var session: ExtendedRuntimeController
    @ObservedObject var classStore: ClassStore
    @ObservedObject var landmarks: LandmarkController
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .summary
    @State private var start = Date()
    @State private var defaultStart = Date()
    @State private var duration = 60
    @State private var confirmReplacement = false
    @State private var confirmEnd = false
    @AppStorage("countVibrationsEnabled") private var countVibrationsEnabled = true
    @AppStorage("showRemainingMinutes") private var showRemainingMinutes = false

    var body: some View {
        NavigationStack {
            Form {
                if mode == .summary, let current = classStore.context {
                    Section {
                        Text(current.scheduledStart.formatted(date: .omitted, time: .shortened) + "–" +
                             current.scheduledEnd.formatted(date: .omitted, time: .shortened))
                        Text("\(current.durationMinutes) minutes").font(.caption)
                        if !session.statusText.isEmpty { Text(session.statusText).font(.caption) }
                    }
                    Button("Edit schedule") {
                        start = current.scheduledStart; duration = current.durationMinutes; mode = .edit
                    }
                    Button("New class") { prepareNew() }
                        .accessibilityIdentifier("new-class")
                    Button(session.isActive ? "Stop session" : "Resume session") {
                        if session.isActive { session.stop() } else { session.start() }
                    }.disabled(session.phase == .starting)
                    Text("Stopping the session keeps class timing. Wrist-down updates may slow.")
                        .font(.caption)
                    Section("Count & display") {
                        Toggle("Count vibrations", isOn: $countVibrationsEnabled)
                        Text("Applies to the next count. If vibrations are delayed, the arc keeps going.").font(.caption)
                        Toggle("Minutes left", isOn: $showRemainingMinutes)
                        if !landmarks.lastResult.isEmpty { Text(landmarks.lastResult).font(.caption) }
                    }
                    Button("End class", role: .destructive) { confirmEnd = true }
                } else if mode == .create {
                    Button(action: confirmStart) {
                        VStack(spacing: 6) {
                            Text("Start 60-min class")
                                .font(.headline)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(defaultStart.formatted(date: .omitted, time: .shortened) + "–" +
                                 defaultStart.addingTimeInterval(3600).formatted(date: .omitted, time: .shortened))
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("confirm-class")
                    Button("Custom schedule") { mode = .adjustNew }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("adjust-class-schedule")
                } else {
                    Section("Scheduled start") {
                        if !Calendar.current.isDateInToday(start) {
                            Text(start.formatted(date: .abbreviated, time: .omitted)).font(.caption)
                        }
                        HStack {
                            Button("−15") { start = start.addingTimeInterval(-900) }
                                .buttonStyle(.plain)
                                .frame(minWidth: 44, minHeight: 44).accessibilityLabel("Start fifteen minutes earlier")
                            Text(start.formatted(date: .omitted, time: .shortened)).font(.headline).minimumScaleFactor(0.7)
                            Button("+15") { start = start.addingTimeInterval(900) }
                                .buttonStyle(.plain)
                                .frame(minWidth: 44, minHeight: 44).accessibilityLabel("Start fifteen minutes later")
                        }
                    }
                    Picker("Duration", selection: $duration) {
                        Text("60 min").tag(60)
                        Text("75 min").tag(75)
                    }
                    Text("Ends " + start.addingTimeInterval(Double(duration) * 60).formatted(date: .omitted, time: .shortened))
                    Button(mode == .edit ? "Save schedule" : "Start custom class", action: confirmStart)
                        .accessibilityIdentifier("confirm-class")
                    if mode == .adjustNew {
                        Button("Back to default") { mode = .create }
                            .frame(minHeight: 44)
                    }
                }
            }
            .navigationTitle(mode == .edit ? "Schedule" : (mode == .summary ? "Class" : (mode == .adjustNew ? "Custom class" : "New class")))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
        .onAppear {
            if classStore.context == nil { prepareNew() }
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--show-class-setup") {
                prepareNew()
                if ProcessInfo.processInfo.arguments.contains("--show-class-adjustments") {
                    mode = .adjustNew
                }
            }
#endif
        }
        .onChange(of: classStore.context) { _, context in
            // Retirement can occur while this sheet is open. Don't expose an
            // uninitialized schedule draft when the old summary disappears.
            if context == nil && mode == .summary { prepareNew() }
        }
        .alert("Start new class?", isPresented: $confirmReplacement) {
            Button("Start new", role: .destructive) { save() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Replaces timing and stops the count.") }
        .alert("End class?", isPresented: $confirmEnd) {
            Button("End class", role: .destructive) {
                session.stop(source: "new_class_reset")
                landmarks.cancel(reason: "new_class_reset")
                classStore.reset()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Clears timing and stops the session and count.") }
    }

    private func prepareNew() {
        start = ClassContext.inferredStart(for: Date())
        defaultStart = start
        duration = 60
        mode = .create
    }

    private func confirmStart() {
        if mode != .edit && classStore.context != nil { confirmReplacement = true }
        else { save() }
    }

    private func save() {
        if mode == .edit {
            classStore.updateSchedule(start: start, durationMinutes: duration)
        } else {
            landmarks.cancel(reason: "new_class_reset")
            // The confirmation is the actual Start action; opening the draft
            // earlier must not claim that the class was already running.
            classStore.begin(at: Date(), scheduledStart: mode == .create ? defaultStart : start,
                             durationMinutes: mode == .create ? 60 : duration)
            if !session.isActive { session.start() }
        }
        dismiss()
    }
}

struct CompanionVolumeControl: WKInterfaceObjectRepresentable {
    let isFocused: Bool
    let diagnosticSnapshot: [String: String]
    let recordDiagnostic: (String, [String: String]) -> Void

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
        guard context.coordinator.isFocused != isFocused else { return }
        context.coordinator.isFocused = isFocused
        let request = diagnostics.requested(isFocused, source: "update")

        DispatchQueue.main.async {
            diagnostics.willInvoke(request)
            if isFocused {
                volumeControl.focus()
            } else {
                volumeControl.resignFocus()
            }
            diagnostics.didReturn(request)
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
        var isFocused = false
        let diagnostics: VolumeControlDiagnostics

        init(recordDiagnostic: @escaping (String, [String: String]) -> Void) {
            diagnostics = VolumeControlDiagnostics(record: recordDiagnostic)
        }
    }
}
