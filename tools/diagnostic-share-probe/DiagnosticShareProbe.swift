// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreTransferable
import OSLog
import SwiftUI
import UniformTypeIdentifiers

private let shareLogger = Logger(subsystem: "net.qays.TeachingTimer.DiagnosticShareProbe", category: "Sharing")

@main
struct DiagnosticShareProbeApp: App {
    var body: some Scene {
        WindowGroup { ShareProbeView() }
    }
}

private struct JSONFixture: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { item in
            shareLogger.info("file_representation_requested type=json")
            return SentTransferredFile(item.url)
        }
    }
}

private struct ZIPFixture: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .zip) { item in
            shareLogger.info("file_representation_requested type=zip")
            return SentTransferredFile(item.url)
        }
    }
}

private struct ShareProbeView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Share probe").font(.headline)
                Text("Synthetic data only").font(.caption)

                ShareLink(item: "TeachingTimer sharing test. This is harmless synthetic text, not a diagnostic journal.") {
                    Label("Share text", systemImage: "text.bubble")
                }

                if let url = Bundle.main.url(forResource: "synthetic-small", withExtension: "json") {
                    ShareLink(item: JSONFixture(url: url), preview: SharePreview("Synthetic JSON")) {
                        Label("Share JSON", systemImage: "doc.text")
                    }
                } else {
                    Text("JSON fixture missing").foregroundStyle(.red)
                }

                if let url = Bundle.main.url(forResource: "synthetic-journals", withExtension: "zip") {
                    ShareLink(item: ZIPFixture(url: url), preview: SharePreview("Synthetic journal ZIP")) {
                        Label("Share ZIP", systemImage: "doc.zipper")
                    }
                } else {
                    Text("ZIP fixture missing").foregroundStyle(.red)
                }

                Text("No journals or accounts read.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 4)
        }
    }
}
