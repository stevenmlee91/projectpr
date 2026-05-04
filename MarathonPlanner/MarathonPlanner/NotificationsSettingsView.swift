import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @ObservedObject var nm: NotificationManager
    @EnvironmentObject var store: PlanStore

    @State private var enabled      = false
    @State private var reminderTime = Date()

    var body: some View {
        Section {

            // MARK: Toggle row — fully custom, no system Toggle
            Button {
                handleToggle(!enabled)
            } label: {
                HStack(spacing: 14) {
                    // Icon badge
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(enabled
                                  ? Color(hex: "30D158")
                                  : Color(.systemGray4))
                            .frame(width: 28, height: 28)
                        Image(systemName: enabled
                              ? "bell.fill"
                              : "bell.slash.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    // Labels
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Daily Workout Reminder")
                            .foregroundColor(.primary)
                            .font(.system(size: 16))
                        Text(statusSubtitle)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Custom pill toggle
                    ZStack(alignment: enabled ? .trailing : .leading) {
                        Capsule()
                            .fill(enabled
                                  ? Color(hex: "30D158")
                                  : Color(.systemGray4))
                            .frame(width: 48, height: 28)
                        Circle()
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.15),
                                    radius: 2, y: 1)
                            .frame(width: 24, height: 24)
                            .padding(2)
                    }
                    .animation(.spring(response: 0.3,
                                       dampingFraction: 0.7),
                               value: enabled)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // MARK: Time picker
            if enabled && nm.authorizationStatus == .authorized {
                DatePicker(
                    "Reminder Time",
                    selection: $reminderTime,
                    displayedComponents: .hourAndMinute
                )
                .onChange(of: reminderTime) { newTime in
                    let components = Calendar.current.dateComponents(
                        [.hour, .minute], from: newTime)
                    nm.reminderHour   = components.hour   ?? 7
                    nm.reminderMinute = components.minute ?? 0
                    nm.scheduleWorkoutReminders(
                        for:       store.plans,
                        primaryID: store.primaryPlanID
                    )
                }
            }

            // MARK: Denied banner
            if nm.authorizationStatus == .denied {
                Button {
                    nm.openSystemSettings()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Notifications blocked — tap to open Settings")
                            .font(.system(size: 13))
                            .foregroundColor(.orange)
                    }
                }
                .buttonStyle(.plain)
            }

        } header: {
            Text("Notifications")
        } footer: {
            if nm.authorizationStatus == .authorized && enabled {
                Text("Mile Zero will remind you of today's workout from your active plan each morning.")
                    .font(.system(size: 11))
            }
        }
        .listRowBackground(Color(.secondarySystemGroupedBackground))
        .onAppear {
            syncStateFromManager()
        }
    }

    // MARK: - Helpers

    private var statusSubtitle: String {
        switch nm.authorizationStatus {
        case .authorized:
            return enabled ? "Reminders on" : "Reminders off"
        case .denied:
            return "Blocked in iOS Settings"
        case .notDetermined:
            return "Tap to enable"
        default:
            return ""
        }
    }

    private func syncStateFromManager() {
        enabled = nm.notificationsEnabled
            && nm.authorizationStatus == .authorized

        var components    = Calendar.current.dateComponents(
            [.year, .month, .day], from: Date())
        components.hour   = nm.reminderHour
        components.minute = nm.reminderMinute
        reminderTime      = Calendar.current.date(from: components) ?? Date()
    }

    private func handleToggle(_ isOn: Bool) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        if isOn {
            switch nm.authorizationStatus {
            case .authorized:
                enabled                 = true
                nm.notificationsEnabled = true
                nm.scheduleWorkoutReminders(
                    for:       store.plans,
                    primaryID: store.primaryPlanID
                )
            case .notDetermined:
                nm.requestPermission { granted in
                    if granted {
                        enabled                 = true
                        nm.notificationsEnabled = true
                        nm.scheduleWorkoutReminders(
                            for:       store.plans,
                            primaryID: store.primaryPlanID
                        )
                    } else {
                        enabled = false
                    }
                }
            case .denied:
                enabled = false
                nm.openSystemSettings()
            default:
                enabled = false
            }
        } else {
            enabled                 = false
            nm.notificationsEnabled = false
            nm.cancelAll()
        }
    }
}
