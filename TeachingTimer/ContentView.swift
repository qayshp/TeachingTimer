import SwiftUI
import WatchKit

struct ContentView: View {
    enum Page: Hashable {
        case squircleIntersection
        case squircleClipped
        case circular
        case nowPlaying
    }

    @ObservedObject var session: ExtendedRuntimeController
    @State private var page: Page = .squircleIntersection

    init(session: ExtendedRuntimeController) {
        self.session = session
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let initialPage: Page
        if arguments.contains("--show-clipped") {
            initialPage = .squircleClipped
        } else if arguments.contains("--show-circular") {
            initialPage = .circular
        } else if arguments.contains("--show-now-playing") {
            initialPage = .nowPlaying
        } else {
            initialPage = .squircleIntersection
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
                    crownIsActive: page == .squircleIntersection
                )
                .tag(Page.squircleIntersection)

                SharedClockPage(
                    date: context.date,
                    face: .squircleClipped,
                    session: session,
                    crownIsActive: page == .squircleClipped
                )
                .tag(Page.squircleClipped)

                SharedClockPage(
                    date: context.date,
                    face: .circular,
                    session: session,
                    crownIsActive: page == .circular
                )
                .tag(Page.circular)

                NowPlayingView()
                    .containerBackground(.black, for: .tabView)
                    .tag(Page.nowPlaying)
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
        }
    }

    private var nextWholeSecond: Date {
        Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970) + 1)
    }
}

#Preview {
    ContentView(session: ExtendedRuntimeController())
}
