// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import MessageUI

@main
struct SupportApp: App {
    var body: some Scene { WindowGroup { SupportView() } }
}

struct SupportView: View {
    @ObservedObject private var companion = DiagnosticCompanion.shared
    @State private var draft: MailDraft?
    @State private var window: DiagnosticCompanion.Window = .lastTwoHours
    @Environment(\.scenePhase) private var scenePhase
    private struct MailDraft: Identifiable { let id = UUID(); let data: Data }
    @State private var notice = ""
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Teaching Timer").font(.title2)
                    Text("Version \(DiagnosticCompanion.build)").font(.caption).textSelection(.enabled)
                    Text("Optional support for your independent Watch app. Teaching works without this iPhone app.")
                }
                Section("Diagnostics") {
                    Text(companion.status)
                    Button("Check connection") { companion.checkConnection() }
                    Picker("Include", selection: $window) {
                        ForEach(DiagnosticCompanion.Window.allCases) { Text($0.title).tag($0) }
                    }.disabled(companion.requesting)
                    Button(companion.requesting ? "Waiting for Watch…" : "Get diagnostics from Watch") { companion.requestReport(window: window) }
                        .disabled(companion.installed != true || companion.requesting)
                    Text("This requests the selected diagnostic time window from your Watch. Saved history may be shorter. Keep its app open. Reports contain usage timestamps and diagnostic events. Nothing is emailed automatically.")
                    if let url = companion.received {
                        Button("Email support") {
                            do {
                                let data = try Data(contentsOf: url)
                                if MFMailComposeViewController.canSendMail() { draft = MailDraft(data: data) }
                                else { notice = "Set up an account in Apple Mail to compose support email, or share the saved report with another mail app." }
                            } catch { notice = "Couldn’t read the report. Request it again." }
                        }
                        ShareLink("Export received report…", item: url)
                        Button("Delete received report", role: .destructive) {
                            do { try FileManager.default.removeItem(at: url); companion.received = nil }
                            catch { notice = "Couldn’t delete the report. Try again." }
                        }
                    }
                    if !notice.isEmpty { Text(notice) }
                }
                Section("Connection details") {
                    Text(companion.connection).font(.caption).textSelection(.enabled)
                    if let build = companion.peerBuild { Text("Watch version \(build)").font(.caption) }
                    ForEach(Array(companion.events.enumerated()), id: \.offset) { _, event in
                        Text(event).font(.caption).textSelection(.enabled)
                    }
                }
                Section("Privacy") {
                    Text("Transfers stay between your paired devices. Email is sent only when you confirm it in the composer. The latest received report replaces the previous one and is excluded from device backup. Delete it when finished. Recipient copies are separate.")
                    Text("Support: teachingtimer@qays.net")
                }
            }
            .navigationTitle("Watch support")
            .sheet(item: $draft) { draft in SupportMail(data: draft.data) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { companion.checkConnection() }
            }
        }
    }
}

struct SupportMail: UIViewControllerRepresentable {
    let data: Data
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(dismiss: { dismiss() }) }
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients(["teachingtimer@qays.net"])
        controller.setSubject("Teaching Timer diagnostic report")
        controller.setMessageBody("Please describe what happened and approximately when:\n\n", isHTML: false)
        controller.addAttachmentData(data, mimeType: "application/json", fileName: "TeachingTimer-diagnostics.json")
        return controller
    }
    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}
    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: () -> Void
        init(dismiss: @escaping () -> Void) { self.dismiss = dismiss }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) { dismiss() }
    }
}
