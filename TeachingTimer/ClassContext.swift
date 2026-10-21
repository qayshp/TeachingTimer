import Foundation
import Combine

struct ClassContext: Codable, Equatable {
    // Sanity bound for persisted/future configuration, not the runtime limit.
    static let validDurationMinutes = 1...1440
    let initialStartPressedAt: Date
    let scheduledStart: Date
    let durationMinutes: Int
    var scheduledEnd: Date { scheduledStart.addingTimeInterval(Double(durationMinutes) * 60) }
    /// A generous overrun window; independent of WatchKit's runtime limit.
    static let retirementGraceMinutes = 30
    var retirementDate: Date { scheduledEnd.addingTimeInterval(Double(Self.retirementGraceMinutes) * 60) }
    func shouldRetire(at date: Date) -> Bool { date >= retirementDate }
    init(pressedAt: Date, durationMinutes: Int = 60, calendar: Calendar = .current) {
        precondition(Self.validDurationMinutes.contains(durationMinutes))
        initialStartPressedAt = pressedAt
        scheduledStart = Self.inferredStart(for: pressedAt, calendar: calendar)
        self.durationMinutes = durationMinutes
    }
    static func inferredStart(for date: Date, calendar: Calendar = .current) -> Date {
        let minuteStart = calendar.dateInterval(of: .minute, for: date)?.start ?? date
        let offset = calendar.component(.minute, from: date) % 15
        return minuteStart.addingTimeInterval(Double(offset >= 13 ? 15 - offset : -offset) * 60)
    }
    func progress(at date: Date) -> Double {
        date.timeIntervalSince(scheduledStart) / scheduledEnd.timeIntervalSince(scheduledStart)
    }

    private enum CodingKeys: String, CodingKey {
        case initialStartPressedAt, scheduledStart, durationMinutes
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        initialStartPressedAt = try values.decode(Date.self, forKey: .initialStartPressedAt)
        scheduledStart = try values.decode(Date.self, forKey: .scheduledStart)
        durationMinutes = try values.decode(Int.self, forKey: .durationMinutes)
        guard Self.validDurationMinutes.contains(durationMinutes),
              [initialStartPressedAt, scheduledStart, scheduledEnd, retirementDate].allSatisfy({
                  $0.timeIntervalSinceReferenceDate.isFinite &&
                  $0 >= .distantPast && $0 <= .distantFuture
              }) else {
            throw DecodingError.dataCorruptedError(forKey: .durationMinutes, in: values,
                debugDescription: "Invalid saved class duration or dates")
        }
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

    /// The caller stops its session/count before timing is removed. No new
    /// class is inferred until an explicit Start, and repeated checks are inert.
    @discardableResult
    func retireIfNeeded(at date: Date = Date(), beforeReset: (ClassContext) -> Void = { _ in }) -> Bool {
        guard let context, context.shouldRetire(at: date) else { return false }
        beforeReset(context)
        reset()
        return true
    }
}
