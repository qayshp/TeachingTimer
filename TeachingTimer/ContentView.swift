import SwiftUI
import WatchKit

struct ContentView: View {
    enum Page: Hashable {
        case classProgress
        case nowPlaying
    }

    @ObservedObject var session: ExtendedRuntimeController
    @StateObject private var classStore = ClassStore()
    @StateObject private var metronome = MetronomeController()
    @Environment(\.scenePhase) private var scenePhase
    @State private var page: Page = .classProgress
    @State private var classClockRevision = 0

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
                    face: .squircleIntersection,
                    session: session,
                    classStore: classStore,
                    metronome: metronome,
                    retireOldClass: { retireOldClass() },
                    crownIsActive: page == .classProgress,
                    showsClassProgress: true
                )
                .tag(Page.classProgress)

                NowPlayingView()
                    .containerBackground(.black, for: .tabView)
                    .tag(Page.nowPlaying)
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
#if DEBUG
            // Visual checks only: no automatic session or haptic actions.
            .transformEnvironment(\.dynamicTypeSize) { size in
                let arguments = ProcessInfo.processInfo.arguments
                if arguments.contains("--accessibility-text") { size = .accessibility3 }
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
            .onChange(of: metronome.isActive) { _, _ in
                context.invalidateTimelineContent()
            }
            .onChange(of: metronome.hapticsStopped) { _, _ in
                context.invalidateTimelineContent()
            }
        }
        .onAppear { [session] in
            metronome.diagnosticContext = { [weak session] in session?.diagnosticContext ?? [:] }
            retireOldClass()
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
            session.applicationStateChanged(String(describing: phase))
            if phase == .active {
                // Stop stale renewal intent before processing foreground recovery.
                retireOldClass()
                // Also refresh the wait if a clock-change notification was
                // missed while suspended and the class is not yet overdue.
                classClockRevision &+= 1
                session.applicationBecameActive()
            }
        }
    }

    private var nextWholeSecond: Date {
        Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970) + 1)
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
            metronome.cancel(reason: "class_retired")
        }
    }
}

#Preview {
    ContentView(session: ExtendedRuntimeController())
}
