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
                    crownIsActive: page == .classProgress,
                    showsClassProgress: true
                )
                .tag(Page.classProgress)

                NowPlayingView()
                    .containerBackground(.black, for: .tabView)
                    .tag(Page.nowPlaying)
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
        }
        .onChange(of: scenePhase) { _, phase in
            session.applicationStateChanged(String(describing: phase))
            if phase == .active { session.applicationBecameActive() }
        }
    }

    private var nextWholeSecond: Date {
        Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970) + 1)
    }
}

#Preview {
    ContentView(session: ExtendedRuntimeController())
}
