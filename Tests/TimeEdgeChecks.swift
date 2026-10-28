// SPDX-License-Identifier: MPL-2.0
import Foundation

@main
struct TimeEdgeChecks {
    static func main() throws {
        let iso = ISO8601DateFormatter()
        func date(_ value: String) -> Date { iso.date(from: value)! }
        func calendar(_ zone: String) -> Calendar {
            var result = Calendar(identifier: .gregorian)
            result.timeZone = TimeZone(identifier: zone)!
            return result
        }
        let pacific = calendar("America/Los_Angeles")
        // Explicit offsets distinguish the two occurrences of 01:xx in autumn.
        for (input, expected) in [
            ("2026-03-08T01:59:59-08:00", "2026-03-08T03:00:00-07:00"),
            ("2026-11-01T01:59:59-07:00", "2026-11-01T01:00:00-08:00"),
            ("2026-11-01T01:37:00-07:00", "2026-11-01T01:30:00-07:00"),
            ("2026-11-01T01:37:00-08:00", "2026-11-01T01:30:00-08:00"),
            ("2026-12-31T23:59:59-08:00", "2027-01-01T00:00:00-08:00")
        ] {
            precondition(ClassContext.inferredStart(for: date(input), calendar: pacific) == date(expected), input)
        }
        for (start, end, minutes) in [
            ("2026-03-08T01:30:00-08:00", "2026-03-08T03:30:00-07:00", 60),
            ("2026-11-01T01:30:00-07:00", "2026-11-01T01:45:00-08:00", 75)
        ] {
            let context = ClassContext(pressedAt: date(start), durationMinutes: minutes, calendar: pacific)
            precondition(context.scheduledEnd == date(end))
            precondition(context.progress(at: context.scheduledStart.addingTimeInterval(Double(minutes) * 30)) == 0.5)
            precondition(!context.shouldRetire(at: context.retirementDate.addingTimeInterval(-0.001)))
            precondition(context.shouldRetire(at: context.retirementDate))
            // Stored instants survive a timezone change; only their display changes.
            let restored = try JSONDecoder().decode(ClassContext.self, from: JSONEncoder().encode(context))
            precondition(restored == context)
            precondition(calendar("Asia/Kathmandu").component(.minute, from: restored.scheduledEnd) == (minutes == 60 ? 15 : 30))
        }
        let kathmandu = calendar("Asia/Kathmandu")
        precondition(ClassContext.inferredStart(for: date("2026-10-27T23:43:59+05:45"), calendar: kathmandu) == date("2026-10-27T23:45:00+05:45"))
        let wall = date("2026-10-27T23:59:59Z")
        let schedule = LandmarkSchedule()
        // Future frames cross midnight. Clock corrections must not re-anchor the arc.
        for correction in [-86400.0, -3600, -2, 0, 2, 3600, 86400] {
            let now = wall.addingTimeInterval(correction)
            let frame = schedule.frame(at: now.addingTimeInterval(2), wallNow: now, elapsedNow: 28)
            precondition(frame.progress == 0.5 && frame.isVisible)
            let final = schedule.frame(at: now, wallNow: now, elapsedNow: 60)
            precondition(final.progress == 1 && final.isVisible)
            precondition(!schedule.frame(at: now, wallNow: now, elapsedNow: 64.8).isVisible)
        }
        print("Time edges passed: DST folds/gaps, year rollover, fractional zone, persistence, retirement and monotonic frame projection")
    }
}
