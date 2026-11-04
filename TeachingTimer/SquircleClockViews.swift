// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

enum SquircleClockTuning {
    static let edgeInset: CGFloat = 2
    static let tickInset: CGFloat = 3
    static let perimeterHandOvershoot: CGFloat = 2
    // Quarter-strength ticks under the clock and through the Class backing.
    static let obscuredTickOpacity: Double = 0.25
}

struct SquircleIntersectionClockView: View {
    let date: Date
    let dimmed: Bool
    var layer: ClockFaceLayer = .complete

    private var second: Int { WallClockDisplay.components(at: date).second ?? 0 }

    var body: some View {
        GeometryReader { geometry in
            let layout = TimerFaceLayout(size: geometry.size)
            let boundary = outline(layout: layout, inset: 0)
            ZStack {
                if layer != .secondsHand {
                    outline(layout: layout, inset: SquircleClockTuning.edgeInset)
                        .stroke(.white.opacity(dimmed ? 0.35 : 0.45), lineWidth: 0.75)
                    Canvas { graphics, _ in
                        for index in 0..<60 {
                            let major = index.isMultiple(of: 5)
                            let width: CGFloat = major ? 2.5 : 1.25
                            let tick = layout.tickSegment(second: index,
                                outerInset: SquircleClockTuning.edgeInset + SquircleClockTuning.tickInset,
                                length: major ? 10 : 5)
                            var path = Path(); path.move(to: tick.outer); path.addLine(to: tick.inner)
                            graphics.stroke(path, with: .color(.white.opacity(major ? 0.92 : 0.48)),
                                style: StrokeStyle(lineWidth: width, lineCap: .round))
                        }
                    }
                    .mask {
                        Canvas { mask, size in
                            mask.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
                            mask.blendMode = .destinationOut
                            mask.fill(Path(layout.systemTimeTickRegion),
                                with: .color(.white.opacity(1 - SquircleClockTuning.obscuredTickOpacity)))
                        }
                    }
                }
                if layer != .dial {
                    Canvas { graphics, _ in
                        let angle = Double(second) * .pi / 30
                        let point = layout.dialPoint(angle: angle, inset: SquircleClockTuning.edgeInset)
                        let tip = CGPoint(x: point.x + sin(angle) * SquircleClockTuning.perimeterHandOvershoot,
                                          y: point.y - cos(angle) * SquircleClockTuning.perimeterHandOvershoot)
                        var path = Path(); path.move(to: layout.dialCenter); path.addLine(to: tip)
                        graphics.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
                        graphics.stroke(path, with: .color(dimmed ? .white : .yellow),
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    }
                    Circle().fill(dimmed ? .white : .yellow).frame(width: 9, height: 9)
                        .position(layout.dialCenter)
                }
            }
            .clipShape(boundary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Seconds hand")
        .accessibilityValue("\(second) seconds")
        .accessibilityHidden(layer == .dial)
    }

    private func outline(layout: TimerFaceLayout, inset: CGFloat) -> Path {
        var path = Path()
        for step in 0...360 {
            let point = layout.dialPoint(angle: Double(step) * .pi / 180, inset: inset)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}
