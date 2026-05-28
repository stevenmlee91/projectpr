import Foundation
import UserNotifications

// MARK: - Weekly Summary Manager

final class WeeklySummaryManager {

    static let shared = WeeklySummaryManager()
    private init() {}

    private let notificationID = "mile_zero_weekly_summary"

    // MARK: - Schedule

    func scheduleWeeklySummary(for plans: [SavedPlan],
                                primaryID: UUID?) {
        // Cancel existing before rescheduling
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(
                withIdentifiers: [notificationID])

        // Only schedule if there is an active primary plan
        guard
            let plan = activePlan(from: plans, primaryID: primaryID),
            let body = generateBody(for: plan)
        else { return }

        let content       = UNMutableNotificationContent()
        content.title     = "Week Complete 🏃"
        content.body      = body
        content.sound     = .default
        content.userInfo  = ["destination": "weekly_summary"]

        // Sunday at 18:00 local time
        var components    = DateComponents()
        components.weekday = 1   // Sunday
        components.hour    = 18
        components.minute  = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats:      true
        )

        let request = UNNotificationRequest(
            identifier: notificationID,
            content:    content,
            trigger:    trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ WeeklySummary schedule error: \(error)")
            }
        }
    }

    func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(
                withIdentifiers: [notificationID])
    }

    // MARK: - Body Generation

    func generateBody(for plan: SavedPlan) -> String? {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())

        // Find current week
        guard let currentWeek = plan.weeks.first(where: { week in
            week.days.contains {
                cal.isDate($0.date, inSameDayAs: today)
            }
        }) else { return nil }

        // Actual miles run this week
        let actualMiles = currentWeek.actualTotalMiles
        let milesText   = actualMiles > 0
            ? String(format: "%.0f miles", actualMiles)
            : "0 miles"

        // Long run status
        let longRunDone = currentWeek.days.contains {
            let isLong = $0.workoutType == "Long Run"
                || $0.workoutType == "Long Run w/ MP Finish"
                || $0.workoutType == "Long Run w/ HMP Finish"
            let isDone = $0.completionStatus == .completed
                || $0.completionStatus == .modified
            return isLong && isDone
        }
        let longRunText = longRunDone ? "Long run ✓" : "Long run missed"

        // Completion rate
        let pct      = Int(currentWeek.completionPercentage * 100)
        let pctText  = "\(pct)% complete"

        // Next week preview
        let nextWeekPreview: String
        if let nextWeek = plan.weeks.first(where: {
            $0.weekNumber == currentWeek.weekNumber + 1
        }) {
            let nextMiles = String(format: "%.0f", nextWeek.totalMiles)
            let nextLong  = nextWeek.days
                .filter {
                    $0.workoutType == "Long Run"
                        || $0.workoutType == "Long Run w/ MP Finish"
                        || $0.workoutType == "Long Run w/ HMP Finish"
                }
                .map { $0.miles }
                .max() ?? 0

            if nextLong > 0 {
                nextWeekPreview = "Next week: \(nextMiles) mi, "
                    + "\(Int(nextLong))-mile long run."
            } else {
                nextWeekPreview = "Next week: \(nextMiles) miles planned."
            }
        } else {
            nextWeekPreview = "Race week is coming. Stay sharp."
        }

        return "You ran \(milesText) this week. "
            + "\(longRunText) · \(pctText). "
            + nextWeekPreview
    }

    // MARK: - Helpers

    private func activePlan(from plans: [SavedPlan],
                             primaryID: UUID?) -> SavedPlan? {
        if let id = primaryID,
           let plan = plans.first(where: { $0.id == id }) {
            return plan
        }
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        return plans.filter { p in
            let start = cal.startOfDay(for: p.startDate)
            let end   = cal.startOfDay(for: p.raceDate)
            return today >= start && today <= end
        }.sorted { $0.raceDate < $1.raceDate }.first
    }
}
