import Foundation
import CoreGraphics

/// Pure geometry shared by tick marks, hands, markers, and progress paths.
enum SquircleRayGeometry {
    /// Unit vector for clock orientation: 0 is up and 15 is right.
    static func direction(forSecond second: Int) -> CGVector {
        let radians = Double(second) * .pi / 30
        return CGVector(dx: sin(radians), dy: -cos(radians))
    }

    /// Intersects a center-originating unit ray with an inset rounded rectangle.
    /// Straight edges are tested first, then the outer corner-circle root.
    static func intersection(size: CGSize, cornerRadius requestedRadius: CGFloat,
                             edgeInset: CGFloat, direction: CGVector) -> CGVector {
        let halfWidth = max(0, size.width / 2 - edgeInset)
        let halfHeight = max(0, size.height / 2 - edgeInset)
        let radius = min(requestedRadius, halfWidth, halfHeight)
        let straightHalfWidth = halfWidth - radius
        let straightHalfHeight = halfHeight - radius
        let epsilon: CGFloat = 0.0001
        func scaled(_ distance: CGFloat) -> CGVector {
            CGVector(dx: direction.dx * distance, dy: direction.dy * distance)
        }
        if abs(direction.dx) > epsilon {
            let distance = halfWidth / abs(direction.dx)
            if abs(direction.dy * distance) <= straightHalfHeight { return scaled(distance) }
        }
        if abs(direction.dy) > epsilon {
            let distance = halfHeight / abs(direction.dy)
            if abs(direction.dx * distance) <= straightHalfWidth { return scaled(distance) }
        }
        let cornerCenter = CGVector(
            dx: direction.dx.sign == .minus ? -straightHalfWidth : straightHalfWidth,
            dy: direction.dy.sign == .minus ? -straightHalfHeight : straightHalfHeight)
        let projection = direction.dx * cornerCenter.dx + direction.dy * cornerCenter.dy
        let squaredDistance = cornerCenter.dx * cornerCenter.dx + cornerCenter.dy * cornerCenter.dy
        let discriminant = max(0, projection * projection - (squaredDistance - radius * radius))
        return scaled(projection + sqrt(discriminant))
    }
}
