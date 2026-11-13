// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import WidgetKit

private struct LauncherEntry: TimelineEntry {
    let date: Date
}

private struct LauncherProvider: TimelineProvider {
    func placeholder(in context: Context) -> LauncherEntry {
        LauncherEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (LauncherEntry) -> Void) {
        completion(LauncherEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LauncherEntry>) -> Void) {
        // This is an app launcher, not a second class clock. It needs no refreshes
        // or access to the teaching app's saved state.
        completion(Timeline(entries: [LauncherEntry(date: .now)], policy: .never))
    }
}

private struct LauncherView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Label("Teaching Timer", image: "MatClockInlineGlyph")
            case .accessoryRectangular:
                HStack(spacing: 8) {
                    Image("MatClockGlyph")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Teaching Timer")
                            .font(.headline)
                        Text("Open teaching clock")
                            .font(.caption)
                    }
                }
            default:
                Image("MatClockGlyph")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .padding(2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Open Teaching Timer")
    }
}

@main
struct TeachingTimerComplication: Widget {
    var body: some WidgetConfiguration {
        // With no custom URL or intent, watchOS opens the containing Watch app.
        StaticConfiguration(kind: "TeachingTimerLauncher", provider: LauncherProvider()) { _ in
            LauncherView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Teaching Timer")
        .description("Open your teaching clock.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
            .accessoryRectangular,
        ])
    }
}

#Preview(as: .accessoryCircular) {
    TeachingTimerComplication()
} timeline: {
    LauncherEntry(date: .now)
}
