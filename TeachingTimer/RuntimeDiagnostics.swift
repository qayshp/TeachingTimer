// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Runtime events use the same ordered, off-main writer as landmark events.
/// Record returns after queuing; a sudden process kill may lose the last events.
final class RuntimeDiagnostics: @unchecked Sendable {
    typealias Event = LandmarkDiagnostics.Event
    let fileURL: URL
    private let writer: LandmarkDiagnostics

    init(fileURL: URL = URL.documentsDirectory.appendingPathComponent("RuntimeDiagnostics.json"),
         capacity: Int = 1000) {
        self.fileURL = fileURL
        writer = LandmarkDiagnostics(url: fileURL, capacity: capacity, label: "RuntimeJournal")
    }

    func record(_ name: String, details: [String: String], at date: Date = Date()) {
        writer.record(name, details: details, at: date, flush: true)
    }

    func flush() async { await writer.flush() }
}
