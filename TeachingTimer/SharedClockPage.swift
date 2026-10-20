import SwiftUI
import WatchKit

enum ClockFaceKind {
    case squircleIntersection
    case squircleClipped
    case circular
}

struct SharedClockPage: View {
    let date: Date
    let face: ClockFaceKind
    @ObservedObject var session: ExtendedRuntimeController
    @ObservedObject var classStore: ClassStore
    @ObservedObject var metronome: MetronomeController
    let crownIsActive: Bool
    var showsClassProgress = false
    @State private var confirmReset = false

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @ScaledMetric(relativeTo: .headline) private var countFontSize = 13.0
    @ScaledMetric(relativeTo: .caption) private var runtimeFontSize = 10.0

    var body: some View {
        let landmarkFrame = metronome.frame(at: date)
        GeometryReader { geometry in
            let layout = TimerFaceLayout(size: geometry.size)
            ZStack {
                clockFace
                ClockAdditions(date: date, face: face, context: classStore.context,
                               showsClassProgress: showsClassProgress,
                               landmarkStartAngle: landmarkFrame.isVisible ? metronome.startAngle : nil,
                               landmarkProgress: landmarkFrame.progress)
                    .allowsHitTesting(false)
                controls(layout: layout)
                    .position(layout.controlsCenter)
                CompanionVolumeControl(isFocused: crownIsActive && !confirmReset)
                    .frame(width: layout.volumeSize.width, height: layout.volumeSize.height)
                    .position(layout.volumeCenter)
                    .accessibilityLabel("iPhone playback volume")
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .containerBackground(.black, for: .tabView)
        .alert("Reset class?", isPresented: $confirmReset) {
            Button("Reset class", role: .destructive) {
                session.stop(source: "new_class_reset")
                metronome.cancel(reason: "new_class_reset")
                classStore.reset()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Ends the session and count. Clears class timing.")
        }
    }

    @ViewBuilder
    private var clockFace: some View {
        switch face {
        case .squircleIntersection:
            SquircleIntersectionClockView(date: date, dimmed: isLuminanceReduced)
        case .squircleClipped:
            SquircleClippedClockView(date: date, dimmed: isLuminanceReduced)
        case .circular:
            CircularClockView(date: date, dimmed: isLuminanceReduced)
        }
    }

    @ViewBuilder
    private func controls(layout: TimerFaceLayout) -> some View {
        VStack(spacing: layout.spacing) {
            Button {
                if metronome.isActive { metronome.cancel() } else { metronome.start() }
            } label: {
                ViewThatFits(in: .horizontal) {
                    Label(metronome.isActive ? "Stop count" : "Start count",
                      systemImage: metronome.isActive ? "stop.fill" : "metronome")
                        .fixedSize()
                    Image(systemName: metronome.isActive ? "stop.fill" : "metronome")
                }
                    .font(.system(size: countFontSize, weight: .bold))
                    .padding(.horizontal, 8)
                    .frame(width: layout.controlsWidth, height: layout.countHeight)
                    .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white, lineWidth: metronome.isActive ? 3 : 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("metronome-toggle")
            .accessibilityLabel(metronome.isActive ? "Stop count" : "Start count")
            .accessibilityValue(metronome.isActive ? (metronome.hapticsStopped ? "Counting without vibrations" : "Counting") : "Ready")
            .accessibilityHint(metronome.isActive ? "Stops the arc and vibrations." : "Starts a one-minute count. Vibrations mark ten-second intervals.")
            HStack(spacing: layout.spacing) {
                Button {
                    if session.isActive { session.stop() }
                    else { classStore.establishIfNeeded(); session.start() }
                } label: {
                    ViewThatFits(in: .vertical) {
                        Text(runtimeActionTitle)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Image(systemName: session.isActive ? "stop.fill" : "play.fill")
                    }
                        .font(.system(size: runtimeFontSize, weight: .semibold))
                        .frame(width: layout.controlsWidth - layout.resetSide - layout.spacing,
                               height: layout.runtimeHeight)
                        .background(.black.opacity(0.35), in: Capsule())
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(session.phase == .starting)
                .accessibilityLabel(runtimeActionTitle)
                .accessibilityHint(session.isActive ? "Stops the session and keeps class timing." : "Keeps the teaching clock active during class.")
                .accessibilityIdentifier("runtime-toggle")
                Button { confirmReset = true } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: layout.resetSide, height: layout.resetSide)
                        .background(.black.opacity(0.35), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reset class")
                .accessibilityHint("Asks before clearing class timing and stopping the session and count.")
                .accessibilityIdentifier("class-reset")
            }
            // Reserve the space so status transitions don't move the tap targets.
            VStack(spacing: 0) {
                Text(session.statusText)
                    .font(.system(size: 11 * layout.scale))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityIdentifier("runtime-status")
                Text(metronome.lastResult)
                    .font(.system(size: 10 * layout.scale))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityIdentifier("landmark-result")
                    .accessibilityLabel(metronome.lastResult)
            }
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(width: layout.controlsWidth, height: layout.statusHeight)
                .allowsHitTesting(false)
        }
        .frame(width: layout.controlsWidth, height: layout.controlsHeight)
    }

    private var runtimeActionTitle: String {
        session.isActive ? "Stop session" : (classStore.context == nil ? "Start class" : "Resume session")
    }
}

struct CompanionVolumeControl: WKInterfaceObjectRepresentable {
    let isFocused: Bool

    func makeWKInterfaceObject(context: Context) -> WKInterfaceVolumeControl {
        WKInterfaceVolumeControl(origin: .companion)
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
