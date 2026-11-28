// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import MessageUI

@main
struct SupportApp: App {
    private static let exports = DiagnosticInbox.Exports(temporaryDirectory: FileManager.default.temporaryDirectory)
    var body: some Scene { WindowGroup { SupportView(exports: Self.exports) } }
}

struct SupportView: View {
    let exports: DiagnosticInbox.Exports
    @ObservedObject private var companion = DiagnosticCompanion.shared
    @State private var draft: MailDraft?
    @State private var export: DiagnosticInbox.Exports.Staged?
    @State private var window: DiagnosticReportFormat.Window = .lastTwoHours
    @Environment(\.scenePhase) private var scenePhase
    private struct MailDraft: Identifiable { let id = UUID(); let data: Data? }
    @State private var notice = ""
    @State private var confirmDelete = false
    @State private var deletingReportID: UUID?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Teaching Timer").font(.title2)
                        Text("Version \(DiagnosticCompanion.build)").font(.caption).textSelection(.enabled)
                        Text("Optional support for your Watch. Teaching works without this iPhone app.")
                            .font(.subheadline)
                    }
                }
                if let report = companion.received {
                    Section("Saved report") {
                        let summary = report.summary
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Prepared \(summary.generatedAt.formatted(date: .abbreviated, time: .shortened))")
                            Text("\(summary.window.title) · \(summary.events) events")
                            Text("Watch build \(summary.build)")
                        }.font(.caption)
                        Button("Email support") {
                            notice = ""
                            if MFMailComposeViewController.canSendMail() { draft = MailDraft(data: report.data) }
                            else { notice = "Set up an account in Apple Mail to compose support email, or share the saved report with another mail app." }
                        }
                        Menu("Report options", systemImage: "ellipsis.circle") {
                            Button("Export received report…") {
                                do { export = try exports.stage(report) }
                                catch { notice = "Couldn’t prepare an export. Try again." }
                            }
                            Button("Delete received report", role: .destructive) {
                                deletingReportID = report.id
                                confirmDelete = true
                            }
                        }
                    }
                }
                Section {
                    Text(companion.status)
                    if companion.installed != true {
                        Button("Check connection") { companion.checkConnection() }
                    }
                    Picker("Include", selection: $window) {
                        ForEach(DiagnosticReportFormat.Window.allCases) { Text($0.title).tag($0) }
                    }.disabled(companion.requesting)
                    Button(companion.requesting ? "Waiting for Watch…" : "Get diagnostics from Watch") { companion.requestReport(window: window) }
                        .disabled(companion.installed != true || companion.requesting)
                } header: {
                    Text("Diagnostics")
                } footer: {
                    Text("Keep the Watch app open. History may be shorter than this window. Reports contain usage times. Nothing is emailed automatically.")
                }
                Section {
                    DisclosureGroup("Connection details") {
                        Button("Check connection") { companion.checkConnection() }
                        Text(companion.connection).font(.caption).textSelection(.enabled)
                        if let build = companion.peerBuild { Text("Watch version \(build)").font(.caption) }
                        ForEach(companion.events) { event in
                            Text(event.text).font(.caption).textSelection(.enabled)
                        }
                    }
                }
                Section {
                    Button("Contact support") {
                        if MFMailComposeViewController.canSendMail() { draft = MailDraft(data: nil) }
                        else { notice = "Email teachingtimer@qays.net from your usual mail app. No report is needed to ask for help." }
                    }
                    NavigationLink("About & privacy") { PhoneInformationView() }
                }

            }
            .navigationTitle("Watch support")
            .sheet(item: $draft) { draft in SupportMail(data: draft.data) }
            .sheet(item: $export) { staged in
                DiagnosticShareSheet(file: staged.url) {
                    exports.finish(staged)
                    export = nil
                }
                .interactiveDismissDisabled()
            }
            .alert("Support", isPresented: Binding(get: { !notice.isEmpty }, set: { if !$0 { notice = "" } })) {
                Button("OK") { notice = "" }
            } message: { Text(notice) }
            .confirmationDialog("Delete the saved report from this iPhone?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete report", role: .destructive) {
                    guard let id = deletingReportID else { return }
                    do {
                        if try !companion.deleteReport(id) { notice = "The saved report changed. Review it before deleting." }
                    } catch { notice = "Couldn’t delete the report. Try again." }
                }
            } message: { Text("Copies already emailed or exported are separate.") }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { companion.checkConnection() }
            }
        }
    }
}

private struct DiagnosticShareSheet: UIViewControllerRepresentable {
    let file: URL
    let finish: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in finish() }
        return controller
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private struct PhoneInformationView: View {
    var body: some View {
        Form {
            Section {
                Text("Teaching Timer").font(.headline)
                Text("Version \(DiagnosticCompanion.build)").textSelection(.enabled)
                Text("The iPhone app is optional. All teaching features work independently on your Watch.")
            }
            Section("Privacy") {
                Text("No account, ads, tracking or automatic uploads. Reports move between your paired devices only after a request. They can reveal when you used the app.")
                Text("The latest received report replaces the previous one and is excluded from device backup. Delete it from the support screen when finished. Recipient copies are separate.")
                Text("Email is sent only when you confirm it in the composer. Your mail provider handles the sent message and attachment.")
                Link("Full privacy policy", destination: URL(string: "https://github.com/qayshp/TeachingTimer/blob/main/docs/PRIVACY.md")!)
            }
            Section("Support") {
                Text("teachingtimer@qays.net").textSelection(.enabled)
                Text("A description and approximate incident time are enough to start. Do not post raw reports publicly.")
            }
        }.navigationTitle("About & privacy")
    }
}

struct SupportMail: UIViewControllerRepresentable {
    let data: Data?
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(dismiss: { dismiss() }) }
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients(["teachingtimer@qays.net"])
        controller.setSubject(data == nil ? "Teaching Timer support" : "Teaching Timer diagnostic report")
        controller.setMessageBody("Please describe what happened and approximately when:\n\n", isHTML: false)
        if let data {
            controller.addAttachmentData(data, mimeType: "application/json", fileName: DiagnosticInbox.fileName)
        }
        return controller
    }
    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}
    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: () -> Void
        init(dismiss: @escaping () -> Void) { self.dismiss = dismiss }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) { dismiss() }
    }
}
