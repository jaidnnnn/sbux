import SwiftUI

@main
struct LiftLogApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            TabView {
                RoutinesView()
                    .tabItem { Label("Routines", systemImage: "list.bullet.clipboard") }
                HistoryView()
                    .tabItem { Label("History", systemImage: "clock") }
                ExercisesView()
                    .tabItem { Label("Exercises", systemImage: "dumbbell") }
                SettingsView()
                    .tabItem { Label("More", systemImage: "ellipsis.circle") }
            }
            .environmentObject(store)
        }
    }
}
