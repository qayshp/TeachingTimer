import Foundation
import CoreGraphics

@main
struct ClockGeometryChecks {
    static func main() {
        let sizes: [CGSize] = [
            .init(width: 162, height: 197), .init(width: 176, height: 215),
            .init(width: 184, height: 224), .init(width: 187, height: 223),
            .init(width: 198, height: 242), .init(width: 208, height: 248),
            .init(width: 205, height: 251), .init(width: 211, height: 257),
        ]
        for size in sizes {
            for inset: CGFloat in [1.5, 4.5, 24.5] {
                let radius = max(0, TimerFaceLayout.cornerRadius(for: size) - (inset == 24.5 ? 23 : 0))
                let halfWidth = size.width / 2 - inset
                let halfHeight = size.height / 2 - inset
                let clippedRadius = min(radius, halfWidth, halfHeight)
                // Half-degree steps include every tick and the rounded corners.
                for step in 0..<720 {
                    let angle = Double(step) * .pi / 360
                    let direction = CGVector(dx: sin(angle), dy: -cos(angle))
                    let point = SquircleRayGeometry.intersection(size: size,
                        cornerRadius: radius, edgeInset: inset, direction: direction)
                    assert(point.dx.isFinite && point.dy.isFinite)
                    assert(abs(point.dx) <= halfWidth + 0.0001)
                    assert(abs(point.dy) <= halfHeight + 0.0001)
                    assert(abs(point.dx * direction.dy - point.dy * direction.dx) < 0.0001)
                    assert(point.dx * direction.dx + point.dy * direction.dy > 0)
                    let x = abs(point.dx), y = abs(point.dy)
                    if x > halfWidth - clippedRadius && y > halfHeight - clippedRadius {
                        let dx = x - (halfWidth - clippedRadius)
                        let dy = y - (halfHeight - clippedRadius)
                        assert(abs(dx * dx + dy * dy - clippedRadius * clippedRadius) < 0.001)
                    } else {
                        assert(abs(x - halfWidth) < 0.0001 || abs(y - halfHeight) < 0.0001)
                    }
                }
            }
            let up = SquircleRayGeometry.intersection(size: size, cornerRadius: 38,
                edgeInset: 1.5, direction: SquircleRayGeometry.direction(forSecond: 0))
            assert(abs(up.dx) < 0.0001 && abs(up.dy + size.height / 2 - 1.5) < 0.0001)
        }
        print("PASS: 17280 ray intersections, 8 Watch sizes, 3 insets, bounds, corners and radial alignment")
    }
}
