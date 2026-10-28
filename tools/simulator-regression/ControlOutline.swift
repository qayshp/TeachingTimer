// SPDX-License-Identifier: MPL-2.0
import AppKit

// Evidence helper for the full-width count button at default text size. Inspect
// both straight sides, away from rounded corners and moving text/hand crossings.
// Low coverage is a review flag, never an assertion about touchability or cause.
guard CommandLine.arguments.count == 2,
      let data = try? Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])),
      let bitmap = NSBitmapImageRep(data: data),
      [324, 422].contains(bitmap.pixelsWide) else { exit(2) }
let width = bitmap.pixelsWide, height = bitmap.pixelsHigh
let scale = min(1.25, max(1, Double(width) / 324))
let centerY = Double(height) - 94 * scale
let halfStraight = 44 * scale - 26
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
let left = coverage(x: 56), right = coverage(x: width - 56)
let result: [String: Any] = ["left": left, "right": right,
    "review": left < 0.7 || right < 0.7]
FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]))
