// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

@main
struct VolumeControlDiagnosticsChecks {
    @MainActor static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("RuntimeDiagnostics.json")
        let journal = RuntimeDiagnostics(fileURL: url)
        var observed: [(String, [String: String])] = []
        let diagnostic = VolumeControlDiagnostics { event, details in
            observed.append((event, details))
            journal.record(event, details: details)
        }
        diagnostic.lastViewSnapshot = ["lastViewTimerPageSelected": "true"]
        diagnostic.created()
        let focus = diagnostic.requested(true, source: "update")
        assert(diagnostic.canInvoke(focus))
        diagnostic.willInvoke(focus)
        diagnostic.didReturn(focus)
        assert(observed.map(\.0) == ["volume_control_created", "volume_focus_requested",
                                     "volume_focus_call", "volume_focus_call_returned"])
        assert(observed[0].1["latestRequestedFocus"] == "none")
        assert(observed[3].1["requestID"] == focus.id)
        assert(observed[3].1["supersededRequest"] == "false")

        // Updating the last observed SwiftUI inputs must not emit per-frame logs.
        let eventCount = observed.count
        for _ in 0..<120 {
            diagnostic.lastViewSnapshot = ["lastViewTimerPageSelected": "false",
                                           "lastViewLuminanceReduced": "true"]
        }
        assert(observed.count == eventCount)

        // A queued focus must not steal the Crown after a later resign request.
        let pendingFocus = diagnostic.requested(true, source: "update")
        let resign = diagnostic.requested(false, source: "update")
        assert(!diagnostic.canInvoke(pendingFocus))
        diagnostic.skipped(pendingFocus)
        assert(observed.last!.0 == "volume_focus_call_skipped")
        let superseded = observed.last!.1
        assert(superseded["supersededRequest"] == "true")
        assert(superseded["requestedFocus"] == "true")
        assert(superseded["latestRequestedFocus"] == "false")
        assert(superseded["latestRequestID"] == resign.id)
        assert(superseded["lastViewTimerPageSelected"] == "false")
        assert(diagnostic.canInvoke(resign))
        diagnostic.willInvoke(resign)
        diagnostic.didReturn(resign)

        // Removal makes all queued update calls ineligible. The adapter still
        // resigns synchronously during dismantle, without using the queue gate.
        let afterRemoval = diagnostic.requested(true, source: "update")
        diagnostic.removed()
        let dismantle = diagnostic.requested(false, source: "dismantle")
        diagnostic.willInvoke(dismantle)
        diagnostic.didReturn(dismantle)
        assert(!diagnostic.canInvoke(afterRemoval))
        diagnostic.skipped(afterRemoval)
        assert(observed.last!.1["controlDismantled"] == "true")
        assert(observed.last!.1["supersededRequest"] == "true")
        assert(observed.last!.1["source"] == "update")
        assert(!observed.contains { $0.0 == "volume_focus_call" && $0.1["requestID"] == afterRemoval.id })
        assert(!observed.contains { $0.0 == "volume_focus_call" && $0.1["requestID"] == pendingFocus.id })
        for (_, fields) in observed {
            assert(fields["controlID"] == diagnostic.controlID)
            assert(fields["origin"] == "companion")
            assert(fields["actualFocus"] == "unobserved")
            assert(fields["volume"] == nil && fields["audioRoute"] == nil)
            if let delay = fields["secondsSinceRequest"] {
                assert(Double(delay)!.isFinite && Double(delay)! >= 0)
            }
        }
        let another = VolumeControlDiagnostics { _, _ in }
        assert(another.controlID != diagnostic.controlID)

        await journal.flush()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = try decoder.decode([RuntimeDiagnostics.Event].self, from: Data(contentsOf: url))
        assert(entries.map(\.event) == observed.map(\.0))
        assert(entries.map(\.details) == observed.map(\.1))
        print("PASS: volume lifecycle, stale/removed focus protection, monotonic delay, no per-frame events, persistent ordering")
    }
}
