// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

@main struct DiagnosticRequestChecks {
    @MainActor static func main() async {
        // New activity must appear next to Check connection even if the wall
        // clock moves backward. Rows retain their identity as newer ones arrive.
        var history = DiagnosticConnectionHistory()
        precondition(history.entries.isEmpty)
        history.record("20:01 · First event")
        let firstEntry = history.entries[0]
        history.record("20:00 · Second event")
        let secondEntry = history.entries[0]
        precondition(history.entries.map(\.text) == ["20:00 · Second event", "20:01 · First event"])
        precondition(history.entries[1] == firstEntry)
        history.record("20:00 · Second event")
        precondition(history.entries[0].id != secondEntry.id,
                     "Identical event text must still have distinct row identities")
        precondition(history.entries[1] == secondEntry && history.entries[2] == firstEntry)
        var bounded = DiagnosticConnectionHistory()
        for number in 1...25 {
            bounded.record("Event \(number)")
            let oldest = max(1, number - DiagnosticConnectionHistory.capacity + 1)
            precondition(bounded.entries.map(\.text) == stride(from: number, through: oldest, by: -1).map { "Event \($0)" })
            precondition(bounded.entries.count == min(number, DiagnosticConnectionHistory.capacity))
        }
        let retained = bounded.entries
        bounded.record("Event 26")
        precondition(bounded.entries[0].text == "Event 26")
        precondition(Array(bounded.entries.dropFirst()) == Array(retained.dropLast()),
                     "Prepending must preserve retained row identities and evict only the oldest event")
        for reason in ["unknown", "update-required", "invalid-request", "invalid-window"] {
            precondition(DiagnosticRequest.failureMessage(reason: reason).contains("both devices"),
                         "A protocol mismatch needs an update, not a retry loop")
        }
        precondition(DiagnosticRequest.failureMessage(reason: "preparation-failed").contains("Watch Help"))
        precondition(!DiagnosticRequest.failureMessage(reason: "future-unrecognized-error").contains("future-unrecognized-error"))
        var pending = DiagnosticRequest.Pending()
        let first = pending.begin()!
        precondition(pending.begin() == nil, "Duplicate requests must be blocked")
        precondition(!pending.finish(UUID()))
        precondition(!pending.finish(nil), "Unsolicited files must not finish a request")
        precondition(pending.finish(first))
        let second = pending.begin()!
        precondition(!pending.finish(first), "Late receipt, error or timeout must not finish a new request")
        precondition(pending.id == second)
        precondition(pending.finish(second))
        precondition(!pending.finish(second), "Completion must be idempotent")
        let file = URL(fileURLWithPath: "/synthetic-report.json")
        var events: [String] = []
        for window in DiagnosticReportFormat.Window.allCases {
            let result = await DiagnosticRequest.enqueue(window: window, prepare: { requested in
                precondition(requested == window)
                events.append("prepare")
                await Task.yield()
                events.append("prepared")
                return file
            }, send: { url in
                precondition(url == file)
                events.append("queued")
                return true
            })
            precondition(result == .queued)
            precondition(events == ["prepare", "prepared", "queued"])
            events.removeAll()
        }
        enum Failure: Error { case synthetic }
        let failed = await DiagnosticRequest.enqueue(window: .lastDay, prepare: { _ in throw Failure.synthetic }, send: { _ in
            preconditionFailure("Failed preparation must never submit a file")
        })
        precondition(failed == .preparationFailed)
        let unavailable = await DiagnosticRequest.enqueue(window: .allRetained, prepare: { _ in file }, send: { _ in false })
        precondition(unavailable == .transportNotReady)
        precondition(DiagnosticReportFormat.Window(rawValue: "invalid") == nil)
        let cutoff = Date(timeIntervalSince1970: 1_800_000_000)
        let eventsByAge = [0, 7_201, 86_401].map { age in
            DiagnosticReport.Event(timestamp: cutoff.addingTimeInterval(-Double(age)),
                                   event: "runtime_started", details: [:])
        }
        let requests: [(String, DiagnosticReportFormat.Window, Int)] = [
            ("lastTwoHours", .lastTwoHours, 1),
            ("lastDay", .lastDay, 2),
            ("allRetained", .allRetained, 3),
        ]
        for (wireValue, expectedWindow, count) in requests {
            let window = DiagnosticReportFormat.Window(rawValue: wireValue)!
            precondition(window == expectedWindow)
            let report = try! DiagnosticReport.build(
                snapshots: [.runtime: .init(events: eventsByAge, status: .available)],
                metadata: .init(version: "1", build: "42", revision: "abcdef0", osVersion: "27.2"),
                window: window, cutoff: cutoff)
            let serialized = try! JSONSerialization.jsonObject(with: report.data) as! [String: Any]
            precondition(serialized["window"] as? String == wireValue, "Keep prior builds and saved reports compatible")
            let summary = try! DiagnosticInbox.summary(report.data)
            precondition(summary.window == window && summary.events == count)
            precondition(summary.build == "42" && abs(summary.generatedAt.timeIntervalSince(cutoff)) < 0.001)
        }
        let journals: [[String: Any]] = ["runtime", "interface", "landmarks"].map { ["source": $0, "events": []] }
        let valid: [String: Any] = ["schemaVersion": 1, "generatedAt": "2026-11-12T08:00:00.000Z", "metadata": ["build": "test"], "window": "lastDay", "eventCount": 0, "journals": journals]
        let data = try! JSONSerialization.data(withJSONObject: valid)
        precondition(try! DiagnosticInbox.summary(data).window == .lastDay)
        for (key, value) in [("schemaVersion", true), ("schemaVersion", 2), ("eventCount", true), ("eventCount", -1), ("eventCount", 1), ("eventCount", 0.5), ("window", "unknown"), ("generatedAt", "yesterday"), ("metadata", [:]), ("journals", [])] as [(String, Any)] {
            var invalid = valid
            invalid[key] = value
            do {
                _ = try DiagnosticInbox.summary(JSONSerialization.data(withJSONObject: invalid))
                preconditionFailure("Accepted invalid report field: " + key)
            } catch {}
        }
        for sources in [["runtime", "runtime", "landmarks"], ["runtime", "interface", "other"]] {
            var invalid = valid
            invalid["journals"] = sources.map { ["source": $0, "events": []] as [String: Any] }
            do { _ = try DiagnosticInbox.summary(JSONSerialization.data(withJSONObject: invalid)); preconditionFailure("Accepted incorrect journal sources") } catch {}
        }
        for invalid in [Data(), Data("broken".utf8), Data(repeating: 32, count: DiagnosticReportFormat.maximumBytes + 1)] {
            do { _ = try DiagnosticInbox.summary(invalid); preconditionFailure("Accepted invalid report") } catch {}
        }
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! data.write(to: temporary)
        precondition(try! DiagnosticInbox.read(temporary).data == data)
        try! Data("broken".utf8).write(to: temporary)
        do { _ = try DiagnosticInbox.read(temporary); preconditionFailure("Accepted corrupt restored report") } catch {}
        try! FileManager.default.removeItem(at: temporary)

        try! FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        var older = valid
        older["window"] = "lastTwoHours"
        let olderData = try! JSONSerialization.data(withJSONObject: older)
        let legacy = temporary.appendingPathComponent(DiagnosticInbox.fileName)
        try! olderData.write(to: legacy)
        let store = DiagnosticInbox.Store(applicationSupport: temporary)
        let reviewed = store.current!
        precondition(reviewed.data == olderData && reviewed.summary.window == .lastTwoHours)
        precondition(!FileManager.default.fileExists(atPath: legacy.path), "Migration must remove the legacy report")

        let exports = DiagnosticInbox.Exports(temporaryDirectory: temporary)
        let now = Date()
        let staged = try! exports.stage(reviewed, now: now.addingTimeInterval(-48 * 60 * 60))
        let incoming = temporary.appendingPathComponent("incoming.json")
        try! data.write(to: incoming)
        let replacement = try! DiagnosticInbox.read(incoming)
        try! store.install(replacement)
        precondition(reviewed.data == olderData, "An in-flight export must keep its reviewed report bytes")
        let stagedReplacement = try! exports.stage(replacement, now: now)
        precondition(staged.url != stagedReplacement.url && staged.url.lastPathComponent == DiagnosticInbox.fileName)
        precondition(try! Data(contentsOf: staged.url) == olderData, "An aged but active share must keep the selected file")
        precondition(try! Data(contentsOf: stagedReplacement.url) == data)
        exports.finish(staged)
        precondition(!FileManager.default.fileExists(atPath: staged.url.path))
        precondition(FileManager.default.fileExists(atPath: stagedReplacement.url.path))
        precondition(store.current?.id == replacement.id && store.current?.summary.window == .lastDay)
        precondition(try! !store.delete(reviewed.id), "Stale confirmation must preserve a newer report")
        precondition(DiagnosticInbox.Store(applicationSupport: temporary).current?.data == data)

        let duplicate = try! DiagnosticInbox.read(incoming)
        precondition(duplicate.summary == replacement.summary && duplicate.id != replacement.id)
        try! store.install(duplicate)
        precondition(try! !store.delete(replacement.id), "Identical summaries must not stand in for receipt identity")
        precondition(try! store.delete(duplicate.id))
        precondition(store.current == nil && DiagnosticInbox.Store(applicationSupport: temporary).current == nil)
        precondition(try! Data(contentsOf: stagedReplacement.url) == data, "Deleting an inbox report must leave its active share readable")
        let concurrentExports = (0..<7).map { _ in try! exports.stage(replacement, now: now) }
        do { _ = try exports.stage(replacement, now: now); preconditionFailure("Export cache must enforce its cap") } catch {}
        for export in concurrentExports { exports.finish(export) }
        exports.finish(stagedReplacement)
        let abandoned = try! DiagnosticInbox.Exports(temporaryDirectory: temporary)
            .stage(reviewed, now: now.addingTimeInterval(-48 * 60 * 60))
        _ = DiagnosticInbox.Exports(temporaryDirectory: temporary)
        precondition(!FileManager.default.fileExists(atPath: abandoned.url.path), "An expired orphan must be cleaned after restart")

        // A blocked migration/save leaves the existing report available.
        let blockedSupport = temporary.appendingPathComponent("blocked-support", isDirectory: true)
        try! FileManager.default.createDirectory(at: blockedSupport, withIntermediateDirectories: true)
        try! olderData.write(to: blockedSupport.appendingPathComponent(DiagnosticInbox.fileName))
        try! Data().write(to: blockedSupport.appendingPathComponent("ReceivedDiagnostics"))
        let blockedStore = DiagnosticInbox.Store(applicationSupport: blockedSupport)
        let preserved = blockedStore.current!
        precondition(preserved.data == olderData)
        do { try blockedStore.install(replacement); preconditionFailure("Storage should fail at the blocked path") } catch {}
        precondition(blockedStore.current?.id == preserved.id)
        precondition(DiagnosticInbox.Store(applicationSupport: blockedSupport).current?.data == olderData)
        print("Diagnostic requests, bounded history, retry isolation, inbox snapshots, file exports, migration and stale deletion checks passed")
    }
}
