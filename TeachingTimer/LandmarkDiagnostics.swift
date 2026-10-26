// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import OSLog

/// All loading, buffering, encoding and atomic disk writes happen on this queue,
/// never on the MainActor that submits the haptics. A sudden kill may lose the
/// most recent buffer; absence of an end event is not a diagnosed cancellation.
final class LandmarkDiagnostics: @unchecked Sendable {
    // A busy week: 3 classes/day, 20 counts/class, up to 45 events/count
    // (including every timing pulse late) fits below this safety cap.
    static let defaultCapacity = 20_000
    static let retentionInterval: TimeInterval = 7 * 24 * 60 * 60
    struct Event: Codable, Sendable {
        let timestamp: Date
        let event: String
        let details: [String: String]
    }
    private let queue: DispatchQueue
    private let url: URL
    private let capacity: Int
    private let retentionInterval: TimeInterval?
    private var events: [Event] = []
    private var pending: [Event] = []
    private var loaded = false
    private var flushScheduled = false
    private let log: Logger

    init(url: URL = URL.documentsDirectory.appendingPathComponent("LandmarkDiagnostics.json"), capacity: Int = LandmarkDiagnostics.defaultCapacity,
         label: String = "LandmarkJournal", retentionInterval: TimeInterval? = LandmarkDiagnostics.retentionInterval) {
        self.url = url
        self.capacity = max(1, capacity)
        self.retentionInterval = retentionInterval
        queue = DispatchQueue(label: "TeachingTimer." + label, qos: .utility)
        log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "net.qays.TeachingTimer", category: label)
    }

    func record(_ name: String, details: [String: String], at date: Date = Date(), flush: Bool = false) {
        let event = Event(timestamp: date, event: name, details: details.mapValues { String($0.prefix(1000)) })
        queue.async {
            self.pending.append(event)
            self.pending = Array(self.pending.suffix(self.capacity))
            if flush { self.writePending() }
            else if !self.flushScheduled {
                self.flushScheduled = true
                self.queue.asyncAfter(deadline: .now() + 0.25) {
                    self.flushScheduled = false
                    self.writePending()
                }
            }
        }
    }

    /// Also used by deterministic checks to wait for queued writes, off main.
    func flush() async {
        await withCheckedContinuation { continuation in
            queue.async { self.writePending(); continuation.resume() }
        }
    }

    private func writePending() {
        guard !pending.isEmpty else { return }
        do {
            if !loaded {
                if FileManager.default.fileExists(atPath: url.path) {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    do { events = try decoder.decode([Event].self, from: Data(contentsOf: url)) }
                    catch {
                        // Preserve the exact unreadable bytes before starting a
                        // new journal. If the backup fails, leave the old file
                        // untouched and retry on a later write.
                        let backup = url.deletingPathExtension()
                            .appendingPathExtension("corrupt." + UUID().uuidString + ".json")
                        try FileManager.default.copyItem(at: url, to: backup)
                        events = [Event(timestamp: Date(), event: "journal_recovered",
                            details: ["preservedFile": backup.lastPathComponent])]
                    }
                }
                loaded = true
            }
            // Trim on writes, relative to the latest submitted event rather than
            // the worker's execution time. Keep future-dated entries after a
            // backwards clock correction. A size cap still bounds that case.
            var retained = events + pending
            if let retentionInterval, let latest = pending.last {
                let cutoff = latest.timestamp.addingTimeInterval(-retentionInterval)
                retained.removeAll { $0.timestamp < cutoff }
            }
            let next = Array(retained.suffix(capacity))
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encoder.encode(next).write(to: url, options: .atomic)
            events = next
            pending.removeAll(keepingCapacity: true)
        } catch {
            log.error("Landmark journal write failed; existing history preserved: \(error.localizedDescription, privacy: .public)")
        }
    }
}
