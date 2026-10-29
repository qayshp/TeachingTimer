// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
        // Every quarter boundary uses the same late-start bias, including
        // subsecond taps just before the :13 cutoff and the next whole hour.
        for minute in 0..<60 {
            let quarter = minute / 15 * 15
            let expectedMinute = minute % 15 >= 13 ? quarter + 15 : quarter
            let expected = date(0).addingTimeInterval(Double(expectedMinute * 60))
            for seconds in [0.0, 0.001, 59.999] {
                let pressed = date(minute).addingTimeInterval(seconds)
                assert(ClassContext.inferredStart(for: pressed, calendar: calendar) == expected)
            }
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
        // Preparing early must allow the inferred quarter to be corrected.
        store.begin(at: date(10, 23), scheduledStart: date(15), durationMinutes: 60)
        assert(store.context?.scheduledEnd == date(15).addingTimeInterval(3600))
        store.updateSchedule(start: date(30), durationMinutes: 75)
        assert(store.context?.initialStartPressedAt == date(10, 23))
        assert(ClassStore(defaults: defaults).context == store.context)
        // Explicit New class before the old grace period expires gets a fresh anchor.
        store.begin(at: date(40), scheduledStart: date(45), durationMinutes: 60)
        assert(store.context?.initialStartPressedAt == date(40))
        assert(store.context?.scheduledStart == date(45))
        store.reset()
        // Decoding must enforce the same invariants as fresh construction.
        let validData = try! JSONEncoder().encode(context)
        let validObject = try! JSONSerialization.jsonObject(with: validData) as! [String: Any]
        for badDuration in [0, -1, 1441, Int.max] {
            var object = validObject
            object["durationMinutes"] = badDuration
            let bytes = try! JSONSerialization.data(withJSONObject: object)
            defaults.set(bytes, forKey: "teachingClassContext.v1")
            assert(ClassStore(defaults: defaults).context == nil)
            assert(defaults.data(forKey: "teachingClassContext.v1") == bytes)
        }
        var badDate = validObject
        badDate["scheduledStart"] = 1e100
        let bytes = try! JSONSerialization.data(withJSONObject: badDate)
        defaults.set(bytes, forKey: "teachingClassContext.v1")
        assert(ClassStore(defaults: defaults).context == nil)
        assert(defaults.data(forKey: "teachingClassContext.v1") == bytes)
        defaults.set(Data("invalid".utf8), forKey: "teachingClassContext.v1")
        let recovered = ClassStore(defaults: defaults)
        assert(recovered.context == nil)
        recovered.establishIfNeeded(at: date(31), durationMinutes: 75)
        assert(ClassStore(defaults: defaults).context?.durationMinutes == 75)
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
        // Empty preferences and unreadable preferences are different diagnoses.
        store.reset()
        let absent = ClassStore(defaults: defaults)
        assert(!absent.needsRecoveryNotice)
        assert(absent.takePersistenceEvents().first?.details["state"] == "absent")
        assert(absent.takePersistenceEvents().isEmpty)
        let corruptBytes = Data("keep these exact bytes".utf8)
        defaults.set(corruptBytes, forKey: "teachingClassContext.v1")
        let broken = ClassStore(defaults: defaults)
        assert(broken.needsRecoveryNotice)
        let failure = broken.takePersistenceEvents().first!
        assert(broken.needsRecoveryNotice) // Draining diagnostics must not hide the notice.
        assert(failure.name == "persistence_read_failed" && failure.details["state"] == "unreadable")
        assert(failure.details["backupReadBack"] == "true")
        let recoveryKey = "teachingClassContext.v1.unreadable.v1"
        assert(defaults.dictionary(forKey: recoveryKey)?["bytes"] as? Data == corruptBytes)
        let capturedAt = defaults.dictionary(forKey: recoveryKey)?["capturedAt"] as? Date
        broken.acknowledgeRecoveryNotice()
        assert(!broken.needsRecoveryNotice)
        assert(defaults.data(forKey: "teachingClassContext.v1") == corruptBytes)
        assert(ClassStore(defaults: defaults).needsRecoveryNotice)
        _ = ClassStore(defaults: defaults)
        assert(defaults.dictionary(forKey: recoveryKey)?["capturedAt"] as? Date == capturedAt)
        broken.begin(at: date(31), scheduledStart: date(30), durationMinutes: 60)
        assert(!broken.needsRecoveryNotice)
        assert(!ClassStore(defaults: defaults).needsRecoveryNotice)
        assert(ClassStore(defaults: defaults).context == broken.context)
        assert(defaults.dictionary(forKey: recoveryKey)?["bytes"] as? Data == corruptBytes)
        defaults.set("unexpected preference type", forKey: "teachingClassContext.v1")
        let wrongType = ClassStore(defaults: defaults)
        assert(wrongType.needsRecoveryNotice)
        assert(wrongType.takePersistenceEvents().first?.details["state"] == "unexpected_type")
        let backupBytes = defaults.dictionary(forKey: recoveryKey)!["bytes"] as! Data
        let propertyList = try! PropertyListSerialization.propertyList(from: backupBytes, format: nil) as! [String: String]
        assert(propertyList["value"] == "unexpected preference type")
        // Failed encoding leaves the old stored value intact and is observable.
        var events: [PersistenceEvent] = []
        defaults.set(corruptBytes, forKey: "encode-test")
        PersistenceDiagnostics.save(Double.nan, key: "encode-test", defaults: defaults, events: &events)
        assert(events.last?.name == "persistence_write_failed")
        assert(defaults.data(forKey: "encode-test") == corruptBytes)
        print("PASS: missing/restored/unreadable/type diagnostics, one-shot draining, exact bounded recovery bytes, failed encoding preserves prior value")
        print("PASS: quarter-hour boundaries, seconds, hour rollover, 75-minute end, midpoint, persistence and explicit reset")
        print("PASS: exact retirement boundary, overrun grace, idempotence, persistence, fresh Start and 75-minute protection")
        print("PASS: invalid persisted durations/dates rejected without overwriting data; explicit Start recovers")
    }
}
