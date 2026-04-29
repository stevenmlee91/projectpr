import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appearanceManager   : AppearanceManager
    @EnvironmentObject var store               : PlanStore
    @EnvironmentObject var notificationManager : NotificationManager

    var body: some View {
        NavigationStack {
            List {
                // Notifications
                NotificationSettingsView(nm: notificationManager)
                    .environmentObject(store)

                // Appearance
                appearanceSection

                // About
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section {
            ForEach(AppAppearance.allCases, id: \.self) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appearanceManager.appearance = option
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: option.icon)
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                            .frame(width: 28)
                        Text(option.displayName)
                            .foregroundColor(.primary)
                        Spacer()
                        if appearanceManager.appearance == option {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Appearance")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"]
                     as? String ?? "1.0")
                    .foregroundColor(.secondary)
            }
            HStack {
                Text("Active Plans")
                Spacer()
                Text("\(store.plans.count)")
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("About")
        }
    }
}
