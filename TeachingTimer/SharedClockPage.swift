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
                .accessibilityValue(landmarks.hapticsStopped ? "Counting without vibrations" : (landmarks.isActive ? "Counting" : "Ready"))
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

/// Secondary management UI owns its draft and dismissal; runtime state remains independent.
private struct ClassControlsView: View {
    enum Mode: Hashable { case summary, create, adjustNew, edit }
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
                        VStack(alignment: .leading, spacing: 4) {
                            Text(current.scheduledStart.formatted(date: .omitted, time: .shortened) + "–" +
                                 current.scheduledEnd.formatted(date: .omitted, time: .shortened))
                                .font(.headline).fixedSize(horizontal: false, vertical: true)
                            Text("\(current.durationMinutes) minutes").font(.caption)
                            if !session.statusText.isEmpty { Text(session.statusText).font(.caption) }
                        }
                    }
                    Section {
                        classAction(session.isActive ? "Stop session" : "Resume session",
                                    icon: session.isActive ? "pause.fill" : "play.fill",
                                    prominent: !session.isActive) {
                            if session.isActive { session.stop() } else { session.start() }
                            dismiss()
                        }
                        .disabled(session.phase == .starting)
                        .accessibilityIdentifier("class-session-toggle")
                    } footer: {
                        Text("Stopping keeps class timing. Wrist-down updates may slow.")
                    }
                    Section("Schedule") {
                        classAction("Edit schedule", icon: "calendar") {
                            start = current.scheduledStart; duration = current.durationMinutes; mode = .edit
                        }.accessibilityIdentifier("edit-class-schedule")
                        classAction("New class", icon: "plus") { prepareNew() }
                            .accessibilityIdentifier("new-class")
                    }
                    Section("Count & display") {
                        Toggle("Count vibrations", isOn: $countVibrationsEnabled)
                        Text("Applies to the next count. Timing may vary if watchOS delays a vibration.").font(.caption)
                        Toggle("Minutes left", isOn: $showRemainingMinutes)
                        if !landmarks.lastResult.isEmpty { Text(landmarks.lastResult).font(.caption) }
                    }
                    Section {
                        classAction("End class", icon: "xmark.circle", role: .destructive) { confirmEnd = true }
                            .accessibilityIdentifier("end-class")
                    }
                } else if mode == .create {
                    Button(action: confirmStart) {
                        VStack(spacing: 6) {
                            ViewThatFits(in: .horizontal) {
                                Label("Start class", systemImage: "play.fill").fixedSize()
                                Label("Start", systemImage: "play.fill").fixedSize()
                            }
                            .font(.headline)
                            Text("60 minutes").font(.caption)
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
                    .buttonStyle(ClassActionStyle(prominent: true))
                    .listRowBackground(Color.clear)
                    .accessibilityLabel("Start 60-minute class")
                    .accessibilityValue(defaultStart.formatted(date: .omitted, time: .shortened) + " to " +
                        defaultStart.addingTimeInterval(3600).formatted(date: .omitted, time: .shortened))
                    .accessibilityIdentifier("confirm-class")
                    classAction("Custom schedule", icon: "slider.horizontal.3") { mode = .adjustNew }
                        .accessibilityIdentifier("adjust-class-schedule")
                } else {
                    Section("Scheduled start") {
                        if !Calendar.current.isDateInToday(start) {
                            Text(start.formatted(date: .abbreviated, time: .omitted)).font(.caption)
                        }
                        VStack(spacing: 8) {
                            Text(start.formatted(date: .omitted, time: .shortened))
                                .font(.headline).frame(maxWidth: .infinity)
                            HStack(spacing: 8) {
                                Button("−15 min") { start = start.addingTimeInterval(-900) }
                                    .accessibilityLabel("Start fifteen minutes earlier")
                                    .accessibilityIdentifier("start-earlier")
                                Button("+15 min") { start = start.addingTimeInterval(900) }
                                    .accessibilityLabel("Start fifteen minutes later")
                                    .accessibilityIdentifier("start-later")
                            }
                            .buttonStyle(ClassActionStyle(compact: true))
                        }
                    }
                    Picker("Duration", selection: $duration) {
                        Text("60 min").tag(60)
                        Text("75 min").tag(75)
                    }
                    Text("Ends " + start.addingTimeInterval(Double(duration) * 60).formatted(date: .omitted, time: .shortened))
                    classAction(mode == .edit ? "Save schedule" : "Start class",
                                icon: mode == .edit ? "checkmark" : "play.fill", prominent: true,
                                action: confirmStart)
                        .accessibilityIdentifier("confirm-class")
                    if mode == .adjustNew {
                        Text("Only this class. The default stays 60 minutes at the suggested start.").font(.caption)
                        classAction("Default schedule", icon: "arrow.uturn.backward") { mode = .create }
                    }
                }
            }
            // A different task starts at its first row, not the summary's old
            // scroll offset. Only this Form is recreated; shared app state stays.
            .id(mode)
            .navigationTitle(mode == .summary ? "Class" : (mode == .create ? "Start" : "Time"))
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button(mode == .summary ? "Done" : "Cancel") { dismiss() }
            } }
        }
#if DEBUG
        // Sheet presentation can reset the environment inherited from TabView.
        // Apply the visual-test size explicitly to this presentation as well.
        .transformEnvironment(\.dynamicTypeSize) { size in
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--maximum-text") { size = .accessibility5 }
            else if arguments.contains("--accessibility-text") { size = .accessibility3 }
            else if arguments.contains("--large-text") { size = .xxxLarge }
        }
#endif
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

    private func classAction(_ title: String, icon: String, prominent: Bool = false,
                             role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).frame(width: 18).accessibilityHidden(true)
                Text(title).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(ClassActionStyle(prominent: prominent, destructive: role == .destructive))
        .listRowBackground(Color.clear)
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
            session.synchronizeClass(classStore.context)
            session.start()
        }
        dismiss()
    }
}

/// Explicit action surfaces stay distinct from read-only Form rows in monochrome.
private struct ClassActionStyle: ButtonStyle {
    var prominent = false
    var destructive = false
    var compact = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(compact ? .caption.weight(.semibold) : .body.weight(.semibold))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, compact ? 3 : 8).padding(.vertical, compact ? 0 : 4)
            .foregroundStyle(prominent ? Color.black : (destructive ? .red : .white))
            .background(prominent ? Color.white : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(prominent ? .clear : .white, lineWidth: 1))
            .opacity(!isEnabled ? 0.4 : (configuration.isPressed ? 0.65 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct RefreshableCompanionVolumeControl: View {
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
