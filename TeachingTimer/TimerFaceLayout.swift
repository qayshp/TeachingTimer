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
    // One rounded-rectangle family below the 44-point Class/header target.
    // The physical display curvature is not exposed by public APIs.
    var dialFrame: CGRect {
        CGRect(x: scale, y: 46 * scale,
               width: size.width - 2 * scale, height: size.height - 47 * scale)
    }
    var dialCenter: CGPoint { CGPoint(x: dialFrame.midX, y: dialFrame.midY) }
    var dialRadius: CGFloat { Self.cornerRadius(for: size) }
    var trackInset: CGFloat { 17 * scale }
    var trackFrame: CGRect { dialFrame.insetBy(dx: trackInset, dy: trackInset) }
    var trackRadius: CGFloat { max(0, dialRadius - trackInset) }
    var controlsWidth: CGFloat { trackFrame.width - 20 * scale }
    var actionHeight: CGFloat { 44 * scale }
    var actionY: CGFloat { trackFrame.maxY - 5 * scale - actionHeight / 2 }
    var optionsWidth: CGFloat { 44 * scale }
    var countWidth: CGFloat { controlsWidth - optionsWidth - 4 }
    var volumeSize: CGSize { CGSize(width: 64 * scale, height: 28) }
    var volumeBackingSide: CGFloat { 38 }
    var volumeCenter: CGPoint { CGPoint(x: dialCenter.x, y: trackFrame.minY + 25 * scale) }
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
        dialPoint(angle: angle, inset: trackInset)
    }
    func dialPoint(angle: Double, inset: CGFloat) -> CGPoint {
        let vector = SquircleRayGeometry.intersection(size: dialFrame.size,
            cornerRadius: max(0, dialRadius - inset), edgeInset: inset,
            direction: CGVector(dx: sin(angle), dy: -cos(angle)))
        return CGPoint(x: dialCenter.x + vector.dx, y: dialCenter.y + vector.dy)
    }
    static func cornerRadius(for size: CGSize) -> CGFloat {
        // Approximation: public APIs do not expose physical display curvature.
        38 * min(1.3, max(0.9, min(size.width / 162, size.height / 197)))
    }
}
