import Foundation
import CoreGraphics

/// Measurements use available points, not model names or pixel resolutions.
struct TimerFaceLayout {
    let size: CGSize
    var scale: CGFloat { min(1.25, max(1, size.width / 162)) }
    var controlsWidth: CGFloat { min(size.width - 24, 136 * scale) }
    var countHeight: CGFloat { 52 * scale }
    var runtimeHeight: CGFloat { 44 * scale }
    var resetSide: CGFloat { runtimeHeight }
    var resetSymbolSize: CGFloat { 20 * scale }
    var spacing: CGFloat { 4 * scale }
    var statusHeight: CGFloat { 28 * scale }
    var statusHorizontalPadding: CGFloat { 6 * scale }
    var controlsHeight: CGFloat { countHeight + runtimeHeight + statusHeight + 2 * spacing }
    var controlsCenter: CGPoint {
        CGPoint(x: size.width / 2, y: size.height - 14 * scale - controlsHeight / 2)
    }
    var volumeSize: CGSize { CGSize(width: 64 * scale, height: 28) }
    // Match the native control's fixed height; don't expand into nearby controls.
    var volumeBackingSide: CGFloat { 38 }
    /// Tunable quiet zone for the system time/status icons, not a measured
    /// system-clock frame. Only the inner count arc is clipped here.
    var systemClockExclusion: CGRect {
        CGRect(x: size.width * 0.48, y: 0,
               width: size.width * 0.52, height: 36 * scale)
    }
    var volumeCenter: CGPoint {
        CGPoint(x: size.width / 2,
                y: max(32, controlsCenter.y - controlsHeight / 2 - 6 - volumeSize.height / 2))
    }
    static func cornerRadius(for size: CGSize) -> CGFloat {
        // A tunable approximation, not a claim about physical display curvature.
        38 * min(1.3, max(0.9, min(size.width / 162, size.height / 197)))
    }
}
