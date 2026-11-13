// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import Darwin
import Foundation

// Synthetic OCR integration check, not a Simulator or app-rendering test.
// Usage: swift scripts/check-screen-text.swift COMPILED_HELPER NEW_OUTPUT_DIR

struct SmokeFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

struct Label: Codable {
    let alternatives: [String]
    let x: Double
    let y: Double
}

struct Fixture: Codable {
    let file: String
    let labels: [Label]
}

struct Row: Decodable {
    let text: String
    let confidence: Double
    let x: Double
    let y: Double
    let recognitionLevel: String
    let corroborated: Bool
}

let imageWidth = 324
let imageHeight = 394

func render(name: String, labels: [[String]], output: URL) throws -> Fixture {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
        pixelsWide: imageWidth, pixelsHigh: imageHeight, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw SmokeFailure("Could not create the synthetic bitmap")
    }
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = context
    NSColor.black.setFill()
    NSRect(x: 0, y: 0, width: imageWidth, height: imageHeight).fill()
    // Leading Help/Privacy symbols exercise icon-inset recognition and conversion
    // back to full-image coordinates. These remain synthetic screenshot labels.
    let isNavigation = name == "settings"
    var expected: [Label] = []
    for (index, alternatives) in labels.enumerated() {
        let top = 16.0 + Double(index) * 74.0
        let card = NSRect(x: 10, y: Double(imageHeight) - top - 60,
                          width: Double(imageWidth) - 20, height: 60)
        NSColor(calibratedWhite: 0.12, alpha: 1).setFill()
        NSBezierPath(roundedRect: card, xRadius: 12, yRadius: 12).fill()
        if isNavigation && (index == 1 || index == 2) {
            let symbolName = index == 1 ? "questionmark.circle" : "hand.raised.fill"
            guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [.white])) else {
                throw SmokeFailure("Could not create the synthetic navigation icon")
            }
            symbol.draw(in: NSRect(x: 25, y: card.midY - 13, width: 26, height: 26))
        }
        let text = NSAttributedString(string: alternatives[0], attributes: [
            .font: NSFont.systemFont(ofSize: isNavigation ? 28 : 22, weight: .semibold),
            .foregroundColor: NSColor.white
        ])
        let size = text.size()
        let origin = NSPoint(x: isNavigation ? 75 : 24, y: card.midY - size.height / 2)
        text.draw(at: origin)
        expected.append(Label(alternatives: alternatives,
            x: (origin.x + size.width / 2) / Double(imageWidth),
            y: (top + 30) / Double(imageHeight)))
    }
    context.flushGraphics()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw SmokeFailure("Could not encode the synthetic bitmap")
    }
    let filename = name + ".png"
    try data.write(to: output.appendingPathComponent(filename))
    return Fixture(file: filename, labels: expected)
}

func recognize(helper: URL, fixture: Fixture, output: URL) throws -> [String: Any] {
    let stem = URL(fileURLWithPath: fixture.file).deletingPathExtension().lastPathComponent
    let stdout = output.appendingPathComponent(stem + "-stdout.json")
    let stderr = output.appendingPathComponent(stem + "-stderr.log")
    _ = FileManager.default.createFile(atPath: stdout.path, contents: nil)
    _ = FileManager.default.createFile(atPath: stderr.path, contents: nil)
    let outHandle = try FileHandle(forWritingTo: stdout)
    let errHandle = try FileHandle(forWritingTo: stderr)
    defer { try? outHandle.close(); try? errHandle.close() }
    let process = Process()
    process.executableURL = helper
    process.arguments = [output.appendingPathComponent(fixture.file).path]
    process.standardOutput = outHandle
    process.standardError = errHandle
    let started = ProcessInfo.processInfo.systemUptime
    try process.run()
    while process.isRunning && ProcessInfo.processInfo.systemUptime - started < 20 {
        Thread.sleep(forTimeInterval: 0.02)
    }
    if process.isRunning {
        process.terminate()
        let deadline = ProcessInfo.processInfo.systemUptime + 1
        while process.isRunning && ProcessInfo.processInfo.systemUptime < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        throw SmokeFailure("OCR exceeded 20 seconds for " + fixture.file)
    }
    let elapsed = ProcessInfo.processInfo.systemUptime - started
    guard process.terminationStatus == 0 else {
        throw SmokeFailure("OCR exited with code \(process.terminationStatus) for " + fixture.file)
    }
    let rows = try JSONDecoder().decode([Row].self, from: Data(contentsOf: stdout))
    guard rows.allSatisfy({ !$0.text.isEmpty && $0.confidence.isFinite && $0.x.isFinite && $0.y.isFinite
        && (0...1).contains($0.confidence) && (0...1).contains($0.x) && (0...1).contains($0.y) }) else {
        throw SmokeFailure("Invalid OCR confidence or coordinates for " + fixture.file)
    }
    for label in fixture.labels {
        let matches = rows.filter { row in
            label.alternatives.contains { $0.lowercased() == row.text.lowercased() }
                && row.recognitionLevel == "fast" && row.corroborated && row.confidence >= 0.5
        }
        guard matches.count == 1, let match = matches.first,
              abs(match.x - label.x) <= 0.06, abs(match.y - label.y) <= 0.06 else {
            throw SmokeFailure("Missing, ambiguous or misplaced OCR label: " + label.alternatives[0])
        }
    }
    return ["file": fixture.file, "passed": true, "elapsedSeconds": elapsed,
            "labels": fixture.labels.map { $0.alternatives[0] }, "recognizedRows": rows.count]
}

func main() throws {
    guard CommandLine.arguments.count == 3 else {
        throw SmokeFailure("Usage: check-screen-text COMPILED_HELPER NEW_OUTPUT_DIR")
    }
    let helper = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
    let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true).standardizedFileURL
    guard FileManager.default.isExecutableFile(atPath: helper.path),
          !FileManager.default.fileExists(atPath: output.path) else {
        throw SmokeFailure("Helper must be executable and output directory must be new")
    }
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    let fixtures = try [
        render(name: "settings", labels: [["Settings"], ["Help"], ["Privacy"], ["About"]], output: output),
        render(name: "actions", labels: [["Start class"], ["Stop session"], ["Resume session"],
                                         ["−15 min", "-15 min"], ["+15 min"]], output: output)
    ]
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(fixtures).write(to: output.appendingPathComponent("fixtures.json"))
    var results: [[String: Any]] = []
    var report: [String: Any] = ["complete": false,
        "scope": "Synthetic 324x394 OCR labels and centers; no UI rendering, app state, Simulator or physical device validated"]
    func save() throws {
        report["fixtures"] = results
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("result.json"), options: .atomic)
    }
    try save()
    do {
        for fixture in fixtures { results.append(try recognize(helper: helper, fixture: fixture, output: output)) }
        report["complete"] = true
        try save()
        print("Synthetic OCR smoke passed: two images, nine labels; no Simulator used.")
    } catch {
        report["error"] = String(describing: error)
        try save()
        throw error
    }
}

do { try main() }
catch { fputs("Synthetic OCR smoke failed: \(error)\n", stderr); exit(1) }
