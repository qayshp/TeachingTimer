// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// Export template PNGs at intentional natural sizes, including a smaller inline
// image. Run from the repository root: swift scripts/render-complication-glyph.swift
import AppKit

let sourceURL = URL(fileURLWithPath: "docs/design/complication-glyph/mat-clock-source.png")
guard let source = NSImage(contentsOf: sourceURL) else {
    fatalError("Missing source artwork")
}
for (name, points) in [("MatClockGlyph", 40), ("MatClockInlineGlyph", 14)] {
    let directory = URL(fileURLWithPath: "TeachingTimerComplications/Assets.xcassets/\(name).imageset")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var images: [[String: String]] = []
    for scale in 1...3 {
        let size = points * scale
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
            let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            fatalError("Cannot render complication artwork")
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        source.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
                    from: .zero, operation: .copy, fraction: 1)
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        let filename = "\(name)@\(scale)x.png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(filename))
        images.append(["filename": filename, "idiom": "universal", "scale": "\(scale)x"])
    }
    let metadata: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1],
                                  "properties": ["template-rendering-intent": "template"]]
    var data = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
    data.append(0x0a)
    try data.write(to: directory.appendingPathComponent("Contents.json"))
    print("Wrote \(name) at \(points) points, 1x/2x/3x")
}
