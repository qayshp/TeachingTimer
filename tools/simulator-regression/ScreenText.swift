// SPDX-License-Identifier: MPL-2.0
import Foundation
import Vision
import ImageIO
import CoreML

// Screenshot-only OCR fallback: Device Hub does not expose Watch app AX nodes.
// Coordinates are normalized to the simulator screenshot, never desktop pixels.
// Accurate recognition can block in ANE model compilation even with a CPU
// compute device selected. Fast recognition avoids that path. Its raw scores
// differ (commonly 0.5), so do not relabel them as accurate-mode confidence.
// Corroborate each actionable row against a separately resized copy instead.
struct Row {
    let text: String
    let confidence: Float
    let x: Double
    let y: Double
}

let started = ProcessInfo.processInfo.systemUptime
func log(_ stage: String) {
    let record: [String: Any] = ["stage": stage, "recognitionLevel": "fast",
        "computeDevice": "cpu", "elapsedSeconds": ProcessInfo.processInfo.systemUptime - started]
    if let data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]) {
        FileHandle.standardError.write(data + Data([10]))
    }
}

func recognize(_ image: CGImage, stage: String, region: CGRect) throws -> [Row] {
    log(stage + "-begin")
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .fast
    request.recognitionLanguages = ["en-US"]
    request.regionOfInterest = region
    for (stage, devices) in try request.supportedComputeStageDevices {
        guard let cpu = devices.first(where: { if case .cpu = $0 { return true }; return false }) else {
            throw NSError(domain: "ScreenText", code: 3)
        }
        request.setComputeDevice(cpu, for: stage)
    }
    try VNImageRequestHandler(cgImage: image).perform([request])
    log(stage + "-complete")
    return (request.results ?? []).compactMap { observation in
        guard let candidate = observation.topCandidates(1).first else { return nil }
        // Vision reports coordinates relative to the region of interest.
        return Row(text: candidate.string, confidence: candidate.confidence,
                   x: region.minX + observation.boundingBox.midX * region.width,
                   y: 1 - (region.minY + observation.boundingBox.midY * region.height))
    }
}

do {
    guard CommandLine.arguments.count == 2,
          let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          image.width <= 4096, image.height <= 4096,
          let context = CGContext(data: nil, width: image.width * 2, height: image.height * 2,
              bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(2) }
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width * 2, height: image.height * 2))
    guard let enlarged = context.makeImage() else { exit(2) }
    log("image-loaded")
    let full = CGRect(x: 0, y: 0, width: 1, height: 1)
    let original = try recognize(image, stage: "original", region: full)
    let scaled = try recognize(enlarged, stage: "enlarged", region: full)
    // A leading SF Symbol can make fast OCR omit an entire short label (Help).
    // Inspect an icon-inset region too, retaining only otherwise missing lines.
    // Never replace an uncertain original or merge fragments into guessed text.
    let inset = CGRect(x: 0.19, y: 0, width: 0.81, height: 1)
    let insetOriginal = try recognize(image, stage: "inset-original", region: inset)
    let insetScaled = try recognize(enlarged, stage: "inset-enlarged", region: inset)
    func corroborated(_ row: Row, in comparison: [Row]) -> Bool {
        guard row.confidence >= 0.5 else { return false }
        return comparison.filter {
            $0.text == row.text && $0.confidence >= 0.5 &&
                abs($0.x - row.x) <= 0.025 && abs($0.y - row.y) <= 0.025
        }.count == 1
    }
    let additions = insetOriginal.filter { row in
        !original.contains { abs($0.y - row.y) <= 0.025 } && corroborated(row, in: insetScaled)
    }
    let rows = (original + additions).map { row -> [String: Any] in
        let comparison = original.contains { $0.text == row.text && $0.x == row.x && $0.y == row.y }
            ? scaled : insetScaled
        // An icon may become extra text at just one scale ("eg Privacy").
        // Preserve the original row; both inset reads must independently agree
        // with that exact word and center before this alternate confirmation.
        let verified = corroborated(row, in: comparison) ||
            (corroborated(row, in: insetOriginal) && corroborated(row, in: insetScaled))
        return ["text": row.text, "x": row.x, "y": row.y, "confidence": row.confidence,
                "recognitionLevel": "fast", "corroborated": verified]
    }
    FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys]))
    log("complete")
} catch {
    log("failed")
    let error = error as NSError
    fputs("ScreenText error \(error.domain) (\(error.code))\n", stderr)
    exit(1)
}
