// SPDX-License-Identifier: MPL-2.0
import AppKit

// Evidence helper for the full-width count button at default text size. Inspect
// both straight sides, away from rounded corners and moving text/hand crossings.
// Low coverage is a review flag, never an assertion about touchability or cause.
guard CommandLine.arguments.count == 2,
      let data = try? Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])),
      let bitmap = NSBitmapImageRep(data: data) else { exit(2) }
let width = bitmap.pixelsWide, height = bitmap.pixelsHigh
// Calibrated full-screen SE 3 40 mm / Ultra 4 49 mm captures only. A cropped
// image or another form factor must not produce plausible-looking measurements.
guard (width == 324 && height == 394) || (width == 422 && height == 514) else { exit(2) }
let scale = min(1.25, max(1, min(Double(width) / 324, Double(height) / 394)))
let centerY = Double(height) - 94 * scale
let halfStraight = 44 * scale - 26
let sideInset = Int((56 * scale).rounded())
func coverage(x: Int) -> Double {
    let matches = (0..<20).filter { index in
        let y = Int(centerY - halfStraight + 2 * halfStraight * Double(index) / 19)
        return (-2...2).contains { dx in
            guard let color = bitmap.colorAt(x: x + dx, y: y)?.usingColorSpace(.deviceRGB) else { return false }
            return min(color.redComponent, color.greenComponent, color.blueComponent) > 0.55
        }
    }
    return Double(matches.count) / 20
}
let left = coverage(x: sideInset), right = coverage(x: width - sideInset)
let result: [String: Any] = ["left": left, "right": right,
    "review": left < 0.7 || right < 0.7, "width": width, "height": height,
    "sampleX": ["left": sideInset, "right": width - sideInset]]
FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]))
