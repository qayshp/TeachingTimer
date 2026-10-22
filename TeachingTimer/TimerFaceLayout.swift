import Foundation
import CoreGraphics

/// A clear count track surrounds the controls below the system clock.
struct TimerFaceLayout {
    let size: CGSize
    var scale: CGFloat { min(1.25, max(1, size.width / 162)) }
    var trackFrame: CGRect {
        CGRect(x: 16, y: 40 * scale, width: size.width - 32, height: size.height - 54 * scale)
    }
    var trackRadius: CGFloat { 22 * scale }
    var controlsWidth: CGFloat { size.width - 56 }
    var actionHeight: CGFloat { 44 * scale }
    var actionY: CGFloat { size.height - 47 * scale }
    var optionsWidth: CGFloat { 44 * scale }
    var countWidth: CGFloat { controlsWidth - optionsWidth - 4 }
    var volumeSize: CGSize { CGSize(width: 64 * scale, height: 28) }
    var volumeBackingSide: CGFloat { 38 }
    var volumeCenter: CGPoint { CGPoint(x: size.width / 2, y: 63 * scale) }
    var statusCenter: CGPoint { CGPoint(x: size.width / 2, y: actionY - actionHeight / 2 - 12) }
    var actionFrame: CGRect {
        CGRect(x: 28, y: actionY - actionHeight / 2, width: controlsWidth, height: actionHeight)
    }
    var volumeFrame: CGRect {
        CGRect(x: volumeCenter.x - 19, y: volumeCenter.y - 19, width: 38, height: 38)
    }
    var statusFrame: CGRect {
        CGRect(x: 28, y: statusCenter.y - 9, width: controlsWidth, height: 18)
    }
    func landmarkPoint(angle: Double) -> CGPoint {
        let vector = SquircleRayGeometry.intersection(size: trackFrame.size,
            cornerRadius: trackRadius, edgeInset: 0,
            direction: CGVector(dx: sin(angle), dy: -cos(angle)))
        return CGPoint(x: trackFrame.midX + vector.dx, y: trackFrame.midY + vector.dy)
    }
    static func cornerRadius(for size: CGSize) -> CGFloat {
        // Approximation: public APIs do not expose physical display curvature.
        38 * min(1.3, max(0.9, min(size.width / 162, size.height / 197)))
    }
}
