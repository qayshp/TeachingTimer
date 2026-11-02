// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
import Foundation
import CoreImage
import AppKit
import Vision

// Deterministic, local-only web QR assets; --check decodes existing files.
let args = CommandLine.arguments
guard args.count == 3, ["--generate", "--check"].contains(args[1]) else {
    fatalError("Usage: swift scripts/information-qr.swift --generate|--check INFORMATION_DIRECTORY")
}
let root = URL(fileURLWithPath: args[2], isDirectory: true)
struct Website: Decodable { let title: String; let url: URL }
let websites = try JSONDecoder().decode([String: Website].self,
    from: Data(contentsOf: root.appendingPathComponent("WebLinks.json")))
let context = CIContext()
for (key, website) in websites.sorted(by: { $0.key < $1.key }) {
    precondition(website.url.scheme == "https" && !website.title.isEmpty)
    let output = root.appendingPathComponent(key + ".png")
    if args[1] == "--generate" {
        let filter = CIFilter(name: "CIQRCodeGenerator")!
        filter.setValue(Data(website.url.absoluteString.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        let code = filter.outputImage!
        // Four-module quiet zone, opaque white, integer scaling.
        let extent = code.extent.insetBy(dx: -4, dy: -4)
        let padded = code.composited(over: CIImage(color: .white).cropped(to: extent))
        let scaled = padded.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let image = context.createCGImage(scaled, from: scaled.extent)!
        try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: output)
    }
    let request = VNDetectBarcodesRequest()
    request.symbologies = [.qr]
    try VNImageRequestHandler(url: output).perform([request])
    precondition(request.results?.map(\.payloadStringValue) == [website.url.absoluteString],
                 "QR does not match WebLinks.json: \(key)")
    print("Verified \(key) QR")
}
