import Foundation

// MARK: - Plan Corrector
//
// Runs immediately after a plan is generated, before it is saved.
// Applies silent physiological fixes so users always receive a
// structurally sound plan. Returns the corrected plan plus a
// human-readable log of every change made (useful for debugging
// and optionally surfacing to the user in a future "What we adjusted" view).

struct PlanCorrector {

    struct Correction {
        let weekNumber  : Int
        let description : String
    }

    // MARK: - Public

    static func autocorrect(
        _ plan    : SavedPlan
    ) -> (plan: SavedPlan, corrections: [Correction]) {

        var result      = plan
        var corrections : [Correction] = []
        let planType    = PlanType(rawValue: plan.planType)

        // Corrections are applied in priority order.
        // Each pass mutates `result` and appends to `corrections`.

        // 1. Methodology-specific hard caps
        if planType == .hansons || planType == .hansonsHalf {
            capHansonsLongRuns(&result, planType: planType, &corrections)
        }

        // 2. Mileage progression — forward pass, week by week.
        //    Run twice to catch cascades (fixing week 4 can expose week 5).
        fixMileageProgression(&result, &corrections)
        fixMileageProgression(&result, &corrections)

        // 3. Long run proportion — after progression is fixed so totals are stable.
        fixLongRunProportion(&result, &corrections)

        // Round all mileage to 1 decimal after corrections to avoid floating-point noise.
        result.weeks = result.weeks.map { week in
            var w = week
            w.days = w.days.map { day in
                day.withMiles((day.miles * 10).rounded() / 10)
            }
            return w
        }

        return (result, corrections)
    }

    // MARK: - 1. Hansons Long Run Cap (≤ 16 miles)

    private static func capHansonsLongRuns(
        _ plan    : inout SavedPlan,
        planType  : PlanType?,
        _ log     : inout [Correction]
    ) {
        let cap: Double = planType == .hansonsHalf ? 14 : 16

        for wi in plan.weeks.indices {
            let week = plan.weeks[wi]
            guard week.phase != .taper && week.phase != .race else { continue }

            for di in week.days.indices {
                let day = week.days[di]
                guard isLongRun(day) && day.miles > cap else { continue }

                let excess    = day.miles - cap
                let oldMiles  = day.miles

                // Cap the long run
                plan.weeks[wi].days[di] = day.withMiles(cap)

                // Redistribute excess to the largest adjustable day in the week
                if excess > 0, let targetIdx = largestAdjustableIndex(
                    in: plan.weeks[wi], excluding: di
                ) {
                    let current  = plan.weeks[wi].days[targetIdx].miles
                    plan.weeks[wi].days[targetIdx] =
                        plan.weeks[wi].days[targetIdx].withMiles(
                            current + excess
                        )
                }

                log.append(Correction(
                    weekNumber:  week.weekNumber,
                    description: String(format:
                        "Long run capped from %.0f to %.0f mi (Hansons methodology limit). " +
                        "Redistributed %.0f mi to easy running.",
                        oldMiles, cap, excess)
                ))
            }
        }
    }

    // MARK: - 2. Mileage Progression (≤ 15% per week)

    private static func fixMileageProgression(
        _ plan : inout SavedPlan,
        _ log  : inout [Correction]
    ) {
        let weeks = plan.weeks.sorted { $0.weekNumber < $1.weekNumber }

        for i in 1..<weeks.count {
            let prevWeek = weeks[i - 1]
            let currWeek = weeks[i]

            guard currWeek.phase != .taper && currWeek.phase != .race else { continue }
            guard prevWeek.totalMiles > 0 && currWeek.totalMiles > 0  else { continue }

            let increase = (currWeek.totalMiles - prevWeek.totalMiles)
                / prevWeek.totalMiles
            guard increase > 0.15 else { continue }

            // Target: no more than 15% above previous week
            let target  = prevWeek.totalMiles * 1.15
            let excess  = currWeek.totalMiles - target
            guard excess > 0.5 else { continue }   // round-off noise — ignore

            // Find the week index in plan.weeks (sorted order may differ from array order)
            guard let currIdx = plan.weeks.firstIndex(
                where: { $0.id == currWeek.id }
            ) else { continue }

            let removed = removeFromEasyRuns(
                &plan.weeks[currIdx], targetReduction: excess
            )

            if removed > 0.1 {
                log.append(Correction(
                    weekNumber:  currWeek.weekNumber,
                    description: String(format:
                        "Reduced week %d by %.1f mi (was +%.0f%% above week %d; " +
                        "target ≤15%%). Easy runs scaled down proportionally.",
                        currWeek.weekNumber, removed,
                        Int(increase * 100), prevWeek.weekNumber)
                ))
            }
        }
    }

    // MARK: - 3. Long Run Proportion (≤ 40% of weekly total)

    private static func fixLongRunProportion(
        _ plan : inout SavedPlan,
        _ log  : inout [Correction]
    ) {
        for wi in plan.weeks.indices {
            let week = plan.weeks[wi]
            guard week.phase != .taper && week.phase != .race else { continue }
            guard week.totalMiles > 0                          else { continue }

            guard let lrIdx = week.days.firstIndex(where: { isLongRun($0) })
            else { continue }

            let lr         = week.days[lrIdx]
            let proportion = lr.miles / week.totalMiles
            guard proportion > 0.40 else { continue }

            // Aim for 38% — a small buffer below the 40% threshold
            let targetTotal = lr.miles / 0.38
            let toAdd       = targetTotal - week.totalMiles
            guard toAdd > 0.5 else { continue }

            // Distribute the extra miles across adjustable days (excluding long run)
            let adjustable = week.days.indices.filter { idx in
                idx != lrIdx && isAdjustable(week.days[idx])
            }
            guard !adjustable.isEmpty else { continue }

            // Cap per-day addition at 3 miles — don't inflate any single easy day excessively
            let perDay   = min(toAdd / Double(adjustable.count), 3.0)
            let actualAdd = perDay * Double(adjustable.count)

            for idx in adjustable {
                let current = plan.weeks[wi].days[idx].miles
                plan.weeks[wi].days[idx] =
                    plan.weeks[wi].days[idx].withMiles(current + perDay)
            }

            let oldPct = Int(proportion * 100)
            let newPct = Int(lr.miles / (week.totalMiles + actualAdd) * 100)
            log.append(Correction(
                weekNumber:  week.weekNumber,
                description: String(format:
                    "Long run was %d%% of weekly total (week %d, %.0f mi week). " +
                    "Added %.1f mi across %d easy day(s) — proportion now ~%d%%.",
                    oldPct, week.weekNumber, week.totalMiles,
                    actualAdd, adjustable.count, newPct)
            ))
        }
    }

    // MARK: - Helpers

    /// Removes `targetReduction` miles from the easiest adjustable days in a week.
    /// Returns the actual amount removed.
    @discardableResult
    private static func removeFromEasyRuns(
        _ week            : inout SavedWeek,
        targetReduction   : Double
    ) -> Double {

        // Sort candidates: remove from lowest-effort runs first
        // (recovery, easy, strides, cross-train before general aerobic)
        let priorityOrder: [String] = [
            "Recovery Run", "Easy Run", "Easy + Strides",
            "Cross-Training", "Shakeout Run",
            "General Aerobic", "Midweek Longer Run", "Medium-Long Run",
            "Steady Run"
        ]

        var candidates: [(index: Int, priority: Int)] = []
        for (idx, day) in week.days.enumerated() {
            guard isAdjustable(day) && day.miles > 0 else { continue }
            let pri = priorityOrder.firstIndex(of: day.workoutType) ?? 99
            candidates.append((idx, pri))
        }
        candidates.sort { $0.priority < $1.priority }

        guard !candidates.isEmpty else { return 0 }

        // Total adjustable miles and minimum floor (50% of original, ≥ 3 mi)
        let totalAdjustable = candidates.reduce(0.0) {
            $0 + week.days[$1.index].miles
        }
        guard totalAdjustable > 0 else { return 0 }

        // Scale factor: how much to keep
        let keepFraction = max(0, (totalAdjustable - targetReduction) / totalAdjustable)

        var removed = 0.0
        for c in candidates {
            let original = week.days[c.index].miles
            let floor    = max(3.0, original * 0.50)
            let scaled   = max(floor, original * keepFraction)
            let cut      = original - scaled
            if cut > 0.1 {
                week.days[c.index] = week.days[c.index].withMiles(scaled)
                removed += cut
            }
        }
        return removed
    }

    /// Index of the largest adjustable day in the week, optionally excluding one index.
    private static func largestAdjustableIndex(
        in week    : SavedWeek,
        excluding  : Int? = nil
    ) -> Int? {
        week.days.indices
            .filter { idx in
                idx != excluding && isAdjustable(week.days[idx])
            }
            .max(by: { week.days[$0].miles < week.days[$1].miles })
    }

    // MARK: - Day Classification

    private static func isLongRun(_ day: SavedDay) -> Bool {
        day.workoutType == "Long Run"
            || day.workoutType == "Long Run w/ MP Finish"
            || day.workoutType == "Long Run w/ HMP Finish"
    }

    /// Days whose mileage can be adjusted without breaking the plan's
    /// physiological structure. Quality workouts and long runs are sacred.
    private static func isAdjustable(_ day: SavedDay) -> Bool {
        guard day.workoutType != "Rest"       else { return false }
        guard day.workoutType != "Race Day 🏁" else { return false }

        // Preserve long runs and all quality workouts
        let protected: Set<String> = [
            "Long Run",
            "Long Run w/ MP Finish",
            "Long Run w/ HMP Finish",
            "Lactate Threshold",
            "Cruise Intervals",
            "Strength (MP)",
            "Speed Work",
            "Interval Work",
            "Repetition Work",
            "Marathon Pace",
            "Tempo Run"
        ]
        return !protected.contains(day.workoutType)
    }
}

// MARK: - SavedDay Mutation Helper

private extension SavedDay {
    /// Returns a copy of this day with updated mileage.
    func withMiles(_ m: Double) -> SavedDay {
        SavedDay(
            id:               id,
            date:             date,
            weekday:          weekday,
            workoutType:      workoutType,
            miles:            m,
            description:      description,
            paceNote:         paceNote,
            completionStatus: completionStatus,
            actualMiles:      actualMiles,
            completionNote:   completionNote
        )
    }
}

