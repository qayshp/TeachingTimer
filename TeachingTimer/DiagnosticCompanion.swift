// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import WatchConnectivity

/// Optional support transport. Never owns teaching state or sends to a server.
@MainActor
final class DiagnosticCompanion: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = DiagnosticCompanion()
    @Published var status = "Checking companion…"
    @Published var installed: Bool?
    var prepareReport: (@MainActor () async throws -> URL)?
    private var preparing = false
    @Published var received: URL?
    private var transport: WCSession?
    var pendingFiles: Set<URL> { Set(transport?.outstandingFileTransfers.map { $0.file.fileURL } ?? []) }


    override private init() {
        super.init()
#if os(iOS)
        if let folder = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            let url = folder.appendingPathComponent("TeachingTimer-diagnostics.json")
            if FileManager.default.fileExists(atPath: url.path) { received = url }
        }
#endif
        guard WCSession.isSupported() else { status = "Companion connection unavailable."; return }
        let session = WCSession.default
        transport = session
        session.delegate = self
        session.activate()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(8))
            if self.installed == nil { self.status = "Couldn’t check companion. Tap Check connection to retry." }
        }
    }

    func checkConnection() {
        guard let transport else { return }
        if transport.activationState == .activated { updateInstallation() }
        else { transport.activate() }
    }

    private func updateInstallation() {
        guard let transport, transport.activationState == .activated else { return }
#if os(watchOS)
        installed = transport.isCompanionAppInstalled
        status = installed == true ? "Ready to send to iPhone." : "Install Teaching Timer on your iPhone to email reports. The phone app is optional for teaching."
#else
        installed = transport.isWatchAppInstalled
        status = installed == true ? "Ready to request a report." : "Install Teaching Timer on your paired Watch."
#endif
    }

    func requestReport() {
        guard let transport, transport.activationState == .activated, installed == true else {
            status = "Companion is not ready. Try again after opening both apps."; return
        }
        guard transport.isReachable else {
            status = "Open Teaching Timer on your Watch, then try again."; return
        }
        transport.sendMessage(["request": "diagnostics-v1"], replyHandler: { response in
            let accepted = response["received"] as? Bool == true
            Task { @MainActor in self.status = accepted ? "Request delivered. Waiting for report; use Watch Help if it does not arrive." : "Open the Watch app and finish any pending transfer, then retry." }
        }, errorHandler: { _ in
            Task { @MainActor in self.status = "Couldn’t contact Watch. Open the app there and retry." }
        })
    }

    func send(_ url: URL) {
        guard let transport, transport.activationState == .activated, installed == true else {
            status = "Install and open the optional iPhone app, then retry."; return
        }
        guard transport.outstandingFileTransfers.isEmpty else {
            status = "A report is already waiting to transfer."; return
        }
        transport.transferFile(url, metadata: ["kind": "diagnostics-v1"])
        status = "Waiting to transfer to iPhone…"
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if error != nil { self.status = "Couldn’t check companion. Try reopening the app." }
            else { self.updateInstallation() }
        }
    }
#if os(watchOS)
    nonisolated func sessionCompanionAppInstalledDidChange(_ session: WCSession) {
        Task { @MainActor in self.updateInstallation() }
    }
#else
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.updateInstallation() }
    }
#endif
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard message["request"] as? String == "diagnostics-v1" else { replyHandler(["received": false]); return }
        replyHandler(["received": true])
        Task { @MainActor in
            guard !self.preparing, self.pendingFiles.isEmpty, let prepare = self.prepareReport else {
                self.status = "Open the Watch app before requesting a report."
                return
            }
            self.preparing = true
            defer { self.preparing = false }
            do { self.send(try await prepare()) }
            catch { self.status = "Couldn’t prepare report. Try from Watch Help." }
        }
    }

    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        let failed = error != nil
        Task { @MainActor in
            self.status = failed ? "Transfer failed. Prepare and send again." : "Transfer completed. Open Teaching Timer on iPhone to email the report."
        }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // Copy before returning: Watch Connectivity removes its temporary file.
        guard file.metadata?["kind"] as? String == "diagnostics-v1" else { return }
        do {
            let values = try file.fileURL.resourceValues(forKeys: [.fileSizeKey])
            guard let size = values.fileSize, size > 0, size <= 2 * 1024 * 1024 else { throw CocoaError(.fileReadCorruptFile) }
            let data = try Data(contentsOf: file.fileURL)
            guard let report = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  report["schemaVersion"] as? Int == 1,
                  report["journals"] is [[String: Any]] else { throw CocoaError(.fileReadCorruptFile) }
            let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let destination = folder.appendingPathComponent("TeachingTimer-diagnostics.json")
            try data.write(to: destination, options: [.atomic, .completeFileProtection])
            var excluded = destination
            var resource = URLResourceValues(); resource.isExcludedFromBackup = true
            try excluded.setResourceValues(resource)
            Task { @MainActor in self.received = destination; self.status = "Report received. Review it before emailing support." }
        } catch {
            Task { @MainActor in self.status = "Couldn’t save the report. Request it again." }
        }
    }
}
