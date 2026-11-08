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
    @State private var composing = false
    @State private var attachment: Data?
    @State private var notice = ""
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Teaching Timer").font(.title2)
                    Text("Optional support for your independent Watch app. Teaching works without this iPhone app.")
                }
                Section("Diagnostics") {
                    Text(companion.status)
                    Button("Check connection") { companion.checkConnection() }
                    Button("Get diagnostics from Watch") { companion.requestReport() }
                        .disabled(companion.installed != true)
                    Text("This requests the last two hours of diagnostics from your Watch. Keep its app open. Reports contain usage timestamps and diagnostic events. Nothing is emailed automatically.")
                    if let url = companion.received {
                        Button("Email support") {
                            do {
                                attachment = try Data(contentsOf: url)
                                if MFMailComposeViewController.canSendMail() { composing = true }
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
                Section("Privacy") {
                    Text("Transfers stay between your paired devices. Email is sent only when you confirm it in the composer. The latest received report replaces the previous one and is excluded from device backup. Delete it when finished. Recipient copies are separate.")
                    Text("Support: teachingtimer@qays.net")
                }
            }
            .navigationTitle("Watch support")
            .sheet(isPresented: $composing) {
                if let attachment { SupportMail(data: attachment) }
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
