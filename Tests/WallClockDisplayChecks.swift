// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

@main
struct WallClockDisplayChecks {
    static func main() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        var pacific = utc
        pacific.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        var kathmandu = utc
        kathmandu.timeZone = TimeZone(identifier: "Asia/Kathmandu")!

        // Immutable value captured in the isolated Watch TimelineView probe:
        // Unix epoch logging showed 1793658035, but Calendar rendered second 34.
        let capturedBits: UInt64 = 0x41c84ca2197fffff
        let captured = Date(timeIntervalSinceReferenceDate: Double(bitPattern: capturedBits))
        let expected = Date(timeIntervalSince1970: 1_793_658_035)
        precondition(captured.timeIntervalSinceReferenceDate == expected.timeIntervalSinceReferenceDate.nextDown)
        precondition(WallClockDisplay.normalizedDate(captured) == expected)
        precondition(WallClockDisplay.components(at: captured, calendar: utc).second == 35)
        precondition(WallClockDisplay.wholeSecondDate(captured) == expected)
        precondition(captured.timeIntervalSinceReferenceDate.bitPattern == capturedBits)

        let iso = ISO8601DateFormatter()
        let boundaries = [
            "2026-11-02T23:14:35Z", "2026-11-02T23:15:00Z",
            "2026-11-03T00:00:00Z", "2027-01-01T00:00:00Z",
            "2026-03-08T03:00:00-07:00", "2026-11-01T01:00:00-08:00",
            "2000-12-31T23:59:59Z", "2001-01-01T00:00:00Z"
        ].map { iso.date(from: $0)! } + [
            // Neighbor spacing differs across powers of two; equality with
            // nextUp/nextDown must not become a wider arithmetic tolerance.
            Date(timeIntervalSinceReferenceDate: 536_870_912),
            Date(timeIntervalSinceReferenceDate: -536_870_912)
        ]
        for boundary in boundaries {
            let reference = boundary.timeIntervalSinceReferenceDate
            for value in [reference.nextDown, reference, reference.nextUp] {
                let date = Date(timeIntervalSinceReferenceDate: value)
                precondition(WallClockDisplay.normalizedDate(date) == boundary)
                precondition(WallClockDisplay.wholeSecondDate(date) == boundary)
                for calendar in [utc, pacific, kathmandu] {
                    let expectedComponents = calendar.dateComponents([.minute, .second], from: boundary)
                    precondition(WallClockDisplay.components(at: date, calendar: calendar) == expectedComponents)
                }
            }
            // Never silently expand the correction to two ULPs or beyond.
            for value in [reference.nextDown.nextDown, reference.nextUp.nextUp] {
                let date = Date(timeIntervalSinceReferenceDate: value)
                precondition(WallClockDisplay.normalizedDate(date).timeIntervalSinceReferenceDate.bitPattern == value.bitPattern)
                precondition(WallClockDisplay.components(at: date, calendar: utc)
                    == utc.dateComponents([.minute, .second], from: date))
            }
            for fraction in [-0.999, -0.5, -0.001, 0.001, 0.25, 0.499, 0.5, 0.75, 0.999] {
                let date = boundary.addingTimeInterval(fraction)
                precondition(WallClockDisplay.normalizedDate(date) == date)
                precondition(WallClockDisplay.components(at: date, calendar: utc)
                    == utc.dateComponents([.minute, .second], from: date))
                let whole = boundary.addingTimeInterval(fraction < 0 ? -1 : 0)
                precondition(WallClockDisplay.wholeSecondDate(date) == whole)
            }
        }

        // Adjacent ticks across a minute/hour boundary use coherent hand and
        // perimeter samples; the minimum excluded value stays in the prior tick.
        let hour = iso.date(from: "2026-11-02T23:00:00Z")!
        for offset in -60...60 {
            let boundary = hour.addingTimeInterval(Double(offset))
            let reference = boundary.timeIntervalSinceReferenceDate
            let near = Date(timeIntervalSinceReferenceDate: reference.nextDown)
            let outside = Date(timeIntervalSinceReferenceDate: reference.nextDown.nextDown)
            precondition(WallClockDisplay.wholeSecondDate(near) == boundary)
            precondition(WallClockDisplay.wholeSecondDate(outside) == boundary.addingTimeInterval(-1))
            let hand = WallClockDisplay.components(at: near, calendar: utc)
            let perimeter = utc.dateComponents([.minute, .second], from: WallClockDisplay.wholeSecondDate(near))
            precondition(hand == perimeter)
        }

        // Exercise the actual class-progress calculation, including the end
        // boundary, without normalizing stored Start timestamps or schedules.
        let context = ClassContext(pressedAt: captured, calendar: utc, scheduledStart: hour)
        let originalContext = context
        for offset in [0, 1, 59, 60, 1799, 1800, 3599, 3600] {
            let boundary = hour.addingTimeInterval(Double(offset))
            let reference = boundary.timeIntervalSinceReferenceDate.nextDown
            let frame = Date(timeIntervalSinceReferenceDate: reference)
            let progress = context.progress(at: WallClockDisplay.wholeSecondDate(frame))
            let hand = WallClockDisplay.components(at: frame, calendar: utc)
            let minutePosition = (Double(hand.minute!) + Double(hand.second!) / 60) / 60
            precondition(progress == Double(offset) / 3600)
            precondition(abs(progress.truncatingRemainder(dividingBy: 1) - minutePosition) < 1e-12)
            precondition(frame.timeIntervalSinceReferenceDate.bitPattern == reference.bitPattern)
        }
        precondition(context == originalContext)
        precondition(context.initialStartPressedAt.timeIntervalSinceReferenceDate.bitPattern == capturedBits)
        precondition(context.scheduledStart == hour && context.scheduledEnd == hour.addingTimeInterval(3600))

        // Display evaluation is order-independent: true backward clock changes
        // and pre-rendered future frames are not clamped to previous renders.
        let frames = [hour.addingTimeInterval(123.25), hour.addingTimeInterval(-90.25),
                      hour.addingTimeInterval(300.75), hour.addingTimeInterval(-3600.5)]
        for frame in frames + frames.reversed() {
            precondition(WallClockDisplay.normalizedDate(frame) == frame)
            precondition(WallClockDisplay.components(at: frame, calendar: utc)
                == utc.dateComponents([.minute, .second], from: frame))
        }
        print("PASS: captured reference bits, exact/adjacent values only, ordinary fractions, minute/hour/year rollover, DST/timezones, coherent hands/class progress, untouched raw dates and real backward corrections")
    }
}
