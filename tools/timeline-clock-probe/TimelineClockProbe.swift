// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

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
            GeometryReader { geometry in
                let size = geometry.size
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let angle = Double(Calendar.current.component(.second, from: timeline.date)) * .pi / 30
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
                    Circle().fill(color).frame(width: 9, height: 9).position(center)
                }
            }
        }
        .ignoresSafeArea()
    }
}
