import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appearanceManager   : AppearanceManager
    @EnvironmentObject var store               : PlanStore
    @EnvironmentObject var notificationManager : NotificationManager

    @AppStorage("hasCompletedOnboarding")
    private var hasCompletedOnboarding: Bool = false

    var body: some View {
        NavigationStack {
            List {

                // MARK: Notifications
                NotificationSettingsView(nm: notificationManager)
                    .environmentObject(store)

                // MARK: Appearance
                appearanceSection

                // MARK: Onboarding
                onboardingSection

                // MARK: About
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
                                .font(.system(size: 14,
                                              weight: .semibold))
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

    // MARK: - Onboarding

    private var onboardingSection: some View {
        Section {
            Button {
                hasCompletedOnboarding = false
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color(hex: "0A84FF"))
                            .frame(width: 28, height: 28)
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Text("Replay Onboarding")
                        .foregroundColor(.primary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } header: {
            Text("Help")
        } footer: {
            Text("See the welcome tour again from the beginning.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color(.secondarySystemBackground))
                        .frame(width: 28, height: 28)
                    Image(systemName: "info.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Text("Version")
                    .padding(.leading, 2)
                Spacer()
                Text(Bundle.main.infoDictionary?[
                    "CFBundleShortVersionString"]
                     as? String ?? "1.0")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14, design: .monospaced))
            }

            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color(hex: "30D158").opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "30D158"))
                }
                Text("Active Plans")
                    .padding(.leading, 2)
                Spacer()
                Text("\(store.plans.count)")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14, design: .monospaced))
            }

            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color(hex: "FF9F0A").opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: "figure.run")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "FF9F0A"))
                }
                Text("Mile Zero")
                    .padding(.leading, 2)
                Spacer()
                Text("Built for runners")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
            }
        } header: {
            Text("About")
        }
    }
}
