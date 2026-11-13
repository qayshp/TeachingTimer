// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import Darwin
import Foundation

// Synthetic screenshot measurements only; no app, Simulator or device is used.
// Usage: swift scripts/check-control-outline.swift COMPILED_HELPER NEW_OUTPUT_DIR

struct FixtureFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

enum Content: String {
    case outline2, outline4, missingLeft, missingRight, black, textOnly, shortCrossing, wrongInset, invalidResolution
}

struct Fixture {
    let name: String
    let width: Int
    let height: Int
    let rect: CGRect // Literal reference bounds, in top-origin screenshot pixels.
    let content: Content

    var leftExpected: Bool {
        [.outline2, .outline4, .missingRight].contains(content)
    }
    var rightExpected: Bool {
        [.outline2, .outline4, .missingLeft].contains(content)
    }
}

struct Measurement: Codable {
    let left: Double
    let right: Double
    let review: Bool
    let width: Int
    let height: Int
    let sampleX: SamplePositions
}

struct SamplePositions: Codable {
    let left: Int
    let right: Int
}

func render(_ fixture: Fixture, to output: URL) throws {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
        pixelsWide: fixture.width, pixelsHigh: fixture.height, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw FixtureFailure("Could not create the synthetic bitmap")
    }
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = context
    NSColor.black.setFill()
    NSRect(x: 0, y: 0, width: fixture.width, height: fixture.height).fill()
    let rect = NSRect(x: fixture.rect.minX, y: Double(fixture.height) - fixture.rect.maxY,
                      width: fixture.rect.width, height: fixture.rect.height)
    if fixture.content == .textOnly {
        let text = NSAttributedString(string: "Stop count", attributes: [
            .font: NSFont.systemFont(ofSize: 24, weight: .semibold), .foregroundColor: NSColor.white
        ])
        let size = text.size()
        text.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
    } else if fixture.content == .shortCrossing {
        NSColor.white.setFill()
        for x in [rect.minX, rect.maxX] {
            NSRect(x: x - 6, y: rect.midY - 2, width: 12, height: 4).fill()
        }
    } else if fixture.content != .black && fixture.content != .invalidResolution {
        NSColor.white.setStroke()
        let path = NSBezierPath(roundedRect: rect, xRadius: 26, yRadius: 26)
        path.lineWidth = fixture.content == .outline2 ? 2 : 4
        path.stroke()
        NSColor.black.setFill()
        if fixture.content == .missingLeft {
            NSRect(x: rect.minX - 8, y: rect.minY - 8, width: 16, height: rect.height + 16).fill()
        } else if fixture.content == .missingRight {
            NSRect(x: rect.maxX - 8, y: rect.minY - 8, width: 16, height: rect.height + 16).fill()
        }
    }
    context.flushGraphics()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw FixtureFailure("Could not encode the synthetic bitmap")
    }
    try data.write(to: output.appendingPathComponent(fixture.name + ".png"))
}

func measure(_ fixture: Fixture, helper: URL, output: URL) throws -> [String: Any] {
    let stdout = output.appendingPathComponent(fixture.name + "-stdout.json")
    let stderr = output.appendingPathComponent(fixture.name + "-stderr.log")
    _ = FileManager.default.createFile(atPath: stdout.path, contents: nil)
    _ = FileManager.default.createFile(atPath: stderr.path, contents: nil)
    let outHandle = try FileHandle(forWritingTo: stdout)
    let errHandle = try FileHandle(forWritingTo: stderr)
    defer { try? outHandle.close(); try? errHandle.close() }
    let process = Process()
    process.executableURL = helper
    process.arguments = [output.appendingPathComponent(fixture.name + ".png").path]
    process.standardOutput = outHandle
    process.standardError = errHandle
    let started = ProcessInfo.processInfo.systemUptime
    try process.run()
    while process.isRunning && ProcessInfo.processInfo.systemUptime - started < 5 {
        Thread.sleep(forTimeInterval: 0.02)
    }
    if process.isRunning {
        process.terminate()
        let deadline = ProcessInfo.processInfo.systemUptime + 1
        while process.isRunning && ProcessInfo.processInfo.systemUptime < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        throw FixtureFailure("Measurement exceeded five seconds for " + fixture.name)
    }
    let elapsed = ProcessInfo.processInfo.systemUptime - started
    if fixture.content == .invalidResolution {
        guard process.terminationStatus == 2, try Data(contentsOf: stdout).isEmpty else {
            throw FixtureFailure("Unsupported resolution was not rejected for " + fixture.name)
        }
        return ["file": fixture.name + ".png", "width": fixture.width, "height": fixture.height,
                "expectedExit": 2, "exit": process.terminationStatus, "elapsedSeconds": elapsed, "passed": true]
    }
    guard process.terminationStatus == 0 else {
        throw FixtureFailure("Helper exited with code \(process.terminationStatus) for " + fixture.name)
    }
    let value = try JSONDecoder().decode(Measurement.self, from: Data(contentsOf: stdout))
    guard value.left.isFinite && value.right.isFinite,
          (0...1).contains(value.left), (0...1).contains(value.right) else {
        throw FixtureFailure("Invalid side coverage for " + fixture.name)
    }
    // These expected positions are independent literals, not the helper's scale formula.
    let expectedSamples = fixture.width == 324 ? (56, 268) : (70, 352)
    guard value.width == fixture.width, value.height == fixture.height,
          value.sampleX.left == expectedSamples.0, value.sampleX.right == expectedSamples.1 else {
        throw FixtureFailure("Incorrect image dimensions or sampling positions for " + fixture.name)
    }
    let absentMaximum = fixture.content == .shortCrossing ? 0.25 : 0.1
    let leftMatches = fixture.leftExpected ? value.left >= 0.9 : value.left <= absentMaximum
    let rightMatches = fixture.rightExpected ? value.right >= 0.9 : value.right <= absentMaximum
    guard leftMatches && rightMatches,
          value.review == !(fixture.leftExpected && fixture.rightExpected) else {
        throw FixtureFailure("Unexpected side coverage or review flag for " + fixture.name)
    }
    return ["file": fixture.name + ".png", "width": fixture.width, "height": fixture.height,
            "referenceBounds": [fixture.rect.minX, fixture.rect.minY, fixture.rect.width, fixture.rect.height],
            "leftExpected": fixture.leftExpected, "rightExpected": fixture.rightExpected,
            "left": value.left, "right": value.right, "review": value.review,
            "sampleX": ["left": value.sampleX.left, "right": value.sampleX.right],
            "elapsedSeconds": elapsed, "passed": true]
}

func main() throws {
    guard CommandLine.arguments.count == 3 else {
        throw FixtureFailure("Usage: check-control-outline COMPILED_HELPER NEW_OUTPUT_DIR")
    }
    let helper = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
    let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true).standardizedFileURL
    guard FileManager.default.isExecutableFile(atPath: helper.path),
          !FileManager.default.fileExists(atPath: output.path) else {
        throw FixtureFailure("Helper must be executable and output directory must be new")
    }
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    // Independent literal fixtures: do not calculate these from the helper's
    // screen-width scaling or sampling formula, which this check must challenge.
    let layouts = [("se", 324, 394, CGRect(x: 56, y: 256, width: 212, height: 88)),
                   ("ultra", 422, 514, CGRect(x: 70, y: 341.5, width: 282, height: 110))]
    let variants: [Content] = [.outline2, .outline4, .missingLeft, .missingRight, .black, .textOnly, .shortCrossing]
    var fixtures = layouts.flatMap { name, width, height, rect in
        variants.map { Fixture(name: name + "-" + $0.rawValue, width: width, height: height,
                               rect: rect, content: $0) }
    }
    fixtures.append(Fixture(name: "ultra-wrong-inset", width: 422, height: 514,
        rect: CGRect(x: 56, y: 341.5, width: 310, height: 110), content: .wrongInset))
    fixtures.append(Fixture(name: "invalid-height", width: 324, height: 393,
        rect: CGRect(x: 56, y: 256, width: 212, height: 88), content: .invalidResolution))
    fixtures.append(Fixture(name: "invalid-ultra-height", width: 422, height: 513,
        rect: CGRect(x: 70, y: 341.5, width: 282, height: 110), content: .invalidResolution))
    fixtures.append(Fixture(name: "cropped-width", width: 323, height: 394,
        rect: CGRect(x: 56, y: 256, width: 212, height: 88), content: .invalidResolution))
    var results: [[String: Any]] = []
    var report: [String: Any] = ["complete": false,
        "scope": "Synthetic outline pixels only; no app rendering, Simulator, device or touchability validated"]
    func save() throws {
        report["fixtures"] = results
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("result.json"), options: .atomic)
    }
    try save()
    do {
        for fixture in fixtures {
            try render(fixture, to: output)
            results.append(try measure(fixture, helper: helper, output: output))
            try save()
        }
        report["complete"] = true
        try save()
        print("Synthetic control-outline smoke passed: 15 outline fixtures, three invalid resolutions; no Simulator used.")
    } catch {
        report["error"] = String(describing: error)
        try save()
        throw error
    }
}

do { try main() }
catch { fputs("Synthetic control-outline smoke failed: \(error)\n", stderr); exit(1) }
