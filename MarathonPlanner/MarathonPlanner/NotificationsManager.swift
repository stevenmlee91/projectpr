import Foundation
import UserNotifications
import SwiftUI

// MARK: - Notification Manager

class NotificationManager: ObservableObject {

    static let shared = NotificationManager()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()
    private let reminderHourKey   = "notification_reminder_hour"
    private let reminderMinuteKey = "notification_reminder_minute"
    private let enabledKey        = "notifications_enabled"

    // Default reminder time — 7:00 AM
    var reminderHour: Int {
        get { UserDefaults.standard.object(forKey: reminderHourKey) as? Int ?? 7 }
        set { UserDefaults.standard.set(newValue, forKey: reminderHourKey) }
    }

    var reminderMinute: Int {
        get { UserDefaults.standard.object(forKey: reminderMinuteKey) as? Int ?? 0 }
        set { UserDefaults.standard.set(newValue, forKey: reminderMinuteKey) }
    }

    var notificationsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    init() {
        refreshAuthorizationStatus()
    }

    // MARK: - Permission

    func refreshAuthorizationStatus() {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.refreshAuthorizationStatus()
                completion(granted)
            }
        }
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Schedule

    // Call this whenever plans change, primary plan changes,
    // reminder time changes, or app launches.
    func scheduleWorkoutReminders(for plans: [SavedPlan], primaryID: UUID?) {
        guard notificationsEnabled,
              authorizationStatus == .authorized else { return }

        // Find the primary plan
        guard let primaryID = primaryID,
              let plan = plans.first(where: { $0.id == primaryID })
        else { return }

        // Cancel existing scheduled notifications before rescheduling
        center.removePendingNotificationRequests(withIdentifiers:
            (0..<7).map { "workout_reminder_day_\($0)" }
        )

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // Schedule next 7 days
        for dayOffset in 0..<7 {
            guard let targetDate = cal.date(byAdding: .day,
                                            value: dayOffset,
                                            to: today)
            else { continue }

            // Find the day in the plan that matches this date
            let matchingDay = plan.weeks
                .flatMap { $0.days }
                .first { cal.isDate($0.date, inSameDayAs: targetDate) }

            // Build notification content
            let content = UNMutableNotificationContent()
            content.sound = .default

            if let day = matchingDay {
                content.title = notificationTitle(for: day)
                content.body  = notificationBody(for: day)
                content.userInfo = ["planID": plan.id.uuidString,
                                    "date":   targetDate.timeIntervalSince1970]
            } else {
                // Day not in plan range — skip
                continue
            }

            // Fire at user's chosen reminder time on this date
            var triggerComponents        = cal.dateComponents([.year, .month, .day],
                                                              from: targetDate)
            triggerComponents.hour       = reminderHour
            triggerComponents.minute     = reminderMinute
            triggerComponents.second     = 0

            // Do not schedule if the trigger time has already passed today
            if dayOffset == 0 {
                let now = Date()
                var todayTrigger = cal.dateComponents([.year, .month, .day],
                                                      from: now)
                todayTrigger.hour   = reminderHour
                todayTrigger.minute = reminderMinute
                todayTrigger.second = 0
                if let triggerDate = cal.date(from: todayTrigger),
                   triggerDate <= now {
                    continue
                }
            }

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: triggerComponents,
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: "workout_reminder_day_\(dayOffset)",
                content:    content,
                trigger:    trigger
            )

            center.add(request)
        }
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Notification Content Builders

    private func notificationTitle(for day: SavedDay) -> String {
        switch day.workoutType {
        case "Rest":
            return "Rest Day 🌙"
        case "Race Day 🏁":
            return "Race Day 🏁 It's time."
        case "Long Run", "Long Run w/ MP Finish":
            return "Long Run Day 🏃"
        case "Tempo Run", "Lactate Threshold":
            return "Quality Session ⚡️"
        case "Easy Run", "Recovery Run":
            return "Easy Run Day"
        default:
            return "Today's Workout"
        }
    }

    private func notificationBody(for day: SavedDay) -> String {
        switch day.workoutType {
        case "Rest":
            return "Rest is training. Recover well today."
        case "Race Day 🏁":
            return "26.2 miles. You trained for this. Run free."
        default:
            var body = ""
            if day.miles > 0 {
                body += String(format: "%.0f mi", day.miles)
            }
            if !day.workoutType.isEmpty && day.workoutType != "Rest" {
                body += body.isEmpty ? day.workoutType : " · \(day.workoutType)"
            }
            if !day.paceNote.isEmpty && day.paceNote != "—" {
                body += " · \(day.paceNote)"
            }
            return body.isEmpty ? "Check the app for today's workout." : body
        }
    }
}
