// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import WatchKit

struct ContentView: View {
    enum Page: String, Hashable {
        case classProgress
        case nowPlaying
    }

    @ObservedObject var session: ExtendedRuntimeController
    @StateObject private var classStore = ClassStore()
    @StateObject private var landmarks = LandmarkController()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var dimmed
    @State private var page: Page = .classProgress
    @State private var classClockRevision = 0
    @State private var mediaViewGeneration = 0
    @State private var mediaReloadPolicy = MediaReloadPolicy()
    @State private var volumeBackgroundRevision = 0

    private struct ClassTaskKey: Equatable {
        let context: ClassContext?
        let clockRevision: Int
    }

    init(session: ExtendedRuntimeController) {
        self.session = session
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let initialPage: Page
        if arguments.contains("--show-progress") {
            initialPage = .classProgress
        } else if arguments.contains("--show-now-playing") {
            initialPage = .nowPlaying
        } else {
            initialPage = .classProgress
        }
        _page = State(initialValue: initialPage)
#endif
    }

    var body: some View {
        TimelineView(.periodic(from: nextWholeSecond, by: 1)) { context in
            TabView(selection: $page) {
                SharedClockPage(
                    date: context.date,
                    session: session,
                    classStore: classStore,
                    landmarks: landmarks,
                    retireOldClass: { retireOldClass() },
                    crownIsActive: page == .classProgress,
                    volumeBackgroundRevision: volumeBackgroundRevision,
                    showsClassProgress: true
                )
                .onAppear { recordInterfaceEvent("page_appeared", page: .classProgress) }
                .onDisappear { recordInterfaceEvent("page_disappeared", page: .classProgress) }
                .tag(Page.classProgress)

                NowPlayingView()
                    // Recreate only the native media host on bounded entry/return
                    // events, never on ordinary wrist wakes.
                    // The timer page, volume adapter, and shared state retain identity.
                    .id(mediaViewGeneration)
                    .containerBackground(.black, for: .tabView)
                    .onAppear { recordInterfaceEvent("page_appeared", page: .nowPlaying) }
                    .onDisappear { recordInterfaceEvent("page_disappeared", page: .nowPlaying) }
                    .tag(Page.nowPlaying)
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
#if DEBUG
            // Visual checks only: no automatic session or haptic actions.
            .transformEnvironment(\.dynamicTypeSize) { size in
                let arguments = ProcessInfo.processInfo.arguments
                if arguments.contains("--maximum-text") { size = .accessibility5 }
                else if arguments.contains("--accessibility-text") { size = .accessibility3 }
                else if arguments.contains("--large-text") { size = .xxxLarge }
            }
#endif
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemClockDidChange)) { _ in
                // Old pre-rendered dates no longer represent the same instants.
                // New frames project from a fresh wall/monotonic clock pair.
                context.invalidateTimelineContent()
                retireOldClass()
                classClockRevision &+= 1
            }
            .onChange(of: landmarks.isActive) { _, _ in
                context.invalidateTimelineContent()
            }
            .onChange(of: classStore.context) { _, _ in
                context.invalidateTimelineContent()
                session.synchronizeClass(classStore.context)
            }
        }
        .onAppear { [session] in
            landmarks.diagnosticContext = { [weak session] in session?.diagnosticContext ?? [:] }
            retireOldClass()
            session.synchronizeClass(classStore.context)
            session.applicationBecameActive()
            recordInterfaceEvent("interface_appeared")
        }
        .onDisappear { recordInterfaceEvent("interface_disappeared") }
        .onChange(of: page) { old, new in
            recordInterfaceEvent("page_selection_changed", details: ["previousPage": old.rawValue])
            if new == .nowPlaying, let reason = mediaReloadPolicy.didSelectMedia() {
                recreateMedia(reason: reason)
            }
        }
        .onChange(of: dimmed) { old, _ in
            recordInterfaceEvent("luminance_changed", details: ["previousLuminanceReduced": String(old)])
        }
        .task(id: ClassTaskKey(context: classStore.context, clockRevision: classClockRevision)) {
            // Use actual wall time, never a potentially pre-rendered timeline
            // date. Recheck after a delayed wake; a clock change reschedules us.
            while !Task.isCancelled, let deadline = classStore.context?.retirementDate {
                let delay = deadline.timeIntervalSinceNow
                if delay <= 0 { retireOldClass(); return }
                do { try await Task.sleep(for: .seconds(delay)) }
                catch { return }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                mediaReloadPolicy.didEnterBackground()
                volumeBackgroundRevision &+= 1
            }
            session.applicationStateChanged(String(describing: phase), details: [
                "selectedPage": page.rawValue,
                "luminanceReduced": String(dimmed),
                "mediaViewGeneration": String(mediaViewGeneration)
            ])
            if phase == .active {
                // Stop stale renewal intent before processing foreground recovery.
                retireOldClass()
                session.synchronizeClass(classStore.context)
                // Also refresh the wait if a clock-change notification was
                // missed while suspended and the class is not yet overdue.
                classClockRevision &+= 1
                session.applicationBecameActive()
                if let reason = mediaReloadPolicy.didBecomeActive(mediaIsSelected: page == .nowPlaying) {
                    recreateMedia(reason: reason)
                }
            }
        }
    }

    private func recordInterfaceEvent(_ event: String, page observedPage: Page? = nil,
                                      details: [String: String] = [:]) {
        var fields = details
        fields["selectedPage"] = page.rawValue
        fields["observedPage"] = observedPage?.rawValue
        fields["scenePhase"] = String(describing: scenePhase)
        fields["luminanceReduced"] = String(dimmed)
        fields["mediaViewGeneration"] = String(mediaViewGeneration)
        // Appearance is a SwiftUI callback, not proof that pixels were visible.
        session.recordInterfaceEvent(event, details: fields)
    }

    private var nextWholeSecond: Date {
        Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970) + 1)
    }

    private func recreateMedia(reason: MediaReloadPolicy.Reason) {
        let previousGeneration = mediaViewGeneration
        mediaViewGeneration &+= 1
        recordInterfaceEvent("media_reload_requested", details: [
            "source": reason.rawValue,
            "refreshMode": "automatic",
            "failureDetected": "unobserved",
            "previousMediaViewGeneration": String(previousGeneration),
            "landmarksActive": String(landmarks.isActive),
            "landmarkProgress": String(landmarks.progress)
        ])
    }

    @discardableResult
    private func retireOldClass(at date: Date = Date()) -> Bool {
        classStore.retireIfNeeded(at: date) { old in
            let formatter = ISO8601DateFormatter()
            session.stop(source: "class_retired", details: [
                "classInitialStart": formatter.string(from: old.initialStartPressedAt),
                "classScheduledStart": formatter.string(from: old.scheduledStart),
                "classScheduledEnd": formatter.string(from: old.scheduledEnd),
                "classRetirementDate": formatter.string(from: old.retirementDate),
                "classRetiredAt": formatter.string(from: date),
                "classDurationMinutes": String(old.durationMinutes)
            ])
            landmarks.cancel(reason: "class_retired")
        }
    }
}

#Preview {
    ContentView(session: ExtendedRuntimeController())
}
