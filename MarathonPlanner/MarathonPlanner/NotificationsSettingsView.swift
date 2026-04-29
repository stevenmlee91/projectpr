import SwiftUI
import UserNotifications

// MARK: - Notification Settings View
//
// Embedded inside SettingsView as a section.
// Can also be used standalone.

struct NotificationSettingsView: View {
    @ObservedObject var nm: NotificationManager
    @EnvironmentObject var store: PlanStore

    // Local state mirrors UserDefaults via the manager
    @State private var enabled = false
    @State private var reminderTime = Date()
    @State private var showDeniedAlert = false

    var body: some View {
        Section {
            // Enable / disable toggle
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Daily Workout Reminder")
                        .foregroundColor(.primary)
                    Text(statusSubtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: $enabled)
                    .labelsHidden()
                    .onChange(of: enabled) { newValue in
                        handleToggle(newValue)
                    }
            }

            // Time picker — only shown when enabled and authorized
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

            // Denied state — link to Settings
            if nm.authorizationStatus == .denied {
                Button {
                    nm.openSystemSettings()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
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
        .onAppear {
            syncStateFromManager()
        }
    }

    // MARK: - Helpers

    private var statusSubtitle: String {
        switch nm.authorizationStatus {
        case .authorized:
            return enabled ? "Reminders are on" : "Reminders are off"
        case .denied:
            return "Blocked in iOS Settings"
        case .notDetermined:
            return "Tap to enable"
        default:
            return ""
        }
    }

    private func syncStateFromManager() {
        enabled = nm.notificationsEnabled && nm.authorizationStatus == .authorized

        // Reconstruct the Date from stored hour/minute
        var components        = Calendar.current.dateComponents([.year,.month,.day],
                                                                from: Date())
        components.hour       = nm.reminderHour
        components.minute     = nm.reminderMinute
        reminderTime = Calendar.current.date(from: components) ?? Date()
    }

    private func handleToggle(_ isOn: Bool) {
        if isOn {
            switch nm.authorizationStatus {
            case .authorized:
                nm.notificationsEnabled = true
                nm.scheduleWorkoutReminders(
                    for:       store.plans,
                    primaryID: store.primaryPlanID
                )
            case .notDetermined:
                nm.requestPermission { granted in
                    if granted {
                        nm.notificationsEnabled = true
                        nm.scheduleWorkoutReminders(
                            for:       store.plans,
                            primaryID: store.primaryPlanID
                        )
                    } else {
                        // Permission denied — flip toggle back
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
            nm.notificationsEnabled = false
            nm.cancelAll()
        }
    }
}
