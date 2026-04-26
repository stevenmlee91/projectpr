import SwiftUI

@main
struct MarathonTrainerApp: App {
    @StateObject private var store = PlanStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
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
        }
        .colorScheme(.dark)
        .tint(.white)
    }
}
