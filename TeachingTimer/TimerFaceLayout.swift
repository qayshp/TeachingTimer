// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import CoreGraphics

/// A clear count track surrounds the controls below the system clock.
struct TimerFaceLayout {
    let size: CGSize
    var scale: CGFloat { min(1.25, max(1, min(size.width / 162, size.height / 197))) }
    // Full-screen outer contour. Only the inner track needs top-label clearance.
    var dialFrame: CGRect { CGRect(origin: .zero, size: size) }
    var dialCenter: CGPoint { CGPoint(x: dialFrame.midX, y: dialFrame.midY) }
    var dialRadius: CGFloat { Self.cornerRadius(for: size) }
    var cornerPower: Double { Self.cornerProfile(for: size).power }
    var trackInset: CGFloat { 17 * scale }
    var trackFrame: CGRect {
        let inset = dialFrame.insetBy(dx: trackInset, dy: trackInset)
        let top = max(inset.minY, 40 * scale)
        return CGRect(x: inset.minX, y: top, width: inset.width, height: inset.maxY - top)
    }
    var trackRadius: CGFloat { max(0, dialRadius - trackInset) }
    var classControlCenter: CGPoint {
        // Keep the capsule just inside the curved edge on larger displays too.
        let r = Double(dialRadius), y = min(r, 23.0)
        let edge = r - pow(max(0, pow(r, cornerPower) - pow(r - y, cornerPower)), 1 / cornerPower)
        return CGPoint(x: max(38, CGFloat(edge) + 35), y: 23)
    }
    // Approximate system-overlay footprint; watchOS owns the actual clock view.
    var systemTimeTickRegion: CGRect {
        CGRect(x: size.width - 70 * scale, y: 5 * scale, width: 69 * scale, height: 27 * scale)
    }
    var controlsWidth: CGFloat { trackFrame.width - 22 * scale }
    var actionHeight: CGFloat { 44 * scale }
    var actionY: CGFloat { trackFrame.maxY - 8 * scale - actionHeight / 2 }
    var optionsWidth: CGFloat { 44 * scale }
    var countWidth: CGFloat { controlsWidth - optionsWidth - 4 }
    var volumeSize: CGSize { CGSize(width: 64 * scale, height: 28) }
    var volumeBackingSide: CGFloat { 38 }
    var volumeCenter: CGPoint { CGPoint(x: dialCenter.x, y: trackFrame.minY + 27 * scale) }
    var volumeRefreshFrame: CGRect {
        CGRect(x: volumeCenter.x - volumeSize.width / 2,
               y: volumeCenter.y - 22 * scale,
               width: volumeSize.width, height: 44 * scale)
    }
    var actionFrame: CGRect {
        CGRect(x: dialCenter.x - controlsWidth / 2, y: actionY - actionHeight / 2,
               width: controlsWidth, height: actionHeight)
    }
    var volumeFrame: CGRect {
        CGRect(x: volumeCenter.x - 19, y: volumeCenter.y - 19, width: 38, height: 38)
    }
    func landmarkPoint(angle: Double) -> CGPoint {
        let vector = SquircleRayGeometry.intersection(size: trackFrame.size,
            cornerRadius: trackRadius, edgeInset: 0,
            direction: CGVector(dx: sin(angle), dy: -cos(angle)), cornerPower: cornerPower)
        return CGPoint(x: trackFrame.midX + vector.dx, y: trackFrame.midY + vector.dy)
    }
    func dialPoint(angle: Double, inset: CGFloat) -> CGPoint {
        let vector = SquircleRayGeometry.intersection(size: dialFrame.size,
            cornerRadius: max(0, dialRadius - inset), edgeInset: inset,
            direction: CGVector(dx: sin(angle), dy: -cos(angle)), cornerPower: cornerPower)
        return CGPoint(x: dialCenter.x + vector.dx, y: dialCenter.y + vector.dy)
    }
    /// Every tick retains its full length; header legibility is a drawing concern.
    func tickSegment(second: Int, outerInset: CGFloat, length: CGFloat) -> (outer: CGPoint, inner: CGPoint) {
        let angle = Double(second) * .pi / 30
        let direction = CGVector(dx: sin(angle), dy: -cos(angle))
        let edge = dialPoint(angle: angle, inset: outerInset)
        return (edge, CGPoint(x: edge.x - direction.dx * length, y: edge.y - direction.dy * length))
    }
    static func cornerRadius(for size: CGSize) -> CGFloat { cornerProfile(for: size).radius }
    static func cornerProfile(for size: CGSize) -> (radius: CGFloat, power: Double) {
        // Tunable approximations fitted to current Simulator masks, not a public
        // physical-display API. Geometry is keyed by point size, not model name.
        switch (Int(size.width.rounded()), Int(size.height.rounded())) {
        case (162, 197): (35, 2.6)
        case (184, 224): (44, 2.75)
        case (187, 223): (53, 2.45)
        case (208, 248): (59.5, 2.4)
        case (211, 257): (78, 2.9)
        default: (35 * min(1.3, max(0.9, min(size.width / 162, size.height / 197))), 2.6)
        }
    }
}
