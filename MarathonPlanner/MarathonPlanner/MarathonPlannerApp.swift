import SwiftUI
import UserNotifications

@main
struct MarathonTrainerApp: App {
    @StateObject private var store             = PlanStore()
    @StateObject private var appearanceManager = AppearanceManager()
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .environmentObject(appearanceManager)
                .environmentObject(notificationManager)
                .preferredColorScheme(appearanceManager.appearance.colorScheme)
                .onAppear {
                    // Refresh auth status and reschedule on every launch
                    notificationManager.refreshAuthorizationStatus()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        notificationManager.scheduleWorkoutReminders(
                            for:       store.plans,
                            primaryID: store.primaryPlanID
                        )
                    }
                }
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
        .tint(.primary)
    }
}
