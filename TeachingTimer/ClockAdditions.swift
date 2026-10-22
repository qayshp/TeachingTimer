import SwiftUI

/// Shared scheduled-end marker and progress arcs, sampled by the parent timeline.
struct ClockAdditions: View {
    let date: Date
    let face: ClockFaceKind
    let context: ClassContext?
    var showsClassProgress = false
    var landmarkStartAngle: Double?
    var landmarkProgress: Double = 0

    var body: some View {
        Canvas { graphics, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            if let start = landmarkStartAngle {
                // Clip only this visual layer. The monotonic progress and start
                // angle remain unchanged as the arc passes behind system time.
                var landmarkGraphics = graphics
                var visibleArea = Path(CGRect(origin: .zero, size: size))
                visibleArea.addRect(TimerFaceLayout(size: size).systemClockExclusion)
                landmarkGraphics.clip(to: visibleArea, style: FillStyle(eoFill: true))
                // An inset, dashed squircle is distinct from the solid outer
                // class perimeter even when all colors become monochrome.
                let inset: CGFloat = 23
                let end = start + min(1, max(0, landmarkProgress)) * 2 * .pi
                landmarkGraphics.stroke(perimeterPath(from: start, to: end, size: size, inset: inset),
                    with: .color(.white),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [4, 3]))
                let direction = CGVector(dx: sin(start), dy: -cos(start))
                let vector = SquircleRayGeometry.intersection(size: size,
                    cornerRadius: max(0, SquircleClockTuning.cornerRadius(for: size) - inset),
                    edgeInset: SquircleClockTuning.edgeInset + inset, direction: direction)
                let point = CGPoint(x: center.x + vector.dx, y: center.y + vector.dy)
                landmarkGraphics.fill(Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)),
                              with: .color(.white))
            }
            if showsClassProgress, let context, context.durationMinutes == 60 {
                // Sample at the hands' whole-second cadence; clamp at either end
                // so an overdue class never wraps into another full hour.
                let sampledDate = Date(timeIntervalSince1970: floor(date.timeIntervalSince1970))
                let progress = min(1, max(0, context.progress(at: sampledDate)))
                let startMinute = Calendar.current.component(.minute, from: context.scheduledStart)
                let startAngle = Double(startMinute) * .pi / 30
                let boundaryAngle = startAngle + progress * 2 * .pi
                let endAngle = startAngle + 2 * .pi
                graphics.stroke(perimeterPath(from: startAngle, to: boundaryAngle, size: size),
                    with: .color(.white.opacity(0.45)),
                    style: StrokeStyle(lineWidth: 0.75, lineCap: .butt, dash: [1, 3]))
                graphics.stroke(perimeterPath(from: boundaryAngle, to: endAngle, size: size),
                    with: .color(.white),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .butt))
            }
            if let context {
                let minute = Calendar.current.component(.minute, from: context.scheduledEnd)
                let direction = SquircleRayGeometry.direction(forSecond: minute)
                let perimeter: CGVector
                if face == .circular {
                    let radius = min(size.width, size.height) * 0.94 / 2
                    perimeter = CGVector(dx: direction.dx * radius, dy: direction.dy * radius)
                } else {
                    perimeter = SquircleRayGeometry.intersection(size: size,
                        cornerRadius: SquircleClockTuning.cornerRadius(for: size),
                        edgeInset: SquircleClockTuning.edgeInset, direction: direction)
                }
                let prominent = context.progress(at: date) >= 0.5
                // Solid geometry carries the emphasis even in monochrome Always-On.
                // Initial area is 56 pt², about twice a 10 × 2.5 pt major tick.
                // After the scheduled midpoint, area increases moderately to 76.5 pt².
                let depth: CGFloat = prominent ? 17 : 14
                let halfWidth: CGFloat = prominent ? 4.5 : 4
                let outer = CGPoint(x: center.x + perimeter.dx - direction.dx * 2,
                                    y: center.y + perimeter.dy - direction.dy * 2)
                var marker = Path()
                marker.move(to: CGPoint(x: outer.x - direction.dy * halfWidth, y: outer.y + direction.dx * halfWidth))
                marker.addLine(to: CGPoint(x: outer.x + direction.dy * halfWidth, y: outer.y - direction.dx * halfWidth))
                marker.addLine(to: CGPoint(x: outer.x - direction.dx * depth, y: outer.y - direction.dy * depth))
                marker.closeSubpath()
                graphics.fill(marker, with: .color(.white))
            }
        }
        .accessibilityLabel("Clock and class end")
        .accessibilityValue(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        let time = date.formatted(date: .omitted, time: .shortened)
        guard let context else { return "Current time \(time). No class started." }
        let end = context.scheduledEnd.formatted(date: .omitted, time: .shortened)
        return "Current time \(time). Class ends at \(end)."
    }

    /// Uses the same ray/perimeter geometry as the ticks and end marker.
    /// One-degree subdivisions follow the rounded corners without a new animation.
    private func perimeterPath(from start: Double, to end: Double, size: CGSize, inset: CGFloat = 3) -> Path {
        var path = Path()
        guard end > start else { return path }
        let steps = max(1, Int(ceil((end - start) * 180 / .pi)))
        for index in 0...steps {
            let angle = start + (end - start) * Double(index) / Double(steps)
            let direction = CGVector(dx: sin(angle), dy: -cos(angle))
            let vector = SquircleRayGeometry.intersection(size: size,
                cornerRadius: inset == 3 ? SquircleClockTuning.cornerRadius(for: size) : max(0, SquircleClockTuning.cornerRadius(for: size) - inset),
                edgeInset: SquircleClockTuning.edgeInset + inset, direction: direction)
            let point = CGPoint(x: size.width / 2 + vector.dx, y: size.height / 2 + vector.dy)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

/// Same wall-clock geometry and cadence as before, in a separate foreground
/// layer so controls cannot hide it. The seconds hand is drawn above this view.
struct WallClockMinuteHand: View {
    let date: Date

    var body: some View {
        Canvas { graphics, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let components = Calendar.current.dateComponents([.minute, .second], from: date)
            let minute = Double(components.minute ?? 0) + Double(components.second ?? 0) / 60
            let angle = minute * .pi / 30
            let length = min(size.width, size.height) * 0.29
            var hand = Path()
            hand.move(to: center)
            hand.addLine(to: CGPoint(x: center.x + sin(angle) * length, y: center.y - cos(angle) * length))
            graphics.stroke(hand, with: .color(.white), style: StrokeStyle(lineWidth: 6, lineCap: .square))
        }
        // ClockAdditions already supplies the wall time and class-end summary.
        .accessibilityHidden(true)
    }
}
