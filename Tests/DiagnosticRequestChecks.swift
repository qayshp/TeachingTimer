// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

@main struct DiagnosticRequestChecks {
    @MainActor static func main() async {
        // The phone's request values must describe exactly the Watch builder's
        // windows. Otherwise a new selection could silently fall back to two
        // hours in the transport adapter rather than honor the user's choice.
        precondition(Set(DiagnosticRequest.Window.allCases.map(\.rawValue)) ==
                     Set(DiagnosticReport.Window.allCases.map(\.rawValue)),
                     "Phone requests and Watch reports must support the same time windows")
        precondition(DiagnosticInbox.maximumBytes == DiagnosticReport.maximumBytes,
                     "The phone must accept every report size the Watch can prepare")
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
        for window in DiagnosticRequest.Window.allCases {
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
        precondition(DiagnosticRequest.Window(rawValue: "invalid") == nil)
        for window in DiagnosticReport.Window.allCases {
            let cutoff = Date()
            let event = DiagnosticReport.Event(timestamp: cutoff, event: "runtime_started", details: [:])
            let report = try! DiagnosticReport.build(snapshots: [.runtime: .init(events: [event], status: .available)], metadata: .init(version: "1", build: "42", revision: "abcdef0", osVersion: "27.2"), window: window, cutoff: cutoff)
            let summary = try! DiagnosticInbox.summary(report.data)
            precondition(summary.window.rawValue == window.rawValue && summary.events == 1)
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
        for invalid in [Data(), Data("broken".utf8), Data(repeating: 32, count: DiagnosticInbox.maximumBytes + 1)] {
            do { _ = try DiagnosticInbox.summary(invalid); preconditionFailure("Accepted invalid report") } catch {}
        }
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! data.write(to: temporary)
        precondition(try! DiagnosticInbox.read(temporary) == data)
        try! Data("broken".utf8).write(to: temporary)
        do { _ = try DiagnosticInbox.read(temporary); preconditionFailure("Accepted corrupt restored report") } catch {}
        try! FileManager.default.removeItem(at: temporary)
        print("Diagnostic request, newest-first bounded history, retry isolation and inbox validation checks passed")
    }
}
