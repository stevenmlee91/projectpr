import Foundation

// MARK: - Training Phase

enum TrainingPhase: String {
    case base  = "Base"
    case build = "Build"
    case peak  = "Peak"
    case taper = "Taper"
    case race  = "Race"
}

// MARK: - Phase Engine

struct TrainingPhaseEngine {

    // MARK: - Core Phase Assignment

    static func phase(
        weekNumber    : Int,
        totalWeeks    : Int,
        taperWeeks    : Int,
        peakWeekNumber: Int
    ) -> TrainingPhase {
        let raceWeek   = totalWeeks
        let taperStart = raceWeek - taperWeeks

        if weekNumber == raceWeek       { return .race  }
        if weekNumber >= taperStart     { return .taper }
        if weekNumber == peakWeekNumber { return .peak  }

        let prePeakEnd = max(1, peakWeekNumber - 1)
        let baseEnd    = max(1, prePeakEnd / 2)
        return weekNumber <= baseEnd ? .base : .build
    }

    // MARK: - Taper Weeks
    //
    // taperDuration.rawValue (e.g. 2) counts the race week itself.
    // The engine handles race week separately, so the actual taper
    // window is always taperDuration - 1.
    //
    // Examples:
    //   taperDuration = 2  →  1 taper week  +  1 race week  ✓
    //   taperDuration = 3  →  2 taper weeks +  1 race week  ✓

    static func taperWeeks(for plan: SavedPlan) -> Int {
        max(1, plan.settings.taperDuration.rawValue - 1)
    }

    // MARK: - Peak Week Detection (data-derived)
    //
    // Scans actual planned mileage across all pre-taper, pre-race weeks.
    // Tiebreaker: later week wins.

    static func peakWeekNumber(for plan: SavedPlan) -> Int {
        let total      = plan.weeks.count
        let taper      = taperWeeks(for: plan)
        let taperStart = total - taper      // first taper week number

        // Exclude taper weeks and race week from consideration
        let candidates = plan.weeks.filter {
            $0.weekNumber < taperStart && $0.weekNumber < total
        }

        guard !candidates.isEmpty else {
            return max(1, taperStart - 1)
        }

        // Higher mileage wins; later week wins ties
        let peak = candidates.max { a, b in
            if a.totalMiles == b.totalMiles {
                return a.weekNumber < b.weekNumber
            }
            return a.totalMiles < b.totalMiles
        }

        return peak?.weekNumber ?? max(1, taperStart - 1)
    }
}
