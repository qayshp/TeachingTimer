// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import WatchConnectivity
import OSLog

/// Optional support transport. Never owns teaching state or sends to a server.
@MainActor
final class DiagnosticCompanion: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = DiagnosticCompanion()
    @Published var status = "Checking companion…"
    @Published var installed: Bool?
    typealias Window = DiagnosticRequest.Window
    nonisolated static var build: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return "\(info["CFBundleShortVersionString"] as? String ?? "?") (\(info["CFBundleVersion"] as? String ?? "?"))"
    }
    @Published private(set) var connection = "Activating…"
    @Published private(set) var events: [String] = []
    @Published private var request = DiagnosticRequest.Pending()
    var requesting: Bool { request.id != nil }
    @Published private(set) var peerBuild: String?
    var prepareReport: (@MainActor (Window) async throws -> URL)?
    private let logger = Logger(subsystem: "net.qays.TeachingTimer", category: "DiagnosticCompanion")

    private func record(_ event: String) {
        logger.notice("\(event, privacy: .public)")
        events.append("\(Date().formatted(date: .omitted, time: .standard)) · \(event)")
        if events.count > 20 { events.removeFirst(events.count - 20) }
        guard let transport else { return }
        connection = "Activation \(transport.activationState.rawValue) · installed \(installed.map(String.init) ?? "unknown") · reachable \(transport.isReachable) · queued \(transport.outstandingFileTransfers.count)"
    }
    private var preparing = false
    @Published var received: URL?
    @Published private(set) var receivedSummary: DiagnosticInbox.Summary?
    private var transport: WCSession?
    var pendingFiles: Set<URL> { Set(transport?.outstandingFileTransfers.map { $0.file.fileURL } ?? []) }

    override private init() {
        super.init()
#if os(iOS)
        if let folder = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            let url = folder.appendingPathComponent("TeachingTimer-diagnostics.json")
            if let data = try? DiagnosticInbox.read(url) {
                received = url
                receivedSummary = try? DiagnosticInbox.summary(data)
            }
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
        record("Connection checked")
    }

    private func updateInstallation() {
        guard let transport, transport.activationState == .activated else { return }
#if os(watchOS)
        installed = transport.isCompanionAppInstalled
        if !requesting { status = installed == true ? "Ready to send to iPhone." : "Install Teaching Timer on your iPhone to email reports. The phone app is optional for teaching." }
#else
        installed = transport.isWatchAppInstalled
        if !requesting { status = installed == true ? "Ready to request a report." : "Install Teaching Timer on your paired Watch." }
#endif
    }

    func requestReport(window: Window = .lastTwoHours) {
        guard !requesting else { return }
        guard let transport, transport.activationState == .activated, installed == true else {
            status = "Companion is not ready. Try again after opening both apps."; return
        }
        guard transport.isReachable else {
            status = "Open Teaching Timer on your Watch, then try again."; return
        }
        guard let id = request.begin() else { return }
        status = "Requesting report…"
        record("Request started: \(window.rawValue)")
        transport.sendMessage(["request": "diagnostics-v2", "window": window.rawValue, "requestID": id.uuidString], replyHandler: { response in
            let accepted = response["received"] as? Bool == true
            let reason = response["reason"] as? String ?? "unknown"
            let build = response["build"] as? String
            Task { @MainActor in
                guard self.request.id == id else { return }
                self.peerBuild = build
                self.record("Watch reply: \(accepted ? "queued" : reason)")
                self.status = accepted ? "Report queued on Watch. Waiting for transfer…" : DiagnosticRequest.failureMessage(reason: reason)
                if !accepted { self.request.finish(id) }
            }
        }, errorHandler: { error in
            let code = (error as NSError).code
            Task { @MainActor in
                guard self.request.id == id else { return }
                self.record("Request failed: WC error \(code)")
                self.status = "Couldn’t contact Watch (\(code)). Open both apps and retry."
                self.request.finish(id)
            }
        })
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(60))
            guard self.request.id == id else { return }
            self.request.finish(id)
            self.status = "Report has not arrived. Check connection and retry; a queued transfer may still arrive later."
            self.record("Request wait expired; delivery unconfirmed")
        }
    }

    @discardableResult
    func send(_ url: URL, requestID: UUID? = nil) -> Bool {
        guard let transport, transport.activationState == .activated, installed == true else {
            status = "Install and open the optional iPhone app, then retry."; return false
        }
        guard transport.outstandingFileTransfers.isEmpty else {
            status = "A report is already waiting to transfer."; return false
        }
        var metadata = ["kind": "diagnostics-v1"]
        if let requestID { metadata["requestID"] = requestID.uuidString }
        transport.transferFile(url, metadata: metadata)
        status = "Waiting to transfer to iPhone…"
        record("Report queued for paired device")
        return true
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let errorCode = (error as NSError?)?.code
        Task { @MainActor in
            if errorCode != nil { self.status = "Couldn’t check companion. Try reopening the app." }
            else { self.updateInstallation() }
            self.record("Activation callback: \(activationState.rawValue), error \(errorCode.map(String.init) ?? "none")")
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
        let protocolName = message["request"] as? String
        guard protocolName == "diagnostics-v1" || protocolName == "diagnostics-v2" else {
            replyHandler(["received": false, "reason": "update-required", "build": Self.build]); return
        }
        let requestID = (message["requestID"] as? String).flatMap(UUID.init(uuidString:))
        guard protocolName != "diagnostics-v2" || requestID != nil else {
            replyHandler(["received": false, "reason": "invalid-request", "build": Self.build]); return
        }
        let windowValue = message["window"] as? String ?? Window.lastTwoHours.rawValue
        let reply = CompanionReply(replyHandler)
        Task { @MainActor in
            guard let window = Window(rawValue: windowValue) else {
                reply.finish(accepted: false, reason: "invalid-window", build: Self.build); return
            }
            guard !self.preparing, self.pendingFiles.isEmpty, let prepare = self.prepareReport else {
                self.record("Request rejected: busy or provider unavailable")
                reply.finish(accepted: false, reason: "busy-or-not-ready", build: Self.build)
                return
            }
            self.preparing = true
            defer { self.preparing = false }
            let outcome = await DiagnosticRequest.enqueue(window: window, prepare: prepare, send: { self.send($0, requestID: requestID) })
            self.record("Report request outcome: \(outcome)")
            if outcome == .preparationFailed { self.status = "Couldn’t prepare report. Try from Watch Help." }
            reply.finish(accepted: outcome == .queued, reason: outcome.rawValue, build: Self.build)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.record("Reachability changed") }
    }

    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        let failed = error != nil
        let code = (error as NSError?)?.code
        Task { @MainActor in
            self.record("Transfer finished: \(code.map(String.init) ?? "no error")")
            self.status = failed ? "Transfer failed. Prepare and send again." : "Transfer completed. Open Teaching Timer on iPhone to email the report."
        }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let requestID = (file.metadata?["requestID"] as? String).flatMap(UUID.init(uuidString:))
        // Copy before returning: Watch Connectivity removes its temporary file.
        guard file.metadata?["kind"] as? String == "diagnostics-v1" else { return }
        do {
            let data = try DiagnosticInbox.read(file.fileURL)
            let summary = try DiagnosticInbox.summary(data)
            let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let destination = folder.appendingPathComponent("TeachingTimer-diagnostics.json")
            try data.write(to: destination, options: [.atomic, .completeFileProtection])
            var excluded = destination
            var resource = URLResourceValues(); resource.isExcludedFromBackup = true
            try excluded.setResourceValues(resource)
            Task { @MainActor in
                self.received = destination
                self.receivedSummary = summary
                let matched = self.request.finish(requestID)
                self.record("Report saved; matches pending request: \(matched)")
                if !self.requesting { self.status = "Report received. Review it before emailing support." }
            }
        } catch {
            Task { @MainActor in
                if self.request.finish(requestID) || !self.requesting {
                    self.status = "Couldn’t save the report. Request it again."
                }
                self.record("Report could not be saved")
            }
        }
    }
}

/// WCSession owns the callback until handed to this box. A lock consumes it once;
/// no caller can invoke or access it concurrently across the delegate/actor hop.
private final class CompanionReply: @unchecked Sendable {
    private let lock = NSLock()
    private var callback: (([String: Any]) -> Void)?
    init(_ callback: @escaping ([String: Any]) -> Void) { self.callback = callback }
    func finish(accepted: Bool, reason: String, build: String) {
        lock.lock()
        let reply = callback
        callback = nil
        lock.unlock()
        reply?(["received": accepted, "reason": reason, "build": build])
    }
}
