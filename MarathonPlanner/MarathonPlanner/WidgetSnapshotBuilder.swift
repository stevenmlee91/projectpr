import Foundation

// MARK: - Widget Snapshot Builder
// Pure function: SavedPlan → WidgetPlanSnapshot.
// Runs in the main app — has full access to DailyInsightEngine,
// WorkoutCoachingEngine, and all plan data models.
// The widget extension never calls this; it only reads the persisted result.

struct WidgetSnapshotBuilder {

    static func build(from plan: SavedPlan) -> WidgetPlanSnapshot {
        let cal      = Calendar.current
        let today    = cal.startOfDay(for: Date())
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

        // Days to race
        let daysToRace = max(0, cal.dateComponents(
            [.day], from: today,
            to: cal.startOfDay(for: plan.raceDate)).day ?? 0)

        // Find current week, today's day, and tomorrow's day
        var currentWeek : SavedWeek? = nil
        var todayDay    : SavedDay?  = nil
        var tomorrowDay : SavedDay?  = nil

        for week in plan.weeks {
            for day in week.days {
                let d = cal.startOfDay(for: day.date)
                if d == today {
                    todayDay    = day
                    currentWeek = week
                }
                if d == cal.startOfDay(for: tomorrow) {
                    tomorrowDay = day
                }
            }
        }

        let week  = currentWeek ?? plan.weeks.first
        let phase = week?.phase ?? .base

        // Week progress
        let trackable = (week?.days ?? []).filter { $0.workoutType != "Rest" }
        let done      = trackable.filter {
            $0.completionStatus == .completed || $0.completionStatus == .modified
        }

        // Overall progress fraction
        let allTrackable = plan.weeks.flatMap { $0.days }.filter { $0.isTrackable }
        let allDone      = allTrackable.filter {
            $0.completionStatus == .completed || $0.completionStatus == .modified
        }
        let overallFraction = allTrackable.isEmpty
            ? 0.0
            : Double(allDone.count) / Double(allTrackable.count)

        // Methodology-aware display names (e.g. "Strength (HMP)" vs "Strength (MP)")
        let raceType       = plan.settings.raceType
        let todayDisplay   = todayDay?.displayWorkoutType(raceType: raceType)
            ?? (todayDay?.workoutType ?? "Rest")
        let tomorrowDisplay = tomorrowDay?.displayWorkoutType(raceType: raceType)

        // Coaching insight — computed here in main app, stored as plain string in snapshot
        let insight = DailyInsightEngine.generate(for: plan)

        return WidgetPlanSnapshot(
            version:                 1,
            lastUpdated:             Date(),
            hasPlan:                 true,
            planName:                plan.name,
            raceDate:                plan.raceDate,
            raceType:                raceType.rawValue,
            daysToRace:              daysToRace,
            isRaceDay:               daysToRace == 0,
            phase:                   phase.rawValue,
            phaseLabel:              week?.phaseLabel ?? phase.displayName,
            weekNumber:              week?.weekNumber ?? 1,
            totalWeeks:              plan.weeks.count,
            todayWorkoutType:        todayDay?.workoutType ?? "Rest",
            todayDisplayName:        todayDisplay,
            todayMiles:              todayDay?.miles ?? 0,
            todayPaceNote:           todayDay?.paceNote ?? "",
            todayIsRest:             todayDay?.isRestDay ?? true,
            todayCompleted:          todayDay?.completionStatus == .completed
                                         || todayDay?.completionStatus == .modified,
            tomorrowDisplayName:     tomorrowDisplay,
            tomorrowMiles:           tomorrowDay?.miles,
            tomorrowIsRest:          tomorrowDay?.isRestDay,
            weekMilesPlanned:        week?.totalMiles ?? 0,
            weekMilesActual:         week?.actualTotalMiles ?? 0,
            weekWorkoutsCompleted:   done.count,
            weekWorkoutsTotal:       trackable.count,
            insightMessage:          insight.message,
            insightDetail:           insight.detail,
            overallProgressFraction: overallFraction
        )
    }
}
