// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import OSLog

@main
struct TimelineClockProbeApp: App {
    var body: some Scene {
        WindowGroup { ClockProbeView() }
    }
}

private struct ClockProbeView: View {
    @Environment(\.isLuminanceReduced) private var dimmed
    private let arguments = ProcessInfo.processInfo.arguments
    private var anchor: Date {
        arguments.contains("--moving-anchor")
            ? Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970) + 1)
            : Date(timeIntervalSince1970: 0)
    }
    var body: some View {
        TimelineView(.periodic(from: anchor, by: 1)) { timeline in
            // Capture once for this content evaluation, before GeometryReader.
            // The immutable sample follows the prepared view without publishing state.
            let trace = arguments.contains("--trace-render")
                ? ClockRenderTrace.shared.capture(date: timeline.date,
                                                  cadence: timeline.cadence,
                                                  dimmed: dimmed,
                                                  normalize: arguments.contains("--normalize-second-boundary"))
                : nil
            GeometryReader { geometry in
                let size = geometry.size
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                // Trace geometry and labels must use the identical captured value;
                // do not re-read the timeline context in this later layout closure.
                let contextDate = trace?.contextDate ?? timeline.date
                let displayDate = arguments.contains("--normalize-second-boundary")
                    ? WallClockDisplay.normalizedDate(contextDate) : contextDate
                let contextSecond = trace?.contextSecondComponent
                    ?? Calendar.current.component(.second, from: displayDate)
                let angle = Double(contextSecond) * .pi / 30
                let endpoint = CGPoint(x: center.x + sin(angle) * 155,
                                       y: center.y - cos(angle) * 155)
                let path = Path { p in p.move(to: center); p.addLine(to: endpoint) }
                let color: Color = arguments.contains("--constant-color") ? .white : (dimmed ? .white : .yellow)
                ZStack {
                    Color.black
                    if arguments.contains("--canvas") {
                        Canvas { context, _ in
                            context.stroke(path, with: .color(color),
                                           style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        }
                    } else {
                        path.stroke(color, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    }
                    if let trace {
                        let wallAngle = Double(Calendar.current.component(.second, from: trace.wallDate)) * .pi / 30
                        // Stay inside the center region so video analysis can
                        // isolate the original hand in an outer pixel annulus.
                        let wallEndpoint = CGPoint(x: center.x + sin(wallAngle) * 40,
                                                   y: center.y - cos(wallAngle) * 40)
                        Path { p in p.move(to: center); p.addLine(to: wallEndpoint) }
                            .stroke(.white, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                        Circle().stroke(.white, lineWidth: 1.5)
                            .frame(width: 8, height: 8).position(wallEndpoint)
                        Text("E\(trace.id) \(trace.dimmed ? "DIM" : "LIVE")\nC \(trace.contextSecond) S\(trace.contextSecondComponent)\nW \(trace.wallSecond)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(3)
                            .background(.black)
                            .position(x: center.x, y: size.height * 0.60)
                    }
                    Circle().fill(color).frame(width: 9, height: 9).position(center)
                }
            }
        }
        .ignoresSafeArea()
    }
}

private struct ClockRenderSample {
    let id: UInt64
    let contextDate: Date
    let contextSecondComponent: Int
    let rawSecondComponent: Int
    let normalized: Bool
    let wallDate: Date
    let monotonicElapsed: Double
    let cadence: String
    let dimmed: Bool

    var contextSecond: String { secondLabel(contextDate) }
    var wallSecond: String { secondLabel(wallDate) }

    private func secondLabel(_ date: Date) -> String {
        String(format: "%06.3f", date.timeIntervalSince1970.truncatingRemainder(dividingBy: 60))
    }
}

// This counter is diagnostic bookkeeping, not observable view state. The lock
// protects the counter and sampling pair if SwiftUI evaluates on different threads.
private final class ClockRenderTrace: @unchecked Sendable {
    static let shared = ClockRenderTrace()
    private let lock = NSLock()
    private let clock = ContinuousClock()
    private let origin = ContinuousClock.now
    private var nextID: UInt64 = 0
    private let logger = Logger(subsystem: "net.qays.TeachingTimer.ClockProbe",
                                category: "RenderTrace")

    func capture(date: Date, cadence: TimelineViewDefaultContext.Cadence,
                 dimmed: Bool, normalize: Bool) -> ClockRenderSample {
        lock.lock()
        nextID += 1
        let wallDate = Date()
        let elapsed = origin.duration(to: clock.now).components
        let cadenceName: String
        switch cadence {
        case .live: cadenceName = "live"
        case .seconds: cadenceName = "seconds"
        case .minutes: cadenceName = "minutes"
        @unknown default: cadenceName = "unknown"
        }
        let sample = ClockRenderSample(
            id: nextID, contextDate: date,
            contextSecondComponent: Calendar.current.component(.second,
                from: normalize ? WallClockDisplay.normalizedDate(date) : date),
            rawSecondComponent: Calendar.current.component(.second, from: date),
            normalized: normalize,
            wallDate: wallDate,
            monotonicElapsed: Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18,
            cadence: cadenceName, dimmed: dimmed)
        lock.unlock()
        logger.notice("clock_render id=\(sample.id, privacy: .public) monotonic_elapsed=\(sample.monotonicElapsed, privacy: .public) context_epoch=\(sample.contextDate.timeIntervalSince1970, privacy: .public) context_reference_bits=\(sample.contextDate.timeIntervalSinceReferenceDate.bitPattern, privacy: .public) raw_second=\(sample.rawSecondComponent, privacy: .public) context_second=\(sample.contextSecondComponent, privacy: .public) normalized=\(sample.normalized, privacy: .public) wall_epoch=\(sample.wallDate.timeIntervalSince1970, privacy: .public) cadence=\(sample.cadence, privacy: .public) dimmed=\(sample.dimmed, privacy: .public)")
        return sample
    }
}
