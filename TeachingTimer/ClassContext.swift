import Foundation
import Combine

struct ClassContext: Codable, Equatable {
    let initialStartPressedAt: Date
    let scheduledStart: Date
    let durationMinutes: Int
    var scheduledEnd: Date { scheduledStart.addingTimeInterval(Double(durationMinutes) * 60) }
    init(pressedAt: Date, durationMinutes: Int = 60, calendar: Calendar = .current) {
        precondition(durationMinutes > 0)
        initialStartPressedAt = pressedAt
        scheduledStart = Self.inferredStart(for: pressedAt, calendar: calendar)
        self.durationMinutes = durationMinutes
    }
    static func inferredStart(for date: Date, calendar: Calendar = .current) -> Date {
        let minuteStart = calendar.dateInterval(of: .minute, for: date)!.start
        let offset = calendar.component(.minute, from: date) % 15
        return minuteStart.addingTimeInterval(Double(offset >= 13 ? 15 - offset : -offset) * 60)
    }
    func progress(at date: Date) -> Double {
        date.timeIntervalSince(scheduledStart) / scheduledEnd.timeIntervalSince(scheduledStart)
    }
}

@MainActor
final class ClassStore: ObservableObject {
    @Published private(set) var context: ClassContext?
    private let defaults: UserDefaults
    private let key = "teachingClassContext.v1"
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key) { context = try? JSONDecoder().decode(ClassContext.self, from: data) }
    }
    func establishIfNeeded(at date: Date = Date(), durationMinutes: Int = 60) {
        guard context == nil else { return }
        context = ClassContext(pressedAt: date, durationMinutes: durationMinutes)
        if let data = try? JSONEncoder().encode(context) { defaults.set(data, forKey: key) }
    }
    func reset() { context = nil; defaults.removeObject(forKey: key) }
}
