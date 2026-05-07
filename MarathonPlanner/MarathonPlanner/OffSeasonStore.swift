import Foundation
import Combine

// MARK: - Off-Season Day Log

struct OffSeasonDayLog: Codable {
    let date      : Date
    var completed : Bool
    var miles     : Double   // 0 if rest or cross-train
}

// MARK: - Off-Season Store

final class OffSeasonStore: ObservableObject {

    static let shared = OffSeasonStore()

    @Published private(set) var logs: [OffSeasonDayLog] = []

    private let key = "off_season_day_logs_v1"

    private init() { load() }

    // MARK: - Public API

    /// Mark today as completed with optional miles
    func markToday(miles: Double = 0) {
        let today = Calendar.current.startOfDay(for: Date())
        if let idx = logs.firstIndex(where: {
            Calendar.current.isDate($0.date, inSameDayAs: today)
        }) {
            logs[idx].completed = true
            logs[idx].miles     = miles
        } else {
            logs.append(OffSeasonDayLog(date:      today,
                                        completed: true,
                                        miles:     miles))
        }
        persist()
    }

    /// Unmark today
    func unmarkToday() {
        let today = Calendar.current.startOfDay(for: Date())
        if let idx = logs.firstIndex(where: {
            Calendar.current.isDate($0.date, inSameDayAs: today)
        }) {
            logs[idx].completed = false
            logs[idx].miles     = 0
        }
        persist()
    }

    var todayIsCompleted: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return logs.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: today)
        })?.completed ?? false
    }

    // MARK: - Weekly Stats

    /// Days completed in the current Mon–Sun week
    func daysCompletedThisWeek() -> Int {
        logsThisWeek().filter { $0.completed }.count
    }

    /// Miles logged in the current Mon–Sun week
    func milesThisWeek() -> Double {
        logsThisWeek().filter { $0.completed }.reduce(0) { $0 + $1.miles }
    }

    // MARK: - Helpers

    private func logsThisWeek() -> [OffSeasonDayLog] {
        var cal          = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2   // Monday
        let today        = cal.startOfDay(for: Date())
        let weekday      = cal.component(.weekday, from: today)
        let daysSinceMon = (weekday + 5) % 7
        guard let monday = cal.date(byAdding: .day,
                                     value: -daysSinceMon,
                                     to: today) else { return [] }
        let sunday = cal.date(byAdding: .day,
                               value: 6, to: monday) ?? today
        return logs.filter {
            $0.date >= monday && $0.date <= sunday
        }
    }

    // MARK: - Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let saved = try? JSONDecoder().decode(
                [OffSeasonDayLog].self, from: data)
        else { return }
        // Prune logs older than 90 days to keep UserDefaults lean
        let cutoff = Calendar.current.date(
            byAdding: .day, value: -90, to: Date()) ?? Date()
        logs = saved.filter { $0.date >= cutoff }
    }
}

// MARK: - Weekly Goal

struct OffSeasonWeeklyGoal {
    let daysTarget  : Int
    let milesTarget : Double
    let label       : String       // "Run 4 days · 24 miles"
    let subLabel    : String       // contextual copy

    /// Derive a goal from the current off-season context
    static func make(from context: OffSeasonContext) -> OffSeasonWeeklyGoal {
        let miles  = context.weeklyTarget
        let isHalf = context.raceType == .halfMarathon

        // Days target based on fitness and phase
        let days: Int
        switch (context.recoveryPhase, context.fitnessLevel) {
        case (.activeRecovery, _):
            days = 3
        case (.earlyOffSeason, .beginner):
            days = 3
        case (.earlyOffSeason, _):
            days = 4
        case (.baseBuilding, .beginner):
            days = 4
        case (.baseBuilding, .intermediate):
            days = 5
        case (.baseBuilding, .advanced):
            days = 6
        }

        let milesRounded = miles.rounded(toPlaces: 0)
        let label        = "Run \(days) days · \(Int(milesRounded)) miles"

        let sub: String
        switch context.planProximity {
        case .imminent:
            let planName = context.upcomingPlan?.name ?? "your training block"
            return OffSeasonWeeklyGoal(
                daysTarget:  days,
                milesTarget: milesRounded,
                label:       label,
                subLabel:    "Final prep week before \(planName) begins."
            )
        case .approaching:
            sub = isHalf
                ? "Building toward half marathon training."
                : "Building toward marathon training."
        case .far:
            sub = "Consistent base miles this week."
        case .none:
            sub = context.recoveryPhase == .activeRecovery
                ? "Gentle movement only — you are still recovering."
                : "Steady base building this week."
        }

        return OffSeasonWeeklyGoal(
            daysTarget:  days,
            milesTarget: milesRounded,
            label:       label,
            subLabel:    sub
        )
    }
}
