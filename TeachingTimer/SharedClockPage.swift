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

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                clockFace
                ClockAdditions(date: date, face: face, context: classStore.context,
                               showsClassProgress: showsClassProgress)
                    .allowsHitTesting(false)
                controls
                    .offset(y: 24)
                CompanionVolumeControl(isFocused: crownIsActive && !confirmReset)
                    .frame(width: 64, height: 28)
                    .offset(y: -48)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .containerBackground(.black, for: .tabView)
        .alert("Reset for a new class?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) {
                session.stop()
                metronome.cancel()
                classStore.reset()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Clears the class end marker and stops runtime and metronome.")
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
    private var controls: some View {
        VStack(spacing: 3) {
            Button {
                if metronome.isActive { metronome.cancel() } else { metronome.start() }
            } label: {
                Label(metronome.isActive ? "Stop beats" : "Metronome",
                      systemImage: metronome.isActive ? "stop.fill" : "metronome")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 128, height: 52)
                    .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white, lineWidth: metronome.isActive ? 3 : 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("metronome-toggle")
            HStack(spacing: 4) {
                Button {
                    if session.isActive { session.stop() }
                    else { classStore.establishIfNeeded(); session.start() }
                } label: {
                    Text(session.isActive ? "Stop runtime" : (classStore.context == nil ? "Start class" : "Restart runtime"))
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 98, height: 36)
                        .background(.black.opacity(0.35), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(session.phase == .starting)
                .accessibilityIdentifier("runtime-toggle")
                Button { confirmReset = true } label: {
                    Image(systemName: "ellipsis").frame(width: 30, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New class or reset")
            }
            if session.needsRestart {
                Text("Runtime ended · tap Restart").font(.system(size: 9)).foregroundStyle(.white)
            } else if session.phase == .starting {
                Text("Starting runtime…").font(.system(size: 9))
            } else if session.phase == .expiring {
                Text("Runtime expiring").font(.system(size: 9))
            }
        }
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
