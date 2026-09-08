import Foundation
import WatchKit
import OSLog

@MainActor
final class MetronomeController: ObservableObject {
    struct Configuration {
        var intervalSeconds: Double = 5
        var beatCount: Int = 8
        var acknowledgement: WKHapticType = .start
        var beat: WKHapticType = .click
    }
    @Published private(set) var isActive = false
    @Published private(set) var beatsDelivered = 0
    @Published private(set) var nextScheduledBeat: Date?
    private(set) var configuration = Configuration()
    private var task: Task<Void, Never>?
    private let log = Logger(subsystem: "com.qayshp.TeachingTimer", category: "Metronome")
    var beatsRemaining: Int { max(0, configuration.beatCount - beatsDelivered) }
    func start(configuration: Configuration = Configuration()) {
        guard !isActive, configuration.intervalSeconds.isFinite,
              configuration.intervalSeconds > 0, configuration.beatCount > 0 else { return }
        self.configuration = configuration
        beatsDelivered = 0
        isActive = true
        let clock = ContinuousClock()
        let anchor = clock.now
        let wallAnchor = Date()
        nextScheduledBeat = wallAnchor.addingTimeInterval(configuration.intervalSeconds)
        WKInterfaceDevice.current().play(configuration.acknowledgement)
        log.notice("Metronome activated; first beat delayed by \(configuration.intervalSeconds) seconds")
        task = Task { [weak self] in
            for index in 1...configuration.beatCount {
                let deadline = anchor.advanced(by: .seconds(configuration.intervalSeconds * Double(index)))
                do { try await clock.sleep(until: deadline) } catch { return }
                guard let self, !Task.isCancelled, self.isActive else { return }
                // Cancel instead of replaying stale beats in a burst after suspension.
                if deadline.duration(to: clock.now) >= .seconds(configuration.intervalSeconds) { self.cancel(); return }
                WKInterfaceDevice.current().play(configuration.beat)
                self.beatsDelivered = index
                self.log.notice("Delivered beat \(index) of \(configuration.beatCount)")
                self.nextScheduledBeat = index < configuration.beatCount
                    ? wallAnchor.addingTimeInterval(configuration.intervalSeconds * Double(index + 1)) : nil
            }
            self?.isActive = false
            self?.log.notice("Metronome completed")
            self?.task = nil
        }
    }
    func cancel() {
        task?.cancel(); task = nil; isActive = false; nextScheduledBeat = nil
        log.notice("Metronome cancelled")
    }
}
