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
        print("PASS: quarter-hour boundaries, seconds, hour rollover, 75-minute end, midpoint, persistence and explicit reset")
    }
}
