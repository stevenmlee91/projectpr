import SwiftUI
import UserNotifications

// MARK: - Notification Delegate

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationDelegate()

    // Called when notification is tapped (foreground or background)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler handler: @escaping () -> Void
    ) {
        let dest = response.notification.request.content
            .userInfo["destination"] as? String

        if dest == "weekly_summary" {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenWeeklySummary"),
                    object: nil
                )
            }
        }
        handler()
    }

    // Show banner even when app is foregrounded
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler handler: @escaping (
            UNNotificationPresentationOptions) -> Void
    ) {
        handler([.banner, .sound])
    }
}

// MARK: - App

@main
struct MarathonTrainerApp: App {
    @StateObject private var store               = PlanStore()
    @StateObject private var appearanceManager   = AppearanceManager()
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var routeStore          = SavedRouteStore()
    @State       private var selectedTab         : Int  = 0
    @State       private var showWeeklySummary   : Bool = false

    @AppStorage("hasCompletedOnboarding")
    private var hasCompletedOnboarding: Bool = false

    init() {
        // Register delegate so notification taps are handled
        UNUserNotificationCenter.current().delegate =
            NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                RootTabView(
                    selectedTab:       $selectedTab,
                    showWeeklySummary: $showWeeklySummary
                )
                .environmentObject(store)
                .environmentObject(appearanceManager)
                .environmentObject(notificationManager)
                .environmentObject(routeStore)
                .preferredColorScheme(
                    appearanceManager.appearance.colorScheme)
                .onAppear {
                    store.syncWidget()
                    notificationManager.refreshAuthorizationStatus()
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + 0.5) {
                        notificationManager.scheduleWorkoutReminders(
                            for:       store.plans,
                            primaryID: store.primaryPlanID
                        )
                        WeeklySummaryManager.shared
                            .scheduleWeeklySummary(
                                for:       store.plans,
                                primaryID: store.primaryPlanID
                            )
                    }
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                // Listen for weekly summary deep link from notification tap
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSNotification.Name("OpenWeeklySummary"))
                ) { _ in
                    showWeeklySummary = true
                }
                // Present summary sheet
                .sheet(isPresented: $showWeeklySummary) {
                    if let plan = store.primaryPlan {
                        WeeklySummaryView(plan: plan)
                    }
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
        case "today":          selectedTab = 0
        case "plans":          selectedTab = 1
        case "pace":           selectedTab = 2
        case "route":          selectedTab = 3
        case "weekly_summary": showWeeklySummary = true
        default:               selectedTab = 0
        }
    }
}

// MARK: - Root Tab View

struct RootTabView: View {
    @Binding var selectedTab       : Int
    @Binding var showWeeklySummary : Bool
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
