// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// Original code-drawn icon: no downloaded artwork or third-party assets.
// Run from the repository root: swift scripts/render-icon.swift
import AppKit

let size = 1024
let bitmap = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
    bytesPerRow: size * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let graphics = NSGraphicsContext(cgContext: bitmap, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
NSColor.black.setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()
let ring = NSBezierPath(roundedRect: NSRect(x: 190, y: 190, width: 644, height: 644), xRadius: 180, yRadius: 180)
NSColor.white.setStroke(); ring.lineWidth = 20; ring.stroke()
for index in 0..<12 {
    let angle = Double(index) * .pi / 6
    let outer = CGPoint(x: 512 + sin(angle) * 270, y: 512 + cos(angle) * 270)
    let inner = CGPoint(x: 512 + sin(angle) * 245, y: 512 + cos(angle) * 245)
    let path = NSBezierPath(); path.move(to: inner); path.line(to: outer)
    path.lineWidth = 12; path.lineCapStyle = .round; path.stroke()
}
let minute = NSBezierPath(); minute.move(to: CGPoint(x: 512, y: 512)); minute.line(to: CGPoint(x: 425, y: 660))
minute.lineWidth = 36; minute.lineCapStyle = .square; minute.stroke()
NSColor(calibratedRed: 1, green: 0.84, blue: 0, alpha: 1).setStroke()
let second = NSBezierPath(); second.move(to: CGPoint(x: 512, y: 512)); second.line(to: CGPoint(x: 665, y: 740))
second.lineWidth = 18; second.lineCapStyle = .round; second.stroke()
NSColor(calibratedRed: 1, green: 0.84, blue: 0, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 485, y: 485, width: 54, height: 54)).fill()
NSGraphicsContext.restoreGraphicsState()
let image = NSBitmapImageRep(cgImage: bitmap.makeImage()!)
let target = URL(fileURLWithPath: "TeachingTimer/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
try image.representation(using: .png, properties: [:])!.write(to: target)
print("Wrote \(target.path)")
