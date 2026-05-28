import Foundation

// MARK: - Widget Plan Snapshot
// Lightweight, Codable model shared between the main app and widget extension.
// The main app builds this from a SavedPlan and writes it to the shared App Group.
// The widget extension reads it — it never touches SavedPlan directly.

struct WidgetPlanSnapshot: Codable {
    let version     : Int       // schema version for forward migration
    let lastUpdated : Date

    // Identity
    let hasPlan  : Bool
    let planName : String
    let raceDate : Date
    let raceType : String       // RaceType.rawValue ("Marathon" / "Half Marathon")

    // Countdown
    let daysToRace : Int
    let isRaceDay  : Bool

    // Phase / week context
    let phase      : String     // TrainingPhase.rawValue
    let phaseLabel : String
    let weekNumber : Int
    let totalWeeks : Int

    // Today
    let todayWorkoutType : String
    let todayDisplayName : String
    let todayMiles       : Double
    let todayPaceNote    : String
    let todayIsRest      : Bool
    let todayCompleted   : Bool

    // Tomorrow preview
    let tomorrowDisplayName : String?
    let tomorrowMiles       : Double?
    let tomorrowIsRest      : Bool?

    // Week progress
    let weekMilesPlanned       : Double
    let weekMilesActual        : Double
    let weekWorkoutsCompleted  : Int
    let weekWorkoutsTotal      : Int

    // Coaching (pre-computed by DailyInsightEngine in main app)
    let insightMessage : String
    let insightDetail  : String?

    // Overall
    let overallProgressFraction : Double
}

// MARK: - App Group I/O

extension WidgetPlanSnapshot {
    static let appGroupID      = "group.MarathonPlanner.milezero"
    static let userDefaultsKey = "widget_plan_snapshot_v1"

    static func read() -> WidgetPlanSnapshot? {
        guard
            let defaults = UserDefaults(suiteName: appGroupID),
            let data     = defaults.data(forKey: userDefaultsKey),
            let snapshot = try? JSONDecoder().decode(
                WidgetPlanSnapshot.self, from: data)
        else { return nil }
        return snapshot
    }

    func write() {
        guard
            let defaults = UserDefaults(suiteName: Self.appGroupID),
            let data     = try? JSONEncoder().encode(self)
        else { return }
        defaults.set(data, forKey: Self.userDefaultsKey)
    }

    static func clear() {
        UserDefaults(suiteName: appGroupID)?
            .removeObject(forKey: userDefaultsKey)
    }
}

// MARK: - Placeholder (widget gallery preview)

extension WidgetPlanSnapshot {
    static var placeholder: WidgetPlanSnapshot {
        WidgetPlanSnapshot(
            version: 1, lastUpdated: Date(),
            hasPlan: true, planName: "Chicago Marathon",
            raceDate: Date().addingTimeInterval(86400 * 42),
            raceType: "Marathon",
            daysToRace: 42, isRaceDay: false,
            phase: "build", phaseLabel: "Building Fitness",
            weekNumber: 9, totalWeeks: 18,
            todayWorkoutType: "Easy",
            todayDisplayName: "Easy Run",
            todayMiles: 8,
            todayPaceNote: "Conversational pace",
            todayIsRest: false, todayCompleted: false,
            tomorrowDisplayName: "Long Run",
            tomorrowMiles: 18, tomorrowIsRest: false,
            weekMilesPlanned: 52, weekMilesActual: 22,
            weekWorkoutsCompleted: 3, weekWorkoutsTotal: 5,
            insightMessage: "Long run tomorrow.",
            insightDetail: "18 miles. Sleep well tonight.",
            overallProgressFraction: 0.45
        )
    }

    static var empty: WidgetPlanSnapshot {
        WidgetPlanSnapshot(
            version: 1, lastUpdated: Date(),
            hasPlan: false, planName: "",
            raceDate: Date(), raceType: "Marathon",
            daysToRace: 0, isRaceDay: false,
            phase: "base", phaseLabel: "Base Building",
            weekNumber: 1, totalWeeks: 18,
            todayWorkoutType: "Rest",
            todayDisplayName: "Rest",
            todayMiles: 0, todayPaceNote: "",
            todayIsRest: true, todayCompleted: false,
            tomorrowDisplayName: nil,
            tomorrowMiles: nil, tomorrowIsRest: nil,
            weekMilesPlanned: 0, weekMilesActual: 0,
            weekWorkoutsCompleted: 0, weekWorkoutsTotal: 0,
            insightMessage: "Add a training plan to get started.",
            insightDetail: nil,
            overallProgressFraction: 0
        )
    }
}
