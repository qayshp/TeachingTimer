// SPDX-License-Identifier: MPL-2.0
import AppKit

// Measures content only, excluding the system clock and page dots. This is an
// evidence aid, not a classifier of rendering failure, audio or touchability.
guard CommandLine.arguments.count == 2,
      let data = try? Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])),
      let bitmap = NSBitmapImageRep(data: data),
      bitmap.pixelsWide > 0, bitmap.pixelsHigh > 0 else { exit(2) }
let width = bitmap.pixelsWide, height = bitmap.pixelsHigh
var visible = 0, bright = 0, total = 0
var peak = 0.0, sum = 0.0
for y in Int(Double(height) * 0.22)..<Int(Double(height) * 0.82) {
    for x in Int(Double(width) * 0.1)..<Int(Double(width) * 0.9) {
        guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { exit(3) }
        let value = Double(max(color.redComponent, color.greenComponent, color.blueComponent))
        if value > 0.05 { visible += 1 }
        if value > 0.5 { bright += 1 }
        peak = max(peak, value); sum += value; total += 1
    }
}
guard total > 0 else { exit(2) }
let result: [String: Any] = ["width": width, "height": height,
    "region": "x=0.10...0.90, y=0.22...0.82 (top origin)",
    "visibleFraction": Double(visible) / Double(total),
    "brightFraction": Double(bright) / Double(total),
    "meanChannelMaximum": sum / Double(total), "peakChannel": peak]
FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]))
