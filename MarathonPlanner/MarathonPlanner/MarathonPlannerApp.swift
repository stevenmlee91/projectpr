import SwiftUI
import UserNotifications

@main
struct MarathonTrainerApp: App {
    @StateObject private var store             = PlanStore()
    @StateObject private var appearanceManager = AppearanceManager()
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var routeStore        = SavedRouteStore()
    @State       private var selectedTab       : Int = 0

    @AppStorage("hasCompletedOnboarding")
    private var hasCompletedOnboarding: Bool = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                RootTabView(selectedTab: $selectedTab)
                    .environmentObject(store)
                    .environmentObject(appearanceManager)
                    .environmentObject(notificationManager)
                    .environmentObject(routeStore)
                    .preferredColorScheme(
                        appearanceManager.appearance.colorScheme)
                    .onAppear {
                        notificationManager.refreshAuthorizationStatus()
                        DispatchQueue.main.asyncAfter(
                            deadline: .now() + 0.5) {
                            notificationManager.scheduleWorkoutReminders(
                                for:       store.plans,
                                primaryID: store.primaryPlanID
                            )
                        }
                    }
                    .onOpenURL { url in
                        handleDeepLink(url)
                    }
            } else {
                OnboardingView(
                    hasCompletedOnboarding: $hasCompletedOnboarding
                )
                .environmentObject(store)
                .preferredColorScheme(
                    appearanceManager.appearance.colorScheme)
            }
        }
    }

    // MARK: - Deep Link

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "milezero" else { return }
        switch url.host {
        case "today":  selectedTab = 0
        case "plans":  selectedTab = 1
        case "pace":   selectedTab = 2
        case "route":  selectedTab = 3
        default:       selectedTab = 0
        }
    }
}

// MARK: - Root Tab View

struct RootTabView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var routeStore: SavedRouteStore

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "figure.run")
                }
                .tag(0)

            PlanListView()
                .tabItem {
                    Label("Plans", systemImage: "list.bullet.rectangle")
                }
                .tag(1)

            PaceCalculatorView()
                .tabItem {
                    Label("Pace", systemImage: "speedometer")
                }
                .tag(2)

            RouteBuilderView()
                .environmentObject(routeStore)
                .tabItem {
                    Label("Route", systemImage: "map")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(4)
        }
        .tint(.primary)
    }
}
