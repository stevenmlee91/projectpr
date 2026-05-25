import Foundation

// MARK: - Training Phase Engine
// Single source of truth for all phase assignment logic.
// Call assignPhases(to:settings:) AFTER plan generation is complete.
// No other system should assign or invent phases.

struct TrainingPhaseEngine {

    // MARK: - Main Entry Point

    /// Assigns canonical TrainingPhase to every week in the plan.
    /// Must be called after all workouts and mileage are finalised.
    ///
    /// Assignment order (highest priority wins):
    ///   1. Race   — always the last week
    ///   2. Taper  — positionally derived from taperDuration
    ///   3. Peak   — data-derived: highest mileage pre-taper week
    ///   4. Build  — weeks in the second half before peak
    ///   5. Base   — weeks in the first half before peak
    static func assignPhases(to weeks: inout [TrainingWeek],
                              settings: UserSettings) {
        guard !weeks.isEmpty else { return }

        let total      = weeks.count
        let taperCount = max(1, settings.planType.canonicalTaperWeeks - 1)
        let taperStart = total - taperCount   // first taper week (1-based)

        // Pass 1: Race and taper — structurally certain
        for i in weeks.indices {
            let wn = weeks[i].weekNumber
            if wn == total {
                weeks[i] = weeks[i].settingPhase(.race)
            } else if wn >= taperStart {
                weeks[i] = weeks[i].settingPhase(.taper)
            }
        }

        // Pass 2: Peak — data-derived from actual generated mileage
        if let peakIdx = peakWeekIndex(in: weeks,
                                        taperStart: taperStart,
                                        total: total) {
            weeks[peakIdx] = weeks[peakIdx].settingPhase(.peak)
        }

        // Pass 3: Fill remaining with base / build
        let peakWN  = weeks.first(where: { $0.phase == .peak })?.weekNumber
                      ?? taperStart - 1
        let baseEnd = max(1, peakWN / 2)

        for i in weeks.indices {
            guard weeks[i].phase != .race,
                  weeks[i].phase != .taper,
                  weeks[i].phase != .peak else { continue }
            let wn = weeks[i].weekNumber
            weeks[i] = weeks[i].settingPhase(wn <= baseEnd ? .base : .build)
        }
    }

    // MARK: - Peak Detection

    /// Returns the array index of the true peak week.
    /// Considers only pre-taper, pre-race weeks with positive mileage.
    /// Tiebreaker: later week wins.
    static func peakWeekIndex(in weeks: [TrainingWeek],
                               taperStart: Int,
                               total: Int) -> Int? {
        weeks.enumerated()
            .filter { _, w in
                w.weekNumber < taperStart
                    && w.weekNumber < total
                    && w.totalMiles > 0
            }
            .max { a, b in
                if a.element.totalMiles == b.element.totalMiles {
                    return a.offset < b.offset   // later index wins tie
                }
                return a.element.totalMiles < b.element.totalMiles
            }?
            .offset
    }

    // MARK: - SavedPlan Helpers

    static func taperWeeks(for plan: SavedPlan) -> Int {
        guard let planType = PlanType(rawValue: plan.planType) else { return 2 }
        return max(1, planType.canonicalTaperWeeks - 1)
    }

    /// Returns the canonical peak week number for chart annotation.
    /// Prefers the explicitly assigned .peak phase; falls back to mileage scan.
    static func peakWeekNumber(for plan: SavedPlan) -> Int {
        if let w = plan.weeks.first(where: { $0.phase == .peak }) {
            return w.weekNumber
        }
        let total      = plan.weeks.count
        let taper      = taperWeeks(for: plan)
        let taperStart = total - taper
        return plan.weeks
            .filter { $0.weekNumber < taperStart && $0.weekNumber < total }
            .max { a, b in
                a.totalMiles == b.totalMiles
                    ? a.weekNumber < b.weekNumber
                    : a.totalMiles < b.totalMiles
            }?
            .weekNumber ?? max(1, taperStart - 1)
    }
}
