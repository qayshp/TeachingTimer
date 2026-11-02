// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Stateless clock-face sampling. Raw timeline/class/deadline dates stay intact.
enum WallClockDisplay {
    /// Timeline frames have been observed one representable value below an
    /// intended integer second. Calendar then shows the preceding second even
    /// though conversion to Unix time rounds away that difference. Normalize
    /// only the integer and its immediate reference-epoch neighbors; ordinary
    /// fractions, genuine clock corrections, and future frames remain intact.
    static func normalizedDate(_ date: Date) -> Date {
        let reference = date.timeIntervalSinceReferenceDate
        guard reference.isFinite else { return date }
        let boundary = reference.rounded()
        guard reference == boundary || reference == boundary.nextDown || reference == boundary.nextUp else {
            return date
        }
        return Date(timeIntervalSinceReferenceDate: boundary)
    }

    static func components(at date: Date, calendar: Calendar = .current) -> DateComponents {
        calendar.dateComponents([.minute, .second], from: normalizedDate(date))
    }

    /// The class perimeter shares the hands' integer-second display sample.
    /// Floor in the reference epoch so Unix conversion cannot widen the rule.
    static func wholeSecondDate(_ date: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: normalizedDate(date).timeIntervalSinceReferenceDate.rounded(.down))
    }
}
