import SwiftUI

@main
struct MarathonTrainerApp: App {
    @StateObject private var store             = PlanStore()
    @StateObject private var appearanceManager = AppearanceManager()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .environmentObject(appearanceManager)
                // This single modifier controls the entire app's color scheme.
                // nil = follow system, .light = force light, .dark = force dark
                .preferredColorScheme(appearanceManager.appearance.colorScheme)
        }
    }
}

struct RootTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "figure.run")
                }
            PlanListView()
                .tabItem {
                    Label("Plans", systemImage: "list.bullet.rectangle")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        // Remove the hardcoded .colorScheme(.dark) from here.
        // preferredColorScheme on the root WindowGroup handles everything.
        .tint(.primary)
    }
}
