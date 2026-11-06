// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

@main
struct DiagnosticReportChecks {
    typealias Export = DiagnosticReport
    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static let metadata = Export.Metadata(version: "1.0", build: "261106.0900.1",
        revision: "5d57903", osVersion: "27.2")

    static func event(_ offset: Double = 0, _ name: String = "runtime_started",
                      _ details: [String: String] = [:]) -> Export.Event {
        Export.Event(timestamp: now.addingTimeInterval(offset), event: name, details: details)
    }

    static func bytes(_ rows: [Export.Event]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(rows)
    }

    static func prepare(_ rows: [Export.Event], window: Export.Window = .lastTwoHours) throws -> Export.Prepared {
        try Export.build(snapshots: [.runtime: .init(data: bytes(rows), status: .available)],
            metadata: metadata, window: window, cutoff: now)
    }

    static func expectFailure(_ expected: Export.Failure, _ body: () throws -> Void) {
        do { try body(); assertionFailure("Expected \(expected)") }
        catch let failure as Export.Failure { assert(failure == expected) }
        catch { assertionFailure("Unexpected error type") }
    }

    static func main() throws {
        // One inclusive cutoff/window is shared by all stores, not one Date()
        // per read. A backward correction excludes future events without moving
        // them or assuming array order is timestamp order.
        let rows = [event(-7201), event(-7200), event(-1), event(), event(1), event(-300)]
        let recent = try prepare(rows)
        assert(recent.report.schemaVersion == 1)
        assert(recent.report.journals.map(\.source) == [.runtime, .interface, .landmarks])
        let runtime = recent.report.journals[0]
        assert(runtime.status == .available && runtime.availableEventCount == 6)
        assert(runtime.events.count == 4 && runtime.excludedBeforeWindow == 1 && runtime.excludedAfterCutoff == 1)
        assert(runtime.actualStart == now.addingTimeInterval(-7200) && runtime.actualEnd == now)
        assert(recent.report.actualStart == runtime.actualStart && recent.report.eventCount == 4)
        assert(recent.report.requestedStart == now.addingTimeInterval(-7200))
        assert(recent.report.journals[1].status == .missing && recent.report.journals[2].status == .missing)
        let day = try prepare([event(-86401), event(-86400), event(-7201)], window: .lastDay)
        assert(day.report.eventCount == 2 && day.report.requestedStart == now.addingTimeInterval(-86400))
        let all = try prepare(rows, window: .allRetained)
        assert(all.report.eventCount == 5 && all.report.requestedStart == nil)
        let noEvents = try prepare([])
        assert(noEvents.report.eventCount == 0 && noEvents.report.actualStart == nil)

        // In-memory snapshots preserve fractions on both inclusive boundaries.
        // Encoding before filtering would round these into the selected interval.
        let preciseCutoff = now.addingTimeInterval(0.5)
        let precise = try Export.build(snapshots: [.runtime: .init(events: [
            event(-7200.0), event(-7199.5), event(0.25), event(0.5), event(0.75)
        ], status: .available)], metadata: metadata, cutoff: preciseCutoff)
        assert(precise.report.eventCount == 3)
        assert(precise.report.journals[0].excludedBeforeWindow == 1)
        assert(precise.report.journals[0].excludedAfterCutoff == 1)
        assert(precise.report.journals[0].events.map(\.timestamp) == [now.addingTimeInterval(-7199.5),
            now.addingTimeInterval(0.25), now.addingTimeInterval(0.5)])
        let serialized = try JSONSerialization.jsonObject(with: precise.data) as! [String: Any]
        assert((serialized["generatedAt"] as! String).hasSuffix(".500000000Z"))
        let preciseRows = ((serialized["journals"] as! [[String: Any]])[0]["events"] as! [[String: Any]])
        assert((preciseRows[1]["timestamp"] as! String).hasSuffix(".250000000Z"))
        let typedInvalid = try Export.build(snapshots: [.runtime: .init(events: [
            Export.Event(timestamp: Date(timeIntervalSince1970: .infinity), event: "runtime_started", details: [:])
        ], status: .available)], metadata: metadata, cutoff: now)
        assert(typedInvalid.report.journals[0].status == .malformed)

        // Untrusted fields, unknown events, known fields holding private strings,
        // arbitrary error text/paths, and unknown categorical values stay local.
        let secret = "PRIVATE-name-email@example.org/🧘/secret"
        let sanitized = try prepare([
            event(0, secret, ["sceneState": "active"]),
            event(0, "runtime_invalidated", [
                "reason": "resigned_frontmost", "reasonCode": "3",
                "errorDomain": "WKExtendedRuntimeSessionErrorDomain", "errorCode": "3",
                "errorDescription": secret, "underlyingErrorDescription": secret,
                "preservedFile": secret, "newPrivateField": secret,
                "phase": "failed(\"\(secret)\")", "runtimePhase": "running",
                "sceneState": secret, "underlyingErrorDomain": secret,
                "launchID": secret, "elapsedWallSeconds": secret,
                "appStateCode": "99999999999999999999999999999999", "actualElapsed": "nan",
                "lateness": "inf", "requestedFocus": secret,
                "classScheduledStart": secret, "revision": secret
            ])
        ])
        assert(sanitized.report.journals[0].omittedEvents == 1)
        assert(sanitized.report.journals[0].omittedFields == 14)
        assert(sanitized.report.journals[0].events[0].details == [
            "reason": "resigned_frontmost", "reasonCode": "3",
            "errorDomain": "WKExtendedRuntimeSessionErrorDomain", "errorCode": "3",
            "phase": "failed", "runtimePhase": "running"
        ])
        assert(!String(decoding: sanitized.data, as: UTF8.self).contains("PRIVATE"))
        assert(!String(decoding: sanitized.data, as: UTF8.self).contains("🧘"))

        // Keep the exact known domain used by expiration-associated renewal
        // rules and event-time OS context, without accepting arbitrary text.
        let systemContext = try prepare([event(0, "runtime_invalidated", [
            "errorDomain": "RBSAssertionErrorDomain", "errorCode": "1",
            "underlyingErrorDomain": "RBSAssertionErrorDomain", "underlyingErrorCode": "1"
        ]), event(0, "app_launched", ["os": "Version 27.2 (Build 24S118)"]),
            event(0, "app_launched", ["os": "Version 27.2 (Build PRIVATE) email@example.org"])])
        assert(systemContext.report.journals[0].events[0].details["errorDomain"] == "RBSAssertionErrorDomain")
        assert(systemContext.report.journals[0].events[0].details["underlyingErrorDomain"] == "RBSAssertionErrorDomain")
        assert(systemContext.report.journals[0].events[1].details["os"] == "Version 27.2 (Build 24S118)")
        assert(systemContext.report.journals[0].events[2].details["os"] == nil)

        // UUID correlation survives across journals and alias fields without
        // sending the original identifiers. Invalid and differently cased UUIDs
        // cannot bypass remapping or produce different pseudonyms.
        let first = "ABCDEF01-2345-6789-ABCD-0123456789AB"
        let second = "00000000-0000-0000-0000-000000000002"
        let correlatedInput: [Export.Source: Export.Snapshot] = [
            .runtime: .init(data: try bytes([event(0, "start_requested", ["runtimeID": first, "launchID": second]),
                event(0, "start_requested", ["runtimeID": second, "replacesRuntimeID": first.lowercased()])]), status: .available),
            .interface: .init(data: try bytes([event(0, "volume_focus_call", ["requestID": first, "latestRequestID": first,
                "controlID": second, "runtimeID": second])]), status: .available),
            .landmarks: .init(data: try bytes([event(0, "haptic_submitted", ["runID": first, "runtimeID": first,
                "kind": "landmark", "landmark": "2", "pulse": "1", "hapticName": "directionUp",
                "scheduledElapsed": "20", "actualElapsed": "20.25", "lateness": "2.5e-1"])]), status: .available)
        ]
        let correlated = try Export.build(snapshots: correlatedInput, metadata: metadata, cutoff: now)
        assert(correlated.report.journals[0].events[0].details["runtimeID"] == "runtime-1")
        assert(correlated.report.journals[0].events[1].details["runtimeID"] == "runtime-2")
        assert(correlated.report.journals[0].events[1].details["replacesRuntimeID"] == "runtime-1")
        assert(correlated.report.journals[1].events[0].details["requestID"] == "request-1")
        assert(correlated.report.journals[1].events[0].details["latestRequestID"] == "request-1")
        assert(correlated.report.journals[2].events[0].details["runtimeID"] == "runtime-1")
        assert(correlated.report.journals[2].events[0].details["runID"] == "count-1")
        assert(correlated.report.journals[2].events[0].details["lateness"] == "0.25")
        assert(!String(decoding: correlated.data, as: UTF8.self).contains(first))
        let reverseInput = Dictionary(uniqueKeysWithValues: correlatedInput.sorted { $0.key.rawValue > $1.key.rawValue })
        let repeated = try Export.build(snapshots: reverseInput, metadata: metadata, cutoff: now)
        assert(correlated.data == repeated.data)

        // Parsing failures and disk/writer uncertainty are explicit. Available
        // pending entries remain useful even when older saved history is corrupt.
        let incomplete = try Export.build(snapshots: [
            .runtime: .init(data: Data("not JSON 🧘".utf8), status: .available),
            .interface: .init(data: try bytes([event(0, "luminance_changed", ["luminanceReduced": "true"])]),
                status: .unreadable, pendingEventCount: 1, lastWriteFailed: true),
            .landmarks: .init(status: .writeFailed, lastWriteFailed: true)
        ], metadata: metadata, cutoff: now)
        assert(incomplete.report.journals.map(\.status) == [.malformed, .unreadable, .writeFailed])
        assert(incomplete.report.eventCount == 1)
        assert(incomplete.report.journals[1].pendingEventCount == 1 && incomplete.report.journals[1].lastWriteFailed)
        let missingData = try Export.build(snapshots: [.runtime: .init(status: .available)], metadata: metadata, cutoff: now)
        assert(missingData.report.journals[0].status == .unreadable)
        let oversizedSource = try Export.build(snapshots: [.runtime: .init(data: Data(repeating: 0x20, count: 32 * 1024 * 1024 + 1),
            status: .available)], metadata: metadata, cutoff: now)
        assert(oversizedSource.report.journals[0].status == .oversized && oversizedSource.report.eventCount == 0)
        for bad in ["{}", "[1]", "[{\"timestamp\":\"not a date\",\"event\":\"runtime_started\",\"details\":{}}]",
                    "[{\"timestamp\":\"2026-01-01T00:00:00Z\",\"event\":\"runtime_started\",\"details\":{\"reasonCode\":3}}]"] {
            let result = try Export.build(snapshots: [.runtime: .init(data: Data(bad.utf8), status: .available)], metadata: metadata, cutoff: now)
            assert(result.report.journals[0].status == .malformed)
        }
        let extraTopLevel = Data("[{\"timestamp\":\"2026-01-01T00:00:00Z\",\"event\":\"runtime_started\",\"details\":{},\"privateExtra\":\"PRIVATE\"}]".utf8)
        let topLevel = try Export.build(snapshots: [.runtime: .init(data: extraTopLevel, status: .available)], metadata: metadata, window: .allRetained, cutoff: now)
        assert(topLevel.report.eventCount == 1 && !String(decoding: topLevel.data, as: UTF8.self).contains("PRIVATE"))

        expectFailure(.invalidCutoff) { _ = try Export.build(snapshots: [:], metadata: metadata, cutoff: Date(timeIntervalSince1970: .nan)) }
        expectFailure(.invalidMetadata) { _ = try Export.build(snapshots: [:], metadata: .init(version: "1.0", build: secret, revision: "unknown", osVersion: "27.2"), cutoff: now) }
        expectFailure(.invalidSnapshot) { _ = try Export.build(snapshots: [.runtime: .init(status: .available, pendingEventCount: -1)], metadata: metadata, cutoff: now) }

        // Output limits are measured after UTF-8 encoding, never by dropping the
        // oldest events. A realistic large journal reports an actionable failure.
        let largeRows = (0..<20_000).map { _ in event(0, "haptic_submitted", [
            "kind": "landmark", "landmark": "6", "pulse": "6", "count": "6", "hapticType": "7",
            "hapticName": "directionUp", "scheduledElapsed": "64", "actualElapsed": "64.25", "lateness": "0.25"])
        }
        do { _ = try prepare(largeRows); assertionFailure("Expected size rejection") }
        catch Export.Failure.tooLarge(let bytes, let limit) { assert(bytes > limit && limit == 2 * 1024 * 1024) }

        // Builder accepts immutable snapshots only: the original bytes and
        // unrelated local files are untouched; no transport is selected or sent.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("RuntimeDiagnostics.json")
        let original = try bytes(rows)
        try original.write(to: url)
        let preserved = try Export.build(snapshots: [.runtime: .init(data: Data(contentsOf: url), status: .available)], metadata: metadata, cutoff: now)
        assert(preserved.data == recent.data)
        let after = try Data(contentsOf: url)
        assert(after == original)
        print("PASS: diagnostic report windows/cutoff, source status, strict redaction, ID correlation, deterministic encoding, malformed/oversized inputs, output limit and unchanged source")
    }
}
