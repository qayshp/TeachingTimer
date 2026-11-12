// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// Preparation is read-only. Only an explicit action queues a device transfer;
/// Preparing or transferring a file does not establish email delivery.
struct DiagnosticSharingView: View {
    struct Prepared: Sendable {
        let report: DiagnosticReport.Report
        let file: DiagnosticReportFile.Prepared
    }

    let prepare: @MainActor (DiagnosticReport.Window, Set<URL>) async throws -> Prepared
    @ObservedObject private var companion = DiagnosticCompanion.shared
    @State private var window: DiagnosticReport.Window = .lastTwoHours
    @State private var prepared: Prepared?
    @State private var preparing = false
    @State private var failure: String?
    @State private var preparedFiles: Set<URL> = []

    var body: some View {
        Form {
            if let prepared {
                summary(prepared)
                Section {
                    Button("Send report to iPhone") { companion.send(prepared.file.url) }
                        .buttonStyle(.borderedProminent)
                        .disabled(companion.installed != true)
                    Text(companion.status)
                } footer: {
                    Text("Open the optional iPhone app to email support. Share after class.")
                }
                Section {
                    NavigationLink("Preview events") { preview(prepared.report) }
                    Button("Choose another time") { self.prepared = nil }
                }
            } else {
                Section {
                    Text("Review a report before sharing. Nothing is sent automatically.")
                        .font(.caption)
                }
                Section {
                    Text(companion.status)
                    Button("Check connection") { companion.checkConnection() }
                }
                Section {
                    Picker("Include", selection: $window) {
                        Text("Last 2 hours").tag(DiagnosticReport.Window.lastTwoHours)
                        Text("Last 24 hours").tag(DiagnosticReport.Window.lastDay)
                        Text("All retained events").tag(DiagnosticReport.Window.allRetained)
                    }
                    .disabled(preparing)
                    Button {
                        failure = nil
                        preparing = true
                    } label: {
                        if preparing { ProgressView("Preparing…") }
                        else { Label("Prepare report", systemImage: "doc.text") }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(preparing)
                    .accessibilityIdentifier("diagnostics-prepare")
                } footer: {
                    Text("Saved history may be shorter than this interval. Preparing a report doesn’t change your class or stop the count.")
                }
                if let failure { Section { Text(failure) } }
            }
            Section("Connection details") {
                Text("Version \(DiagnosticCompanion.build)").font(.caption)
                Text(companion.connection).font(.caption)
                ForEach(Array(companion.events.enumerated()), id: \.offset) { _, event in
                    Text(event).font(.caption)
                }
            }
            Section("Before sharing") {
                Text("Includes app and watchOS versions, timestamps, session and interface events, count timing, and error codes. Times can reveal when you taught or used the app.")
                Text("Excludes song titles, audio, actual volume, saved preference files, and system logs. Unapproved fields and free-form errors are left out.")
                Text("Do not post this file in a public GitHub issue. The recipient can keep a copy.")
            }
        }
        // Show the new summary from its beginning, not the old picker offset.
        .id(prepared?.file.url)
        .navigationTitle("Diagnostics")
        .task(id: preparing) {
            guard preparing else { return }
            defer { preparing = false }
            do {
                let value = try await prepare(window, preparedFiles)
                try Task.checkCancellation()
                preparedFiles.insert(value.file.url)
                prepared = value
            } catch is CancellationError {
                return
            } catch DiagnosticReport.Failure.tooLarge {
                failure = "This report is too large. Choose a shorter interval. No events were silently removed to fit."
            } catch DiagnosticReportFile.Failure.cacheFull {
                failure = "Eight prepared reports are still being kept for sharing. Try again after a day, or send one you already saved."
            } catch {
                // Do not surface private filesystem paths from an underlying error.
                failure = "Couldn’t prepare the report. Your journals are unchanged. Try again, or email support with a description."
            }
        }
    }

    @ViewBuilder
    private func summary(_ prepared: Prepared) -> some View {
        Section("Ready to share") {
            Text("\(prepared.report.eventCount) events · \(ByteCountFormatter.string(fromByteCount: Int64(prepared.file.byteCount), countStyle: .file))")
            if let start = prepared.report.actualStart, let end = prepared.report.actualEnd {
                Text("From \(start.formatted(date: .abbreviated, time: .standard))")
                Text("To \(end.formatted(date: .abbreviated, time: .standard))")
            } else {
                Text("No events available in this interval.")
            }
            Text("These are the events available now, not a guarantee of complete history.")
                .font(.caption)
        }
        ForEach(prepared.report.journals, id: \.source) { journal in
            Section(journal.source.displayName) {
                Text("\(journal.events.count) events")
                if journal.status == .oversized {
                    Text("This journal was too large to read safely. This report is incomplete.")
                } else if journal.status != .available {
                    Text(journal.status == .missing ? "No saved history was available. Any queued events are included." :
                         "Some history could not be read. This report is incomplete.")
                }
                if journal.lastWriteFailed {
                    Text("The latest journal save failed. Available events in memory are included.")
                }
                if journal.excludedAfterCutoff > 0 {
                    Text("\(journal.excludedAfterCutoff) events dated after this report were excluded.")
                }
                if journal.omittedEvents > 0 || journal.omittedFields > 0 {
                    Text("Privacy filter — omitted events: \(journal.omittedEvents); fields: \(journal.omittedFields).")
                        .font(.caption)
                }
            }
        }
    }

    private func preview(_ report: DiagnosticReport.Report) -> some View {
        List {
            Section {
                Text("The latest 20 included events from each journal are shown here. The file includes all \(report.eventCount) events in its summary.")
            }
            ForEach(report.journals, id: \.source) { journal in
                Section(journal.source.displayName) {
                    ForEach(Array(journal.events.suffix(20).enumerated()), id: \.offset) { _, event in
                        NavigationLink {
                            Form {
                                Text(event.timestamp.formatted(date: .abbreviated, time: .standard))
                                ForEach(event.details.keys.sorted(), id: \.self) { key in
                                    Text("\(key): \(event.details[key] ?? "")")
                                        .font(.caption)
                                }
                            }.navigationTitle("Event")
                        } label: {
                            Text(event.event.replacingOccurrences(of: "_", with: " "))
                                .font(.caption)
                        }
                    }
                }
            }
        }.navigationTitle("Preview")
    }
}

private extension DiagnosticReport.Source {
    var displayName: String {
        switch self {
        case .runtime: "Sessions"
        case .interface: "Interface"
        case .landmarks: "Counts"
        }
    }
}
