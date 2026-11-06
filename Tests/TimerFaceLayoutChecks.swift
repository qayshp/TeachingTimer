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
            assert(layout.dialFrame == CGRect(origin: .zero, size: size))
            assert(abs(layout.trackFrame.midX - layout.dialCenter.x) < 0.0001)
            assert(layout.trackFrame.midY > layout.dialCenter.y) // Local top clearance only.
            assert(layout.trackRadius == layout.dialRadius - layout.trackInset)
            assert(layout.countWidth >= 44 && layout.optionsWidth >= 44 && layout.actionHeight >= 44)
            assert(layout.volumeRefreshFrame.width >= 44 && layout.volumeRefreshFrame.height >= 44)
            let settingsTarget = CGRect(x: layout.classControlCenter.x - 22,
                                        y: layout.classControlCenter.y - 22, width: 44, height: 44)
            assert(layout.dialFrame.contains(settingsTarget))
            assert(!settingsTarget.intersects(layout.volumeRefreshFrame))
            assert(!settingsTarget.intersects(layout.systemTimeTickRegion))
            assert(layout.volumeRefreshFrame.minY >= 45) // Clear of settings button.
            assert(layout.volumeRefreshFrame.maxY + 4 < layout.actionFrame.minY)
            assert(layout.volumeFrame.maxY < layout.actionFrame.minY)
            var ticksUnderTime = 0
            for second in 0..<60 {
                let major = second.isMultiple(of: 5)
                let length: CGFloat = major ? 10 : 5
                let tick = layout.tickSegment(second: second, outerInset: 5, length: length)
                assert(abs(hypot(tick.inner.x - tick.outer.x, tick.inner.y - tick.outer.y) - length) < 0.0001,
                       "Header must not shorten or remove ticks")
                var crossesTime = false
                for sample in 0...20 {
                    let t = CGFloat(sample) / 20
                    let point = CGPoint(x: tick.outer.x + (tick.inner.x - tick.outer.x) * t,
                                        y: tick.outer.y + (tick.inner.y - tick.outer.y) * t)
                    crossesTime = crossesTime || layout.systemTimeTickRegion.contains(point)
                }
                if crossesTime { ticksUnderTime += 1 }
            }
            assert(ticksUnderTime > 0 && ticksUnderTime < 60)
            assert(layout.dialFrame.contains(layout.systemTimeTickRegion))
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
        print("PASS: 8 full-screen dials, all 480 ticks retain full length, time-overlay regions, 44pt targets, 5760 count dots clear of controls")
    }
}
