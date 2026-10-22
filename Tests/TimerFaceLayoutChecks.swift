import Foundation

@main struct TimerFaceLayoutChecks {
    static func main() {
        let sizes: [CGSize] = [CGSize(width: 162, height: 197), CGSize(width: 176, height: 215),
            CGSize(width: 184, height: 224), CGSize(width: 187, height: 223),
            CGSize(width: 198, height: 242), CGSize(width: 208, height: 248),
            CGSize(width: 205, height: 251), CGSize(width: 211, height: 257)]
        for size in sizes {
            let layout = TimerFaceLayout(size: size)
            assert(layout.countWidth >= 44 && layout.optionsWidth >= 44 && layout.actionHeight >= 44)
            assert(layout.volumeFrame.maxY < layout.statusFrame.minY)
            assert(layout.statusFrame.maxY < layout.actionFrame.minY)
            for index in 0..<720 {
                let point = layout.landmarkPoint(angle: Double(index) * .pi / 360)
                // Include the full start dot, not just the arc centerline.
                for control in [layout.actionFrame, layout.volumeFrame, layout.statusFrame] {
                    assert(!control.insetBy(dx: -3, dy: -3).contains(point), "Covered count track")
                }
                assert(point.y - 3 >= 36 * layout.scale, "Count enters system clock area")
            }
        }
        print("PASS: 8 sizes, 44pt targets, 5760 count-track points clear of controls and clock")
    }
}
