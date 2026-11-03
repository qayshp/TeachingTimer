// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

@main struct TimerFaceLayoutChecks {
    static func roundedDistance(_ point: CGPoint, rect: CGRect, radius: CGFloat) -> CGFloat {
        let x = abs(point.x - rect.midX) - (rect.width / 2 - radius)
        let y = abs(point.y - rect.midY) - (rect.height / 2 - radius)
        return hypot(max(x, 0), max(y, 0)) + min(max(x, y), 0) - radius
    }
    static func main() {
        let sizes: [CGSize] = [CGSize(width: 162, height: 197), CGSize(width: 176, height: 215),
            CGSize(width: 184, height: 224), CGSize(width: 187, height: 223),
            CGSize(width: 198, height: 242), CGSize(width: 208, height: 248),
            CGSize(width: 205, height: 251), CGSize(width: 211, height: 257)]
        for size in sizes {
            let layout = TimerFaceLayout(size: size)
            assert(layout.dialFrame.minY > 45)
            assert(abs(layout.trackFrame.midX - layout.dialCenter.x) < 0.0001)
            assert(abs(layout.trackFrame.midY - layout.dialCenter.y) < 0.0001)
            assert(layout.trackRadius == layout.dialRadius - layout.trackInset)
            assert(layout.countWidth >= 44 && layout.optionsWidth >= 44 && layout.actionHeight >= 44)
            assert(layout.volumeRefreshFrame.width >= 44 && layout.volumeRefreshFrame.height >= 44)
            assert(layout.volumeRefreshFrame.minY >= 45) // Clear of Class button.
            assert(layout.volumeRefreshFrame.maxY + 4 < layout.actionFrame.minY)
            assert(layout.volumeFrame.maxY < layout.actionFrame.minY)
            for index in 0..<720 {
                let point = layout.landmarkPoint(angle: Double(index) * .pi / 360)
                // Include the full start dot, not just the arc centerline.
                // Test painted shapes rather than bounding-box corners: the
                // action is rounded and native volume has a circular backing.
                for (control, radius) in [(layout.actionFrame, CGFloat(12)),
                                           (layout.volumeFrame, CGFloat(19))] {
                    let distance = roundedDistance(point, rect: control, radius: radius)
                    assert(distance > 4, "Count dot/stroke touches control: \(size), \(index), \(distance)")
                }
                assert(point.y - 3 >= 36 * layout.scale, "Count enters system clock area")
            }
        }
        print("PASS: 8 sizes, aligned inset contours, clear header, 44pt targets, 5760 count dots clear of painted controls")
    }
}
