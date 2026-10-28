// SPDX-License-Identifier: MPL-2.0
import Foundation
import Vision
import ImageIO

// Screenshot-only OCR fallback: Device Hub does not expose Watch app AX nodes.
// Coordinates are normalized to the simulator screenshot, never desktop pixels.
guard CommandLine.arguments.count == 2,
      let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { exit(2) }
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.recognitionLanguages = ["en-US"]
try VNImageRequestHandler(cgImage: image).perform([request])
let rows = (request.results ?? []).compactMap { observation -> [String: Any]? in
    guard let candidate = observation.topCandidates(1).first else { return nil }
    return ["text": candidate.string, "x": observation.boundingBox.midX,
            "y": 1 - observation.boundingBox.midY, "confidence": candidate.confidence]
}
FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys]))
