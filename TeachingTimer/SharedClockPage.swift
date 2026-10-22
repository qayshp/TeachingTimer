import SwiftUI
import WatchKit

enum ClockFaceKind { case squircleIntersection, squircleClipped, circular }
enum ClockFaceLayer { case complete, dial, secondsHand }

struct SharedClockPage: View {
    let date: Date
    let face: ClockFaceKind
    @ObservedObject var session: ExtendedRuntimeController
    @ObservedObject var classStore: ClassStore
    @ObservedObject var metronome: MetronomeController
    let retireOldClass: () -> Bool
    let crownIsActive: Bool
    var showsClassProgress = false
    @State private var classSheet: ClassSheetRequest?
    @AppStorage("countVibrationsEnabled") private var countVibrationsEnabled = true
    @AppStorage("showRemainingMinutes") private var showRemainingMinutes = false
    @Environment(\.isLuminanceReduced) private var dimmed
    @ScaledMetric(relativeTo: .caption) private var labelSize = 13.0

    var body: some View {
        let frame = metronome.frame(at: date)
        GeometryReader { geometry in
            let layout = TimerFaceLayout(size: geometry.size)
            ZStack {
                clockFace(layer: .dial)
                ClockAdditions(date: date, face: face, context: classStore.context,
                    showsClassProgress: showsClassProgress,
                    landmarkStartAngle: frame.isVisible ? metronome.startAngle : nil,
                    landmarkProgress: frame.progress)
                    .allowsHitTesting(false)
                Button("Class") { classSheet = ClassSheetRequest() }
                    .font(.system(size: min(labelSize, 16), weight: .semibold))
                    .frame(width: 52, height: 44).contentShape(Rectangle())
                    .buttonStyle(.plain).position(x: 34, y: 23)
                    .accessibilityLabel("Class options").accessibilityIdentifier("class-options")
                CompanionVolumeControl(isFocused: crownIsActive && classSheet == nil)
                    .frame(width: layout.volumeSize.width, height: layout.volumeSize.height)
                    .background { Circle().fill(.black).frame(width: 38, height: 38).allowsHitTesting(false) }
                    .position(layout.volumeCenter)
                    .accessibilityLabel("iPhone playback volume")
                actions(layout: layout).position(x: geometry.size.width / 2, y: layout.actionY)
                HStack(spacing: 3) {
                    if metronome.hapticsStopped { Image(systemName: "hand.raised.slash").accessibilityHidden(true) }
                    Text(faceStatus)
                }
                    .font(.system(size: min(labelSize, 15)))
                    .lineLimit(1).minimumScaleFactor(0.85)
                    .frame(width: layout.controlsWidth, height: 18)
                    .position(layout.statusCenter).allowsHitTesting(false)
                WallClockMinuteHand(date: date).allowsHitTesting(false)
                clockFace(layer: .secondsHand).allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .containerBackground(.black, for: .tabView)
        .sheet(item: $classSheet) { _ in
            ClassControlsView(session: session, classStore: classStore, metronome: metronome)
        }
    }

    private var faceStatus: String {
        if metronome.hapticsStopped { return "Vibrations off" }
        if session.phase == .starting { return "Starting…" }
        if session.phase == .expiring { return session.statusText }
        if classStore.context != nil && !session.isActive { return "Session off" }
        if metronome.isActive && !metronome.configuration.hapticsEnabled { return "Visual count" }
        if showRemainingMinutes, let context = classStore.context {
            if date < context.scheduledStart { return "Starts " + context.scheduledStart.formatted(date: .omitted, time: .shortened) }
            let minutes = max(0, Int(ceil(context.scheduledEnd.timeIntervalSince(date) / 60)))
            return minutes > 0 ? "\(minutes) min left" : "Class time reached"
        }
        return ""
    }

    @ViewBuilder private func actions(layout: TimerFaceLayout) -> some View {
        if classStore.context == nil {
            Button("Start class") { retireOldClass(); classSheet = ClassSheetRequest() }
                .font(.system(size: labelSize, weight: .semibold))
                .frame(width: layout.controlsWidth, height: layout.actionHeight)
                .background(.black, in: Capsule())
                .overlay(Capsule().stroke(.white, lineWidth: 1))
                .contentShape(Rectangle()).buttonStyle(.plain)
                .accessibilityIdentifier("class-start")
        } else {
            HStack(spacing: 4) {
                Button {
                    if metronome.isActive { metronome.cancel() }
                    else { metronome.start(configuration: .init(hapticsEnabled: countVibrationsEnabled)) }
                } label: {
                    ViewThatFits(in: .horizontal) {
                        Text(metronome.isActive ? "Stop count" : "1-min count").fixedSize()
                        Text(metronome.isActive ? "Stop" : "Count").fixedSize()
                        Image(systemName: metronome.isActive ? "stop.fill" : "timer")
                    }
                    .font(.system(size: labelSize, weight: .semibold))
                    .frame(width: session.isActive ? layout.controlsWidth : layout.countWidth,
                           height: layout.actionHeight)
                    .background(.black, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white, lineWidth: metronome.isActive ? 2 : 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityIdentifier("metronome-toggle")
                .accessibilityLabel(metronome.isActive ? "Stop count" : "Start one-minute count")
                .accessibilityValue(metronome.hapticsStopped ? "Counting without vibrations" : (metronome.isActive ? "Counting" : "Ready"))
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
        switch face {
        case .squircleIntersection: SquircleIntersectionClockView(date: date, dimmed: dimmed, layer: layer)
        case .squircleClipped: SquircleClippedClockView(date: date, dimmed: dimmed, layer: layer)
        case .circular: CircularClockView(date: date, dimmed: dimmed, layer: layer)
        }
    }
}

private struct ClassSheetRequest: Identifiable {
    let id = UUID()
}

/// Secondary management UI owns its draft and dismissal; runtime state remains independent.
private struct ClassControlsView: View {
    enum Mode { case summary, create, edit }
    @ObservedObject var session: ExtendedRuntimeController
    @ObservedObject var classStore: ClassStore
    @ObservedObject var metronome: MetronomeController
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .summary
    @State private var start = Date()
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
                        Text(session.statusText).font(.caption)
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
                        if !metronome.lastResult.isEmpty { Text(metronome.lastResult).font(.caption) }
                    }
                    Button("End class", role: .destructive) { confirmEnd = true }
                } else {
                    Section("Scheduled start") {
                        Text(start.formatted(date: .abbreviated, time: .omitted)).font(.caption)
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
                    Button(mode == .edit ? "Save schedule" : "Start class") {
                        if mode == .create && classStore.context != nil { confirmReplacement = true }
                        else { save() }
                    }.accessibilityIdentifier("confirm-class")
                    if mode == .create {
                        Text("Check the suggested time before starting.").font(.caption)
                    }
                }
            }
            .navigationTitle(mode == .edit ? "Schedule" : (mode == .create ? "New class" : "Class"))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
        .onAppear {
            if classStore.context == nil { prepareNew() }
        }
        .alert("Start new class?", isPresented: $confirmReplacement) {
            Button("Start new", role: .destructive) { save() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Replaces timing and stops the count.") }
        .alert("End class?", isPresented: $confirmEnd) {
            Button("End class", role: .destructive) {
                session.stop(source: "new_class_reset")
                metronome.cancel(reason: "new_class_reset")
                classStore.reset()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Clears timing and stops the session and count.") }
    }

    private func prepareNew() {
        start = ClassContext.inferredStart(for: Date())
        duration = 60
        mode = .create
    }

    private func save() {
        if mode == .edit {
            classStore.updateSchedule(start: start, durationMinutes: duration)
        } else {
            metronome.cancel(reason: "new_class_reset")
            // The confirmation is the actual Start action; opening the draft
            // earlier must not claim that the class was already running.
            classStore.begin(at: Date(), scheduledStart: start, durationMinutes: duration)
            if !session.isActive { session.start() }
        }
        dismiss()
    }
}

struct CompanionVolumeControl: WKInterfaceObjectRepresentable {
    let isFocused: Bool

    func makeWKInterfaceObject(context: Context) -> WKInterfaceVolumeControl {
        let volumeControl = WKInterfaceVolumeControl(origin: .companion)
        // Native tint affects the resting appearance only. System adjustment
        // feedback and unavailable-source presentation remain system-owned.
        volumeControl.setTintColor(.white)
        return volumeControl
    }

    func updateWKInterfaceObject(
        _ volumeControl: WKInterfaceVolumeControl,
        context: Context
    ) {
        guard context.coordinator.isFocused != isFocused else { return }
        context.coordinator.isFocused = isFocused

        DispatchQueue.main.async {
            if isFocused {
                volumeControl.focus()
            } else {
                volumeControl.resignFocus()
            }
        }
    }

    static func dismantleWKInterfaceObject(
        _ volumeControl: WKInterfaceVolumeControl,
        coordinator: Coordinator
    ) {
        volumeControl.resignFocus()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var isFocused = false
    }
}
