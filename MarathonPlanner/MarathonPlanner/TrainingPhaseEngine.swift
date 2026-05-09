import Foundation

// MARK: - Training Phase

enum TrainingPhase: String {
    case base   = "Base"
    case build  = "Build"
    case peak   = "Peak"
    case taper  = "Taper"
    case race   = "Race"
}

// MARK: - Phase Engine

struct TrainingPhaseEngine {

    // MARK: - Public API

    /// Assigns exactly one TrainingPhase to each week index (1-based).
    /// This is the single source of truth for phase classification.
    /// Week labels on SavedWeek.phase are used only as display text —
    /// never for logic decisions.
    static func phase(
        weekNumber  : Int,
        totalWeeks  : Int,
        taperWeeks  : Int,   // typically 1 for half, 2–3 for marathon
        peakWeeks   : Int    // typically 1–2
    ) -> TrainingPhase {

        let raceWeek  = totalWeeks
        let taperStart = raceWeek - taperWeeks
        let peakStart  = taperStart - peakWeeks

        // Priority order — exactly one phase assigned
        if weekNumber == raceWeek  { return .race  }
        if weekNumber >= taperStart { return .taper }
        if weekNumber >= peakStart  { return .peak  }

        // Split remaining weeks into base and build
        let buildWeeks = max(1, peakStart - 1)
        let baseEnd    = max(1, buildWeeks / 2)

        if weekNumber <= baseEnd { return .base }
        return .build
    }

    /// Derives taper length from a SavedPlan's settings.
    /// Half marathon = 1 week. Marathon = taperDuration setting.
    static func taperWeeks(for plan: SavedPlan) -> Int {
        plan.settings.raceType == .halfMarathon
            ? 1
            : plan.settings.taperDuration.rawValue
    }

    /// Derives peak weeks — always 1 for simplicity.
    static func peakWeeks(for plan: SavedPlan) -> Int { 1 }

    /// Returns the canonical peak week number for a plan.
    static func peakWeekNumber(for plan: SavedPlan) -> Int {
        let total  = plan.weeks.count
        let taper  = taperWeeks(for: plan)
        let peak   = peakWeeks(for: plan)
        return total - taper - peak + 1
    }
}
