// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import CoreFoundation

/// Typed request values and queue outcomes shared by phone and Watch.
enum DiagnosticRequest {
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
    static func enqueue(window: DiagnosticReportFormat.Window,
                        prepare: @MainActor (DiagnosticReportFormat.Window) async throws -> URL,
                        send: @MainActor (URL) -> Bool) async -> Outcome {
        do {
            let file = try await prepare(window)
            return send(file) ? .queued : .transportNotReady
        } catch { return .preparationFailed }
    }
}

/// Local connection activity is shown in arrival order, newest first. Text
/// includes wall time for reading, but clock changes must not reorder records.
struct DiagnosticConnectionHistory {
    static let capacity = 20
    struct Entry: Identifiable, Equatable {
        let id = UUID()
        let text: String
    }
    private(set) var entries: [Entry] = []

    mutating func record(_ text: String) {
        entries.insert(Entry(text: text), at: 0)
        if entries.count > Self.capacity { entries.removeLast(entries.count - Self.capacity) }
    }
}

/// Validate received and restored files before offering them for email.
enum DiagnosticInbox {
    // Host and Simulator filesystems cannot provide iPhone data protection.
    private static let writingOptions: Data.WritingOptions = {
        #if os(iOS) && !targetEnvironment(simulator)
        [.atomic, .completeFileProtection]
        #else
        .atomic
        #endif
    }()
    static let fileName = "TeachingTimer-diagnostics.json"

    struct Receipt: Identifiable, Sendable {
        let id = UUID()
        let data: Data
        let summary: Summary

        fileprivate init(data: Data, summary: Summary) {
            self.data = data
            self.summary = summary
        }
    }

    struct Summary: Equatable, Sendable {
        let build: String
        let window: DiagnosticReportFormat.Window
        let events: Int
        let generatedAt: Date
    }
    static func summary(_ data: Data) throws -> Summary {
        guard !data.isEmpty, data.count <= DiagnosticReportFormat.maximumBytes,
              let report = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let schema = report["schemaVersion"] as? NSNumber,
              CFGetTypeID(schema) != CFBooleanGetTypeID(), schema == 1,
              let timestamp = report["generatedAt"] as? String,
              let generatedAt = date(timestamp),
              let metadata = report["metadata"] as? [String: String],
              let build = metadata["build"], !build.isEmpty,
              let raw = report["window"] as? String,
              let window = DiagnosticReportFormat.Window(rawValue: raw),
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
    static func read(_ url: URL) throws -> Receipt {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= DiagnosticReportFormat.maximumBytes else { throw CocoaError(.fileReadCorruptFile) }
        let data = try Data(contentsOf: url)
        return try Receipt(data: data, summary: summary(data))
    }

#if !os(watchOS)
    /// File-based export uses separate, protected snapshots in the app's temp
    /// directory. Only the share completion can retire an active snapshot.
    @MainActor
    final class Exports {
        private static let capacity = 8
        private static let retention: TimeInterval = 24 * 60 * 60
        private let folder: URL
        private var active: Set<UUID> = []

        struct Staged: Identifiable {
            let id: UUID
            let url: URL
            fileprivate let directory: URL
        }

        init(temporaryDirectory: URL) {
            folder = temporaryDirectory.appendingPathComponent("TeachingTimerDiagnosticExports", isDirectory: true)
            _ = try? purgeExpired(now: Date())
        }

        func stage(_ report: Receipt, now: Date = Date()) throws -> Staged {
            let seconds = now.timeIntervalSince1970
            guard seconds.isFinite, (0..<Double(Int64.max)).contains(seconds) else { throw CocoaError(.fileWriteUnknown) }
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            guard try purgeExpired(now: now) < Self.capacity else { throw CocoaError(.fileWriteOutOfSpace) }

            let id = UUID()
            let directory = folder.appendingPathComponent("\(Int64(seconds))-\(id.uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
            let url = directory.appendingPathComponent(DiagnosticInbox.fileName)
            do {
                try report.data.write(to: url, options: DiagnosticInbox.writingOptions)
            } catch {
                try? FileManager.default.removeItem(at: directory)
                throw error
            }
            active.insert(id)
            return Staged(id: id, url: url, directory: directory)
        }

        func finish(_ report: Staged) {
            guard active.remove(report.id) != nil else { return }
            try? FileManager.default.removeItem(at: report.directory)
        }

        private func purgeExpired(now: Date) throws -> Int {
            let directoryKeys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]
            let values = try folder.resourceValues(forKeys: directoryKeys)
            guard values.isDirectory == true, values.isSymbolicLink != true else { throw CocoaError(.fileWriteUnknown) }
            let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: Array(directoryKeys))
            var count = 0
            for url in files {
                let components = url.lastPathComponent.split(separator: "-", maxSplits: 1)
                guard components.count == 2, let epoch = Int64(components[0]), epoch >= 0,
                      let id = UUID(uuidString: String(components[1])) else { continue }
                let values = try url.resourceValues(forKeys: directoryKeys)
                guard values.isDirectory == true, values.isSymbolicLink != true else { continue }
                if !active.contains(id), now.timeIntervalSince1970 - Double(epoch) > Self.retention {
                    try FileManager.default.removeItem(at: url)
                } else {
                    count += 1
                }
            }
            return count
        }
    }
#endif

    /// A single durable receipt. The delegate writes before returning, while
    /// the UI can delete. The lock keeps the file and its identity in sync.
    final class Store: @unchecked Sendable {
        private let lock = NSLock()
        private let folder: URL
        private let destination: URL
        private let legacy: URL
        private var receipt: Receipt?

        init(applicationSupport: URL) {
            folder = applicationSupport.appendingPathComponent("ReceivedDiagnostics", isDirectory: true)
            destination = folder.appendingPathComponent(DiagnosticInbox.fileName)
            legacy = applicationSupport.appendingPathComponent(DiagnosticInbox.fileName)
            if let saved = try? DiagnosticInbox.read(destination) {
                receipt = saved
                try? removeIfPresent(legacy)
            } else if let previous = try? DiagnosticInbox.read(legacy) {
                // Keep the original readable if migration fails. A later save
                // or explicit deletion can clean up the legacy path.
                receipt = previous
                try? install(previous)
            }
        }

        var current: Receipt? { lock.withLock { receipt } }

        func install(_ report: Receipt) throws {
            try lock.withLock {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                var excluded = folder
                var resource = URLResourceValues()
                resource.isExcludedFromBackup = true
                try excluded.setResourceValues(resource)
                try report.data.write(to: destination, options: DiagnosticInbox.writingOptions)
                receipt = report
                try? removeIfPresent(legacy)
            }
        }

        func delete(_ id: UUID) throws -> Bool {
            try lock.withLock {
                guard receipt?.id == id else { return false }
                try removeIfPresent(legacy)
                try removeIfPresent(destination)
                receipt = nil
                return true
            }
        }

        private func removeIfPresent(_ url: URL) throws {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
    }
}
