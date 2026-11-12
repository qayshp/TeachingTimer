// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

@main struct DiagnosticRequestChecks {
    @MainActor static func main() async {
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
        print("Diagnostic request checks passed")
    }
}
