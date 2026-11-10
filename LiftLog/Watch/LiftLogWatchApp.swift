import SwiftUI

@main
struct LiftLogWatchApp: App {
    @StateObject private var store = WatchStore()

    var body: some Scene {
        WindowGroup {
            NavigationView {
                RootView()
            }
            .environmentObject(store)
        }
    }
}
