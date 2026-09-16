import Foundation

/// Pure timing/geometry model, also compiled by the command-line checks.
struct LandmarkSchedule {
    var intervalSeconds: Double = 10
    var landmarkCount: Int = 6
    var pulseSpacing: Double = 0.8

    var duration: Double { intervalSeconds * Double(landmarkCount) }
    var isValid: Bool {
        intervalSeconds.isFinite && intervalSeconds > 0 &&
        (1...6).contains(landmarkCount) && pulseSpacing.isFinite &&
        pulseSpacing >= 0.5 && Double(landmarkCount) * pulseSpacing < intervalSeconds
    }
    func pulseOffset(landmark: Int, pulse: Int) -> Double {
        Double(landmark) * intervalSeconds + Double(pulse) * pulseSpacing
    }
    func progress(elapsed: Double) -> Double { min(1, max(0, elapsed / duration)) }
    static func startAngle(at date: Date) -> Double {
        Double(Calendar.current.component(.second, from: date)) * .pi / 30
    }
}

#if canImport(WatchKit)
import WatchKit
import OSLog

@MainActor
final class MetronomeController: ObservableObject {
    struct Configuration {
        var schedule = LandmarkSchedule()
        var acknowledgement: WKHapticType = .start
        // Physical-device trial: a more distinctive beat than the faint click.
        var beat: WKHapticType = .directionUp
    }
    @Published private(set) var isActive = false
    // Diagnostic bookkeeping is not displayed. Avoid invalidating all clock
    // pages twice per beat; only active/inactive changes need UI publication.
    private(set) var beatsDelivered = 0
    private(set) var nextScheduledBeat: Date?
    private(set) var configuration = Configuration()
    private(set) var startAngle: Double = 0
    private var anchor: ContinuousClock.Instant?
    private var task: Task<Void, Never>?
    private let log = Logger(subsystem: "com.qayshp.TeachingTimer", category: "Metronome")
    var beatsRemaining: Int { max(0, configuration.schedule.landmarkCount - beatsDelivered) }
    /// Read by the existing one-second timeline; no per-pulse UI publication.
    var progress: Double {
        guard isActive, let anchor else { return 0 }
        let elapsed = anchor.duration(to: ContinuousClock().now).components
        return configuration.schedule.progress(elapsed: Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18)
    }
    func start(configuration: Configuration = Configuration()) {
        guard !isActive, configuration.schedule.isValid else { return }
        self.configuration = configuration
        beatsDelivered = 0
        let clock = ContinuousClock()
        let anchor = clock.now
        self.anchor = anchor
        let wallAnchor = Date()
        startAngle = LandmarkSchedule.startAngle(at: wallAnchor)
        let schedule = configuration.schedule
        nextScheduledBeat = wallAnchor.addingTimeInterval(schedule.intervalSeconds)
        isActive = true
        WKInterfaceDevice.current().play(configuration.acknowledgement)
        log.notice("Landmarks activated; first group in \(schedule.intervalSeconds) seconds")
        task = Task { [weak self] in
            for index in 1...schedule.landmarkCount {
                for pulse in 0..<index {
                    let deadline = anchor.advanced(by: .seconds(schedule.pulseOffset(landmark: index, pulse: pulse)))
                    do { try await clock.sleep(until: deadline) } catch { return }
                    guard let self, !Task.isCancelled, self.isActive else { return }
                    // Never compress overdue pulses into a misleading catch-up burst.
                    guard deadline.duration(to: clock.now) < .seconds(schedule.pulseSpacing / 2) else {
                        self.log.warning("Landmark schedule missed; cancelling rather than catching up")
                        self.cancel(); return
                    }
                    WKInterfaceDevice.current().play(configuration.beat)
                    self.log.notice("Landmark \(index), pulse \(pulse + 1)")
                }
                guard let self, !Task.isCancelled else { return }
                self.beatsDelivered = index
                self.nextScheduledBeat = index < schedule.landmarkCount
                    ? wallAnchor.addingTimeInterval(schedule.intervalSeconds * Double(index + 1)) : nil
            }
            // Let the final six-pulse group finish before clearing the full arc.
            let end = schedule.pulseOffset(landmark: schedule.landmarkCount, pulse: schedule.landmarkCount)
            do { try await clock.sleep(until: anchor.advanced(by: .seconds(end))) } catch { return }
            guard !Task.isCancelled else { return }
            self?.anchor = nil
            self?.isActive = false
            self?.log.notice("Landmarks completed")
            self?.task = nil
        }
    }
    func cancel() {
        task?.cancel(); task = nil; anchor = nil; isActive = false; nextScheduledBeat = nil
        log.notice("Landmarks cancelled")
    }
}
#endif
