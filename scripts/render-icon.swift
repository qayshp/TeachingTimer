// SPDX-License-Identifier: MPL-2.0
// Render the three watch icon variants from the reviewed rolled-mat draft.
// Run from the repository root: swift scripts/render-icon.swift
import AppKit

let size = 1024
let sourceURL = URL(fileURLWithPath: "docs/design/icon-drafts/mat-timer.png")
guard let source = NSImage(contentsOf: sourceURL) else { fatalError("Missing rolled-mat source artwork") }

func writeIcon(_ name: String, badge: String? = nil, color: NSColor? = nil) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.current = context
    NSColor.black.setFill(); NSRect(x: 0, y: 0, width: size, height: size).fill()
    source.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero,
                operation: .copy, fraction: 1)
    if let badge, let color {
        let rect = NSRect(x: badge == "BETA" ? 600 : 650, y: 58,
                          width: badge == "BETA" ? 370 : 320, height: 128)
        let pill = NSBezierPath(roundedRect: rect, xRadius: 64, yRadius: 64)
        color.setFill(); pill.fill()
        NSColor.white.setStroke(); pill.lineWidth = 9; pill.stroke()
        let font = NSFont.systemFont(ofSize: 70, weight: .black)
        let text = NSAttributedString(string: badge, attributes: [
            .font: font, .foregroundColor: NSColor.white
        ])
        let textSize = text.size()
        text.draw(at: NSPoint(x: rect.midX - textSize.width / 2,
                              y: rect.midY - textSize.height / 2 + 3))
    }
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    let target = URL(fileURLWithPath: "TeachingTimer/Assets.xcassets/\(name).appiconset/\(name).png")
    try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
    try bitmap.representation(using: .png, properties: [:])!.write(to: target)
    print("Wrote \(target.path)")
}

try writeIcon("AppIcon")
try writeIcon("AppIconBeta", badge: "BETA", color: NSColor(calibratedRed: 0.55, green: 0.12, blue: 0.28, alpha: 1))
try writeIcon("AppIconDev", badge: "DEV", color: NSColor(calibratedRed: 0.08, green: 0.28, blue: 0.52, alpha: 1))
