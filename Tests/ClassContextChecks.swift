import Foundation

@main
struct ClassContextChecks {
    @MainActor static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func date(_ minute: Int, _ second: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 17, minute: minute, second: second))!
        }
        for (input, expected) in [(31, 30), (37, 30), (42, 30), (43, 45), (44, 45), (45, 45), (0, 0)] {
            assert(ClassContext.inferredStart(for: date(input), calendar: calendar) == date(expected))
        }
        assert(ClassContext.inferredStart(for: date(42, 59), calendar: calendar) == date(30))
        assert(ClassContext.inferredStart(for: date(59), calendar: calendar) == date(59).addingTimeInterval(60))
        let context = ClassContext(pressedAt: date(37, 23), durationMinutes: 75, calendar: calendar)
        assert(context.initialStartPressedAt == date(37, 23))
        assert(context.scheduledEnd == date(30).addingTimeInterval(75 * 60))
        assert(context.progress(at: context.scheduledStart.addingTimeInterval(37.5 * 60)) == 0.5)
        let suite = "TeachingTimerTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ClassStore(defaults: defaults)
        store.establishIfNeeded(at: date(31))
        let original = store.context
        store.establishIfNeeded(at: date(59), durationMinutes: 75)
        assert(store.context == original)
        assert(ClassStore(defaults: defaults).context == original)
        store.reset()
        assert(ClassStore(defaults: defaults).context == nil)
        store.establishIfNeeded(at: date(31))
        let oldClass = store.context!
        assert(oldClass.retirementDate == date(30).addingTimeInterval(90 * 60))
        assert(!oldClass.shouldRetire(at: oldClass.retirementDate.addingTimeInterval(-0.001)))
        var retirementCalls = 0
        assert(!store.retireIfNeeded(at: oldClass.scheduledEnd.addingTimeInterval(29 * 60)))
        // Class context survives an hour-long runtime boundary and the overrun.
        assert(store.context == oldClass)
        assert(store.retireIfNeeded(at: oldClass.retirementDate) { retired in
            assert(store.context == oldClass && retired == oldClass)
            retirementCalls += 1
        })
        assert(retirementCalls == 1 && store.context == nil)
        assert(ClassStore(defaults: defaults).context == nil)
        assert(!store.retireIfNeeded(at: oldClass.retirementDate.addingTimeInterval(600)) { _ in retirementCalls += 1 })
        assert(retirementCalls == 1)
        // A new context is created only by a later explicit Start.
        let nextStart = date(31).addingTimeInterval(3 * 3600)
        store.establishIfNeeded(at: nextStart, durationMinutes: 75)
        let longerClass = store.context!
        assert(longerClass.initialStartPressedAt == nextStart)
        assert(longerClass.retirementDate.timeIntervalSince(longerClass.scheduledStart) == 105 * 60)
        assert(!store.retireIfNeeded(at: longerClass.scheduledStart.addingTimeInterval(90 * 60)))
        // Restored old data is checked against actual time on activation.
        let reopened = ClassStore(defaults: defaults)
        assert(reopened.retireIfNeeded(at: longerClass.retirementDate.addingTimeInterval(3600)))
        assert(ClassStore(defaults: defaults).context == nil)
        print("PASS: quarter-hour boundaries, seconds, hour rollover, 75-minute end, midpoint, persistence and explicit reset")
        print("PASS: exact retirement boundary, overrun grace, idempotence, persistence, fresh Start and 75-minute protection")
    }
}
