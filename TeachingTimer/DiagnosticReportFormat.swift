// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// The report builder, Watch requests, and iPhone inbox share the same limits
/// and window identifiers. The raw values are part of the report format.
enum DiagnosticReportFormat {
    static let maximumBytes = 2 * 1024 * 1024

    enum Window: String, CaseIterable, Codable, Identifiable, Sendable {
        case lastTwoHours, lastDay, allRetained

        var id: String { rawValue }

        var title: String {
            switch self {
            case .lastTwoHours: "Last 2 hours"
            case .lastDay: "Last 24 hours"
            case .allRetained: "All retained events"
            }
        }

        func start(before cutoff: Date) -> Date? {
            switch self {
            case .lastTwoHours: cutoff.addingTimeInterval(-7_200)
            case .lastDay: cutoff.addingTimeInterval(-86_400)
            case .allRetained: nil
            }
        }
    }
}
