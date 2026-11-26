// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import CoreGraphics

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
            let nativeVolumeFrame = CGRect(x: layout.volumeCenter.x - layout.volumeSize.width / 2,
                                           y: layout.volumeCenter.y - layout.volumeSize.height / 2,
                                           width: layout.volumeSize.width, height: layout.volumeSize.height)
            let volumeShapes = [CGPath(rect: nativeVolumeFrame, transform: nil),
                                CGPath(ellipseIn: layout.volumeFrame, transform: nil)]
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
                // Protect both the wider native frame and its circular backing.
                for (control, radius) in [(layout.actionFrame, CGFloat(12)),
                                           (layout.volumeFrame, CGFloat(19)),
                                           (nativeVolumeFrame, CGFloat(0))] {
                    let distance = roundedDistance(point, rect: control, radius: radius)
                    assert(distance > 4, "Count dot/stroke touches control: \(size), \(index), \(distance)")
                }
                assert(point.y - 3 >= 36 * layout.scale, "Count enters system clock area")
            }
            // ClockAdditions now draws above native volume. Its full progress
            // perimeter and both filled end-marker sizes must remain separate.
            let perimeter = CGMutablePath()
            for degree in 0...360 {
                // Match ClockAdditions.perimeterPath: edgeInset is 2 points.
                let point = layout.dialPoint(angle: Double(degree) * .pi / 180, inset: 2)
                if degree == 0 { perimeter.move(to: point) }
                else { perimeter.addLine(to: point) }
            }
            let progressStroke = perimeter.copy(strokingWithWidth: 2.5,
                lineCap: .butt, lineJoin: .miter, miterLimit: 10)
            for volumeShape in volumeShapes {
                assert(!progressStroke.intersects(volumeShape), "Class progress touches volume: \(size)")
            }
            for minute in 0..<60 {
                let angle = Double(minute) * .pi / 30
                let direction = SquircleRayGeometry.direction(forSecond: minute)
                let outer = layout.dialPoint(angle: angle, inset: 4)
                for (depth, halfWidth): (CGFloat, CGFloat) in [(14, 4), (17, 5)] {
                    let marker = CGMutablePath()
                    marker.move(to: CGPoint(x: outer.x - direction.dy * halfWidth,
                                            y: outer.y + direction.dx * halfWidth))
                    marker.addLine(to: CGPoint(x: outer.x + direction.dy * halfWidth,
                                               y: outer.y - direction.dx * halfWidth))
                    marker.addLine(to: CGPoint(x: outer.x - direction.dx * depth,
                                               y: outer.y - direction.dy * depth))
                    marker.closeSubpath()
                    for volumeShape in volumeShapes {
                        assert(!marker.intersects(volumeShape), "Class end marker touches volume: \(size), \(minute), \(depth)")
                    }
                }
            }
        }
        // Independent pixel bounds shared by the outline-regression fixtures.
        // A layout change must prompt recalibration instead of leaving the
        // measurement helper silently sampling outside the real button.
        let calibrated: [(CGSize, CGRect)] = [
            (CGSize(width: 162, height: 197), CGRect(x: 56, y: 256, width: 212, height: 88)),
            (CGSize(width: 211, height: 257), CGRect(x: 70, y: 341.5, width: 282, height: 110))
        ]
        for (size, expected) in calibrated {
            let frame = TimerFaceLayout(size: size).actionFrame
            let pixels = CGRect(x: frame.minX * 2, y: frame.minY * 2,
                                width: frame.width * 2, height: frame.height * 2)
            assert(pixels == expected, "Recalibrate ControlOutline and its fixtures after count-frame changes")
        }
        print("PASS: 8 full-screen dials, all 480 ticks retain full length, time-overlay regions, 44pt targets, 5760 count dots, 8 progress strokes and 960 end markers clear native volume and backing, SE/Ultra outline calibration bounds")
    }
}
