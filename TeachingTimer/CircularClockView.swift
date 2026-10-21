import SwiftUI

/// The existing oversized circular clock face, retained as the control variant.
struct CircularClockView: View {
    let date: Date
    let dimmed: Bool
    var layer: ClockFaceLayer = .complete

    private var second: Int {
        Calendar.current.component(.second, from: date)
    }

    var body: some View {
        GeometryReader { geometry in
            // Unlike the two edge-to-edge squircle experiments, the circular
            // control stays fully inside the Watch display.
            let side = min(geometry.size.width, geometry.size.height) * 0.94

            ZStack {
                if layer != .secondsHand {
                    Circle()
                        .stroke(.white.opacity(dimmed ? 0.42 : 0.72), lineWidth: 1.5)

                    ForEach(0..<60, id: \.self) { index in
                        Capsule()
                            .fill(.white.opacity(index % 5 == 0 ? 0.92 : 0.48))
                            .frame(
                                width: index % 5 == 0 ? 2.5 : 1.25,
                                height: index % 5 == 0 ? 10 : 5
                            )
                            .offset(y: -(side / 2) + 7)
                            .rotationEffect(.degrees(Double(index) * 6))
                    }
                }
                if layer != .dial {
                    Capsule()
                        .fill(dimmed ? .white : .yellow)
                        .frame(width: 3.5, height: side * 0.45)
                        .offset(y: -side * 0.205)
                        .rotationEffect(.degrees(Double(second) * 6))

                    Circle()
                        .fill(dimmed ? .white : .yellow)
                        .frame(width: 9, height: 9)
                }
            }
            .frame(width: side, height: side)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Seconds hand")
        .accessibilityValue("\(second) seconds")
        .accessibilityHidden(layer == .dial)
    }
}
