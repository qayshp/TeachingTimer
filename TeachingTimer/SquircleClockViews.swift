import SwiftUI

enum SquircleClockTuning {
    /// Tunable approximation; public APIs don't expose physical display curvature.
    static func cornerRadius(for size: CGSize) -> CGFloat {
        TimerFaceLayout.cornerRadius(for: size)
    }
    static let edgeInset: CGFloat = 1.5
    static let tickInset: CGFloat = 3
    static let perimeterHandOvershoot: CGFloat = 2
}

struct SquircleIntersectionClockView: View {
    let date: Date
    let dimmed: Bool

    var body: some View {
        SquircleClockFace(date: date, dimmed: dimmed, handStyle: .perimeterIntersection)
    }
}

struct SquircleClippedClockView: View {
    let date: Date
    let dimmed: Bool

    var body: some View {
        SquircleClockFace(date: date, dimmed: dimmed, handStyle: .fixedAndClipped)
    }
}

private struct SquircleClockFace: View {
    enum HandStyle {
        case perimeterIntersection
        case fixedAndClipped
    }

    let date: Date
    let dimmed: Bool
    let handStyle: HandStyle

    private var second: Int {
        Calendar.current.component(.second, from: date)
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let boundary = RoundedRectangle(
                cornerRadius: SquircleClockTuning.cornerRadius(for: size),
                style: .continuous
            )

            ZStack {
                boundary
                    .inset(by: SquircleClockTuning.edgeInset)
                    .stroke(.white.opacity(dimmed ? 0.35 : 0.45), lineWidth: 0.75)

                ticks
                hand

                Circle()
                    .fill(dimmed ? .white : .yellow)
                    .frame(width: 9, height: 9)
            }
            .frame(width: size.width, height: size.height)
            .clipShape(boundary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Seconds hand")
        .accessibilityValue("\(second) seconds")
    }

    private var ticks: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            for index in 0..<60 {
                let direction = SquircleRayGeometry.direction(forSecond: index)
                let perimeter = SquircleRayGeometry.intersection(
                    size: size,
                    cornerRadius: SquircleClockTuning.cornerRadius(for: size),
                    edgeInset: SquircleClockTuning.edgeInset,
                    direction: direction
                )
                let length: CGFloat = index.isMultiple(of: 5) ? 10 : 5
                let outer = perimeter - direction * SquircleClockTuning.tickInset
                let inner = outer - direction * length
                var path = Path()
                path.move(to: center + inner)
                path.addLine(to: center + outer)
                context.stroke(
                    path,
                    with: .color(.white.opacity(index.isMultiple(of: 5) ? 0.92 : 0.48)),
                    style: StrokeStyle(
                        lineWidth: index.isMultiple(of: 5) ? 2.5 : 1.25,
                        lineCap: .round
                    )
                )
            }
        }
    }

    private var hand: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let direction = SquircleRayGeometry.direction(forSecond: second)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let length: CGFloat = switch handStyle {
            case .perimeterIntersection:
                SquircleRayGeometry.intersection(
                    size: size,
                    cornerRadius: SquircleClockTuning.cornerRadius(for: size),
                    edgeInset: SquircleClockTuning.edgeInset,
                    direction: direction
                ).magnitude + SquircleClockTuning.perimeterHandOvershoot
            case .fixedAndClipped:
                hypot(size.width, size.height) * 1.25
            }

            Canvas { context, _ in
                var path = Path()
                path.move(to: center)
                path.addLine(to: center + direction * length)
                context.stroke(
                    path,
                    with: .color(dimmed ? .white : .yellow),
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
            }
        }
    }
}

enum SquircleRayGeometry {
    /// Unit vector for clock orientation: 0 is up and 15 is right.
    static func direction(forSecond second: Int) -> CGVector {
        let radians = Double(second) * .pi / 30
        return CGVector(dx: sin(radians), dy: -cos(radians))
    }

    /// Intersects a center-originating ray with an inset rounded rectangle.
    /// Straight edges are tested first. Rays aimed into a corner use the outer
    /// root of the corresponding corner-circle quadratic.
    static func intersection(
        size: CGSize,
        cornerRadius requestedRadius: CGFloat,
        edgeInset: CGFloat,
        direction: CGVector
    ) -> CGVector {
        let halfWidth = max(0, size.width / 2 - edgeInset)
        let halfHeight = max(0, size.height / 2 - edgeInset)
        let radius = min(requestedRadius, halfWidth, halfHeight)
        let straightHalfWidth = halfWidth - radius
        let straightHalfHeight = halfHeight - radius
        let epsilon: CGFloat = 0.0001

        if abs(direction.dx) > epsilon {
            let distance = halfWidth / abs(direction.dx)
            let y = direction.dy * distance
            if abs(y) <= straightHalfHeight {
                return direction * distance
            }
        }

        if abs(direction.dy) > epsilon {
            let distance = halfHeight / abs(direction.dy)
            let x = direction.dx * distance
            if abs(x) <= straightHalfWidth {
                return direction * distance
            }
        }

        let cornerCenter = CGVector(
            dx: direction.dx.sign == .minus ? -straightHalfWidth : straightHalfWidth,
            dy: direction.dy.sign == .minus ? -straightHalfHeight : straightHalfHeight
        )
        let projection = direction.dot(cornerCenter)
        let discriminant = max(
            0,
            projection * projection - (cornerCenter.dot(cornerCenter) - radius * radius)
        )
        return direction * (projection + sqrt(discriminant))
    }
}

private extension CGVector {
    static func * (vector: CGVector, scalar: CGFloat) -> CGVector {
        CGVector(dx: vector.dx * scalar, dy: vector.dy * scalar)
    }

    static func - (lhs: CGVector, rhs: CGVector) -> CGVector {
        CGVector(dx: lhs.dx - rhs.dx, dy: lhs.dy - rhs.dy)
    }

    var magnitude: CGFloat {
        hypot(dx, dy)
    }

    func dot(_ other: CGVector) -> CGFloat {
        dx * other.dx + dy * other.dy
    }
}

private extension CGPoint {
    static func + (point: CGPoint, vector: CGVector) -> CGPoint {
        CGPoint(x: point.x + vector.dx, y: point.y + vector.dy)
    }
}
