import Foundation

// MARK: - Week Completion Snapshot
//
// A lightweight read of what has already happened in the current training
// week, built by scanning past days before today. The snapshot deliberately
// excludes today's workout and any future days so the coaching engine only
// sees decisions the runner has already made — not speculative future state.
//
// Used by WorkoutCoachingEngine to produce completion-aware "THIS WEEK"
// coaching context that responds to how the week has actually gone.

struct WeekCompletionSnapshot {

    // MARK: - Stored Properties

    /// Workouts completed or modified so far (past days only, before today).
    let completedCount  : Int

    /// Total trackable (non-rest) workouts in the whole week.
    let trackableCount  : Int

    /// Workouts explicitly skipped before today.
    let skippedCount    : Int

    /// Quality sessions (tempo / speed / strength / LT / intervals) completed.
    let qualityDone     : Int

    /// Quality sessions planned for the entire week (excludes today).
    let qualityTotal    : Int

    /// Whether the long run has been marked complete this week.
    let longRunDone     : Bool

    /// Actual miles logged on the long run, if completed.
    let longRunActual   : Double?

    /// Planned miles for the long run.
    let longRunPlanned  : Double

    // MARK: - Derived

    /// Fraction of the whole week's trackable workouts that are done.
    var completionPct   : Double { Double(completedCount) / Double(max(1, trackableCount)) }

    /// True when at least one session has been skipped before today.
    var hasSkips        : Bool   { skippedCount > 0 }

    /// True when all quality sessions for the week are already complete.
    var allQualityDone  : Bool   { qualityTotal > 0 && qualityDone >= qualityTotal }

    /// True when no past days have been completed OR skipped yet.
    var noPriorActivity : Bool   { completedCount == 0 && skippedCount == 0 }

    /// True when the long run was run meaningfully longer than planned
    /// (≥10% over AND ≥1.5 miles over, to avoid false positives on small plans).
    var longRunOverrun  : Bool {
        guard longRunDone, let actual = longRunActual, longRunPlanned > 0 else {
            return false
        }
        return actual >= longRunPlanned * 1.10 && actual >= longRunPlanned + 1.5
    }

    // MARK: - Builder

    /// Build a snapshot from a SavedWeek, excluding today's workout.
    /// Only days strictly before today are counted as "completed" or "skipped"
    /// so that future pre-marked sessions don't pollute this week's picture.
    static func from(_ week: SavedWeek,
                     excludingDayID dayID: UUID) -> WeekCompletionSnapshot {
        let startOfToday = Calendar.current.startOfDay(for: Date())

        // Days before today, not today
        let pastDays = week.days.filter {
            $0.id != dayID && $0.date < startOfToday
        }

        let completed = pastDays.filter {
            $0.isTrackable
                && ($0.completionStatus == .completed
                    || $0.completionStatus == .modified)
        }.count

        let skipped = pastDays.filter {
            $0.isTrackable && $0.completionStatus == .skipped
        }.count

        // Trackable count across the whole week (for proportion context)
        let trackable = week.days.filter { $0.isTrackable }.count

        // Quality: count done from past days, total from whole week (excl today)
        let qualityDone = pastDays.filter {
            $0.isQualityDay
                && ($0.completionStatus == .completed
                    || $0.completionStatus == .modified)
        }.count

        let qualityTotal = week.days.filter {
            $0.id != dayID && $0.isQualityDay
        }.count

        // Long run: can be past OR future — we care about whether it's done
        let longRunDay  = week.days.first { $0.isLongRunDay }
        let longRunDone = longRunDay.map {
            $0.completionStatus == .completed || $0.completionStatus == .modified
        } ?? false

        return WeekCompletionSnapshot(
            completedCount: completed,
            trackableCount: trackable,
            skippedCount:   skipped,
            qualityDone:    qualityDone,
            qualityTotal:   qualityTotal,
            longRunDone:    longRunDone,
            longRunActual:  longRunDay?.actualMiles,
            longRunPlanned: longRunDay?.miles ?? 0
        )
    }
}

// MARK: - SavedDay classification (file-private)
// These properties match workout type strings without requiring a WorkoutType
// enum conversion, keeping the snapshot builder independent of TrainingPlan.

private extension SavedDay {

    var isQualityDay: Bool {
        switch workoutType {
        case "Strength (MP)", "Speed Work", "Lactate Threshold",
             "Cruise Intervals", "Interval Work", "Repetition Work",
             "Tempo Run", "Marathon Pace":
            return true
        default:
            return false
        }
    }

    var isLongRunDay: Bool {
        workoutType == "Long Run"
            || workoutType == "Long Run w/ MP Finish"
            || workoutType == "Long Run w/ HMP Finish"
    }
}
