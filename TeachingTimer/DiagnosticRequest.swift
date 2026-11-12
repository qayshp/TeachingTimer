// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import CoreFoundation

/// Typed request values and queue outcomes shared by phone and Watch.
enum DiagnosticRequest {
    enum Window: String, CaseIterable, Identifiable, Sendable {
        case lastTwoHours, lastDay, allRetained
        var id: String { rawValue }
        var title: String {
            switch self {
            case .lastTwoHours: "Last 2 hours"
            case .lastDay: "Last 24 hours"
            case .allRetained: "All retained events"
            }
        }
    }

    /// Correlate replies, timeout and file receipt across retries. Old callbacks
    /// must never finish a newer request, including unsolicited Watch exports.
    struct Pending {
        private(set) var id: UUID?
        mutating func begin() -> UUID? {
            guard id == nil else { return nil }
            let value = UUID()
            id = value
            return value
        }
        @discardableResult mutating func finish(_ candidate: UUID?) -> Bool {
            guard let id, id == candidate else { return false }
            self.id = nil
            return true
        }
    }

    /// Older companions reject an unknown request without a reason. Retrying
    /// that protocol mismatch cannot help until both app versions are updated.
    static func failureMessage(reason: String) -> String {
        switch reason {
        case "unknown", "update-required", "invalid-request", "invalid-window":
            "Update Teaching Timer on both devices, then compare their versions."
        case "busy-or-not-ready":
            "Watch is busy or still opening. Keep its app open, then retry."
        case "preparation-failed":
            "Watch couldn’t prepare the report. Try from Watch Help."
        default:
            "Watch couldn’t queue the report. Check connection and retry."
        }
    }

    enum Outcome: String, Sendable {
        case queued
        case transportNotReady = "transport-not-ready"
        case preparationFailed = "preparation-failed"
    }

    @MainActor
    static func enqueue(window: Window,
                        prepare: @MainActor (Window) async throws -> URL,
                        send: @MainActor (URL) -> Bool) async -> Outcome {
        do {
            let file = try await prepare(window)
            return send(file) ? .queued : .transportNotReady
        } catch { return .preparationFailed }
    }
}

/// Validate received and restored files before offering them for email.
enum DiagnosticInbox {
    static let maximumBytes = 2 * 1024 * 1024
    struct Summary: Equatable, Sendable {
        let build: String
        let window: DiagnosticRequest.Window
        let events: Int
        let generatedAt: Date
    }
    static func summary(_ data: Data) throws -> Summary {
        guard !data.isEmpty, data.count <= maximumBytes,
              let report = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let schema = report["schemaVersion"] as? NSNumber,
              CFGetTypeID(schema) != CFBooleanGetTypeID(), schema == 1,
              let timestamp = report["generatedAt"] as? String,
              let generatedAt = date(timestamp),
              let metadata = report["metadata"] as? [String: String],
              let build = metadata["build"], !build.isEmpty,
              let raw = report["window"] as? String,
              let window = DiagnosticRequest.Window(rawValue: raw),
              let count = report["eventCount"] as? NSNumber,
              CFGetTypeID(count) != CFBooleanGetTypeID(), count.doubleValue == Double(count.intValue), count.intValue >= 0,
              let journals = report["journals"] as? [[String: Any]],
              journals.count == 3,
              Set(journals.compactMap { $0["source"] as? String }) == Set(["runtime", "interface", "landmarks"]),
              journals.allSatisfy({ $0["events"] is [[String: Any]] }),
              journals.reduce(0, { $0 + (($1["events"] as? [[String: Any]])?.count ?? 0) }) == count.intValue
        else { throw CocoaError(.fileReadCorruptFile) }
        return Summary(build: build, window: window, events: count.intValue, generatedAt: generatedAt)
    }
    private static func date(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
    static func read(_ url: URL) throws -> Data {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= maximumBytes else { throw CocoaError(.fileReadCorruptFile) }
        let data = try Data(contentsOf: url)
        _ = try summary(data)
        return data
    }
}
