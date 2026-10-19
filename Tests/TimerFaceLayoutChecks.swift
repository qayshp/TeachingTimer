import Foundation

@main
struct TimerFaceLayoutChecks {
    static func main() {
        // Logical display sizes span SE 40/44, Series 41–46, and Ultra.
        let sizes: [CGSize] = [
            CGSize(width: 162, height: 197), CGSize(width: 176, height: 215),
            CGSize(width: 184, height: 224), CGSize(width: 187, height: 223),
            CGSize(width: 198, height: 242), CGSize(width: 208, height: 248),
            CGSize(width: 205, height: 251), CGSize(width: 211, height: 257),
        ]
        for size in sizes {
            let layout = TimerFaceLayout(size: size)
            let controlsTop = layout.controlsCenter.y - layout.controlsHeight / 2
            let volumeBottom = layout.volumeCenter.y + layout.volumeSize.height / 2
            assert(layout.countHeight >= 44 && layout.resetSide >= 44)
            assert(layout.controlsWidth - layout.resetSide - layout.spacing >= 44)
            assert(layout.controlsWidth <= size.width - 24)
            assert(volumeBottom + 5 <= controlsTop, "Overlapping controls at \(size)")
            assert(layout.volumeCenter.y - layout.volumeSize.height / 2 >= 18)
            assert(layout.controlsCenter.y + layout.controlsHeight / 2 < size.height - 12)
            assert(TimerFaceLayout.cornerRadius(for: size) < size.width / 2)
        }
        print("PASS: 8 Watch sizes, separated volume/actions, 44pt action targets, edge clearance")
    }
}
