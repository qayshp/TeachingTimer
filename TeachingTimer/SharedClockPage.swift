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
    let crownIsActive: Bool

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                clockFace

                VStack(spacing: 5) {
                    Text(elapsedText)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(isLuminanceReduced ? .white : .yellow)

                    controls
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    .black.opacity(isLuminanceReduced ? 0.68 : 0.52),
                    in: Capsule()
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .containerBackground(.black, for: .tabView)
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
        HStack(spacing: 8) {
            CompanionVolumeControl(isFocused: crownIsActive)
                .frame(width: 64, height: 18)

            if session.isActive {
                Button {
                    session.stop()
                } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .accessibilityLabel("Stop session")
            } else {
                Button("Start") {
                    session.start()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.yellow, in: Capsule())
                .accessibilityIdentifier("start-session")
            }
        }

        if case let .ended(message) = session.phase {
            Text(message)
                .font(.system(size: 8))
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
    }

    private var elapsedText: String {
        guard let start = session.startedAt else {
            return session.phase == .starting ? "Starting…" : "00:00"
        }

        let totalSeconds = max(0, Int(date.timeIntervalSince(start)))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
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
