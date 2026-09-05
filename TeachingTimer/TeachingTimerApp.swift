import SwiftUI

@main
struct TeachingTimerApp: App {
    @StateObject private var session = ExtendedRuntimeController()

    var body: some Scene {
        WindowGroup {
            ContentView(session: session)
        }
    }
}
