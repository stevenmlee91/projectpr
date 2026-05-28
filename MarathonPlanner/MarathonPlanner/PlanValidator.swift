import Foundation

// MARK: - Severity

enum ValidationSeverity: Int, Comparable {
    case info    = 0
    case warning = 1
    case error   = 2

    static func < (lhs: ValidationSeverity, rhs: ValidationSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .info:    return "INFO"
        case .warning: return "WARNING"
        case .error:   return "ERROR"
        }
    }

    var icon: String {
        switch self {
        case .info:    return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error:   return "xmark.octagon"
        }
    }
}

// MARK: - Issue

struct ValidationIssue: Identifiable {
    let id         : UUID = UUID()
    let severity   : ValidationSeverity
    let code       : String        // machine-readable, e.g. "PROGRESSION_ERROR"
    let title      : String
    let detail     : String
    let weekNumber : Int?          // nil = plan-level issue
    let dayIndex   : Int?          // nil = week-level or plan-level
}

// MARK: - Report

struct ValidationReport {
    let issues     : [ValidationIssue]
    let checksRun  : Int
    let score      : Int           // 0–100
    let planType   : PlanType?

    var errors   : [ValidationIssue] { issues.filter { $0.severity == .error   } }
    var warnings : [ValidationIssue] { issues.filter { $0.severity == .warning } }
    var infos    : [ValidationIssue] { issues.filter { $0.severity == .info    } }
    var isClean  : Bool             { issues.filter { $0.severity >= .warning  }.isEmpty }

    var scoreLabel: String {
        switch score {
        case 90...100: return "Excellent"
        case 75..<90:  return "Good"
        case 55..<75:  return "Fair"
        default:       return "Needs Review"
        }
    }
}

// MARK: - Validator

struct PlanValidator {

    static func validate(_ plan: SavedPlan) -> ValidationReport {
        var issues    : [ValidationIssue] = []
        var checksRun : Int               = 0

        let planTypeEnum = PlanType(rawValue: plan.planType)

        // Run all check groups
        issues += checkDataIntegrity(plan, &checksRun)
        issues += checkMileageProgression(plan, &checksRun)
        issues += checkLongRunProportion(plan, planTypeEnum, &checksRun)
        issues += checkRecoveryWeeks(plan, &checksRun)
        issues += checkQualityWorkoutSpacing(plan, planTypeEnum, &checksRun)
        issues += checkTaper(plan, planTypeEnum, &checksRun)
        issues += checkRaceWeek(plan, &checksRun)
        issues += checkPhaseSequencing(plan, &checksRun)
        issues += checkMethodologySpecific(plan, planTypeEnum, &checksRun)

        // Compute score
        let errorPenalty   = issues.filter { $0.severity == .error   }.count * 15
        let warningPenalty = issues.filter { $0.severity == .warning }.count * 5
        let score          = max(0, 100 - errorPenalty - warningPenalty)

        let sorted = issues.sorted {
            if $0.severity != $1.severity { return $0.severity > $1.severity }
            return ($0.weekNumber ?? 0) < ($1.weekNumber ?? 0)
        }

        return ValidationReport(
            issues:    sorted,
            checksRun: checksRun,
            score:     score,
            planType:  planTypeEnum
        )
    }

    // MARK: - Data Integrity

    private static func checkDataIntegrity(
        _ plan: SavedPlan,
        _ count: inout Int
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        for week in plan.weeks {
            // 7-day check
            count += 1
            if week.days.count != 7 {
                issues.append(ValidationIssue(
                    severity:   .warning,
                    code:       "DAY_COUNT",
                    title:      "Week \(week.weekNumber) has \(week.days.count) days",
                    detail:     "Training weeks should have exactly 7 days. This may cause mileage calculations to be off.",
                    weekNumber: week.weekNumber,
                    dayIndex:   nil
                ))
            }

            // Rest day mileage check
            count += 1
            let restWithMiles = week.days.filter {
                $0.workoutType == "Rest" && $0.miles > 0
            }
            if !restWithMiles.isEmpty {
                issues.append(ValidationIssue(
                    severity:   .warning,
                    code:       "REST_MILES",
                    title:      "Rest day has mileage in week \(week.weekNumber)",
                    detail:     "Rest days should have 0 miles assigned. Found \(restWithMiles.count) rest day(s) with miles.",
                    weekNumber: week.weekNumber,
                    dayIndex:   nil
                ))
            }

            // Week total consistency
            count += 1
            let sumOfDays = week.days.reduce(0.0) { $0 + $1.miles }
            let deviation = abs(sumOfDays - week.totalMiles)
            if deviation > 0.5 {
                issues.append(ValidationIssue(
                    severity:   .info,
                    code:       "MILEAGE_MISMATCH",
                    title:      "Mileage mismatch in week \(week.weekNumber)",
                    detail:     "Week total (\(String(format: "%.1f", week.totalMiles)) mi) doesn't match day sum (\(String(format: "%.1f", sumOfDays)) mi).",
                    weekNumber: week.weekNumber,
                    dayIndex:   nil
                ))
            }
        }

        return issues
    }

    // MARK: - Mileage Progression

    private static func checkMileageProgression(
        _ plan: SavedPlan,
        _ count: inout Int
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        let weeks = plan.weeks.sorted { $0.weekNumber < $1.weekNumber }

        for i in 1..<weeks.count {
            let prev = weeks[i - 1]
            let curr = weeks[i]

            // Skip taper-phase weeks and any week where mileage drops (those are legitimate cutback weeks)
            guard curr.phase != .taper && curr.phase != .race else { continue }
            guard prev.totalMiles > 0   else { continue }
            guard curr.totalMiles > 0   else { continue }

            count += 1
            let increase = (curr.totalMiles - prev.totalMiles) / prev.totalMiles

            if increase > 0.25 {
                issues.append(ValidationIssue(
                    severity:   .error,
                    code:       "PROGRESSION_ERROR",
                    title:      "Sharp jump into week \(curr.weekNumber)",
                    detail:     String(format: "+%.0f%% increase (%.0f → %.0f mi). The 10% rule keeps tissues safe. A jump this large significantly elevates injury risk.",
                                      increase * 100, prev.totalMiles, curr.totalMiles),
                    weekNumber: curr.weekNumber,
                    dayIndex:   nil
                ))
            } else if increase > 0.15 {
                issues.append(ValidationIssue(
                    severity:   .warning,
                    code:       "PROGRESSION_WARNING",
                    title:      "Aggressive build into week \(curr.weekNumber)",
                    detail:     String(format: "+%.0f%% increase (%.0f → %.0f mi). Most coaches recommend no more than 10–15%% weekly.",
                                      increase * 100, prev.totalMiles, curr.totalMiles),
                    weekNumber: curr.weekNumber,
                    dayIndex:   nil
                ))
            }
        }

        return issues
    }

    // MARK: - Long Run Proportion

    private static func checkLongRunProportion(
        _ plan: SavedPlan,
        _ planType: PlanType?,
        _ count: inout Int
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        for week in plan.weeks {
            guard week.phase != .taper && week.phase != .race else { continue }
            guard week.totalMiles > 0                          else { continue }

            let longRunDay = week.days.first {
                $0.workoutType.contains("Long Run")
            }
            guard let lr = longRunDay, lr.miles > 0 else { continue }

            count += 1
            let proportion = lr.miles / week.totalMiles

            if proportion > 0.50 {
                issues.append(ValidationIssue(
                    severity:   .error,
                    code:       "LONG_RUN_TOO_LARGE",
                    title:      "Long run dominates week \(week.weekNumber)",
                    detail:     String(format: "%.0f mi long run is %.0f%% of the %.0f mi week. Above 50%% means too little easy running to support recovery.",
                                      lr.miles, proportion * 100, week.totalMiles),
                    weekNumber: week.weekNumber,
                    dayIndex:   nil
                ))
            } else if proportion > 0.40 {
                issues.append(ValidationIssue(
                    severity:   .warning,
                    code:       "LONG_RUN_HIGH",
                    title:      "Long run proportion high in week \(week.weekNumber)",
                    detail:     String(format: "%.0f mi long run is %.0f%% of the %.0f mi week. Keeping it under 40%% leaves room for quality and recovery work.",
                                      lr.miles, proportion * 100, week.totalMiles),
                    weekNumber: week.weekNumber,
                    dayIndex:   nil
                ))
            }
        }

        return issues
    }

    // MARK: - Recovery Weeks

    private static func checkRecoveryWeeks(
        _ plan: SavedPlan,
        _ count: inout Int
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        let buildWeeks = plan.weeks
            .filter { $0.phase == .base || $0.phase == .build || $0.phase == .peak }
            .sorted { $0.weekNumber < $1.weekNumber }

        guard buildWeeks.count >= 5 else { return [] }
        count += 1

        // Find the longest run of non-cutback weeks
        // A "cutback" week is one where mileage drops vs the previous week
        var consecutiveBuilding = 0
        var maxConsecutive      = 0

        for i in 1..<buildWeeks.count {
            let prev = buildWeeks[i - 1]
            let curr = buildWeeks[i]
            if curr.totalMiles >= prev.totalMiles {
                consecutiveBuilding += 1
                maxConsecutive = max(maxConsecutive, consecutiveBuilding)
            } else {
                consecutiveBuilding = 0
            }
        }

        if maxConsecutive >= 4 {
            issues.append(ValidationIssue(
                severity:   .warning,
                code:       "MISSING_RECOVERY_WEEK",
                title:      "No cutback week for \(maxConsecutive + 1) weeks",
                detail:     "Most methodologies include a lighter week every 3–4 weeks to let the body absorb the training load. Continuous building without recovery raises injury risk.",
                weekNumber: nil,
                dayIndex:   nil
            ))
        }

        return issues
    }

    // MARK: - Quality Workout Spacing

    private static func checkQualityWorkoutSpacing(
        _ plan: SavedPlan,
        _ planType: PlanType?,
        _ count: inout Int
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // Only check plans that have quality workouts
        guard planType?.requiresTwoWorkoutDays == true else { return [] }

        let hardTypes: Set<String> = [
            "Tempo Run", "Tempo", "Interval", "Intervals", "Speed Work",
            "VO2max", "Lactate Threshold", "Strides",
            "Long Run w/ MP Finish", "Long Run w/ HMP Finish",
            "Tune-up Race", "Time Trial"
        ]

        for week in plan.weeks {
            let days = week.days.sorted { $0.date < $1.date }

            for i in 0..<(days.count - 1) {
                let a = days[i]
                let b = days[i + 1]

                let aHard = hardTypes.contains(where: { a.workoutType.contains($0) })
                let bHard = hardTypes.contains(where: { b.workoutType.contains($0) })

                guard aHard && bHard else { continue }

                // Verify they're actually consecutive days
                let daysBetween = Calendar.current.dateComponents(
                    [.day], from: a.date, to: b.date
                ).day ?? 0
                guard daysBetween == 1 else { continue }

                count += 1
                issues.append(ValidationIssue(
                    severity:   .error,
                    code:       "CONSECUTIVE_QUALITY",
                    title:      "Back-to-back quality workouts in week \(week.weekNumber)",
                    detail:     "\(a.workoutType) followed immediately by \(b.workoutType). Hard workouts on consecutive days prevent full adaptation and raise injury risk. Separate by at least one easy or rest day.",
                    weekNumber: week.weekNumber,
                    dayIndex:   i
                ))
            }
        }

        return issues
    }

    // MARK: - Taper

    private static func checkTaper(
        _ plan: SavedPlan,
        _ planType: PlanType?,
        _ count: inout Int
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        let taperWeeks = plan.weeks
            .filter { $0.phase == .taper || $0.phase == .race }
            .sorted { $0.weekNumber < $1.weekNumber }

        count += 1

        // Validate taper length
        let expectedTaper = planType?.canonicalTaperWeeks ?? 2
        if taperWeeks.count < expectedTaper - 1 {
            issues.append(ValidationIssue(
                severity:   .warning,
                code:       "TAPER_SHORT",
                title:      "Taper may be too short",
                detail:     "\(planType?.rawValue ?? "This methodology") typically uses a \(expectedTaper)-week taper. Found \(taperWeeks.count) taper week(s). A longer taper allows the body to fully absorb peak training.",
                weekNumber: nil,
                dayIndex:   nil
            ))
        }

        // Taper should show decreasing mileage
        count += 1
        for i in 1..<taperWeeks.count {
            let prev = taperWeeks[i - 1]
            let curr = taperWeeks[i]
            if curr.totalMiles > prev.totalMiles + 1 {
                issues.append(ValidationIssue(
                    severity:   .warning,
                    code:       "TAPER_ASCENDING",
                    title:      "Mileage rises in taper (week \(curr.weekNumber))",
                    detail:     String(format: "Taper week \(curr.weekNumber) (%.0f mi) is higher than week \(prev.weekNumber) (%.0f mi). Taper mileage should step down progressively.",
                                      curr.totalMiles, prev.totalMiles),
                    weekNumber: curr.weekNumber,
                    dayIndex:   nil
                ))
            }
        }

        // Race week mileage should be ≤50% of peak
        count += 1
        if let raceWeek = taperWeeks.last {
            let peakMileage = plan.weeks
                .filter { $0.phase != .taper }
                .map { $0.totalMiles }
                .max() ?? 0
            let raceWeekMiles = raceWeek.totalMiles
            if peakMileage > 0 && raceWeekMiles > peakMileage * 0.55 {
                issues.append(ValidationIssue(
                    severity:   .warning,
                    code:       "RACE_WEEK_HIGH",
                    title:      "Race week mileage is high",
                    detail:     String(format: "Week \(raceWeek.weekNumber) has %.0f mi — %.0f%% of your %.0f mi peak. Race week is typically 30–50%% of peak to arrive fresh.",
                                      raceWeekMiles,
                                      (raceWeekMiles / peakMileage) * 100,
                                      peakMileage),
                    weekNumber: raceWeek.weekNumber,
                    dayIndex:   nil
                ))
            }
        }

        return issues
    }

    // MARK: - Race Week

    private static func checkRaceWeek(
        _ plan: SavedPlan,
        _ count: inout Int
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // Find the final week
        guard let lastWeek = plan.weeks.sorted(by: { $0.weekNumber < $1.weekNumber }).last
        else { return [] }

        let hardTypes: Set<String> = [
            "Tempo Run", "Tempo", "Interval", "Intervals",
            "Speed Work", "VO2max", "Lactate Threshold"
        ]

        count += 1

        // Find race day
        let raceDayExists = lastWeek.days.contains {
            $0.workoutType.contains("Race") || $0.workoutType.contains("🏁")
        }
        if !raceDayExists {
            issues.append(ValidationIssue(
                severity:   .info,
                code:       "NO_RACE_DAY",
                title:      "No race day in final week",
                detail:     "Week \(lastWeek.weekNumber) doesn't contain a Race Day entry. This may be intentional if the race was added differently.",
                weekNumber: lastWeek.weekNumber,
                dayIndex:   nil
            ))
        }

        count += 1

        // No hard workouts within 3 days of race
        let days = lastWeek.days.sorted { $0.date < $1.date }
        if let raceDayEntry = days.last(where: {
            $0.workoutType.contains("Race") || $0.workoutType.contains("🏁")
        }) {
            let beforeRace = days.filter { $0.date < raceDayEntry.date }
            let daysBeforeRace = beforeRace.count

            for (idx, day) in beforeRace.enumerated() {
                let daysOut = daysBeforeRace - idx
                guard daysOut <= 3 else { continue }
                let isHard = hardTypes.contains(where: { day.workoutType.contains($0) })
                if isHard {
                    issues.append(ValidationIssue(
                        severity:   .warning,
                        code:       "HARD_WORKOUT_NEAR_RACE",
                        title:      "Hard workout too close to race day",
                        detail:     "\(day.workoutType) is \(daysOut) day\(daysOut == 1 ? "" : "s") before race day. The final 3 days should be easy running only to keep legs fresh.",
                        weekNumber: lastWeek.weekNumber,
                        dayIndex:   idx
                    ))
                }
            }
        }

        return issues
    }

    // MARK: - Phase Sequencing

    private static func checkPhaseSequencing(
        _ plan: SavedPlan,
        _ count: inout Int
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        let weeks = plan.weeks.sorted { $0.weekNumber < $1.weekNumber }

        count += 1

        // Expected phase order
        let phaseOrder: [TrainingPhase] = [.base, .build, .peak, .taper, .race]

        var lastPhaseIndex = -1
        for week in weeks {
            if let idx = phaseOrder.firstIndex(of: week.phase) {
                if idx < lastPhaseIndex {
                    issues.append(ValidationIssue(
                        severity:   .warning,
                        code:       "PHASE_ORDER",
                        title:      "Unexpected phase transition in week \(week.weekNumber)",
                        detail:     "Phase '\(week.phase.displayName)' appears after a later phase. Training phases should progress: Base → Build → Peak → Taper.",
                        weekNumber: week.weekNumber,
                        dayIndex:   nil
                    ))
                    break
                }
                lastPhaseIndex = max(lastPhaseIndex, idx)
            }
        }

        // Taper should be last
        count += 1
        let taperWeeks = weeks.filter { $0.phase == .taper }
        if let lastTaper = taperWeeks.max(by: { $0.weekNumber < $1.weekNumber }) {
            let nonTaperAfter = weeks.filter {
                $0.weekNumber > lastTaper.weekNumber
                    && $0.phase != .taper
                    && $0.phase != .race
            }
            if !nonTaperAfter.isEmpty {
                issues.append(ValidationIssue(
                    severity:   .warning,
                    code:       "NON_TAPER_AFTER_TAPER",
                    title:      "Build weeks after taper starts",
                    detail:     "\(nonTaperAfter.count) non-taper week(s) appear after taper has begun. The taper should run continuously to race day.",
                    weekNumber: nonTaperAfter.first?.weekNumber,
                    dayIndex:   nil
                ))
            }
        }

        return issues
    }

    // MARK: - Methodology Specific

    private static func checkMethodologySpecific(
        _ plan: SavedPlan,
        _ planType: PlanType?,
        _ count: inout Int
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        guard let planType else { return [] }

        switch planType {

        case .hansons, .hansonsHalf:
            // Hansons: no long run > 16 miles
            count += 1
            for week in plan.weeks {
                guard week.phase != .taper && week.phase != .race else { continue }
                for day in week.days where day.workoutType.contains("Long Run") {
                    if day.miles > 16 {
                        issues.append(ValidationIssue(
                            severity:   .error,
                            code:       "HANSONS_LONG_RUN",
                            title:      "Long run exceeds Hansons limit (week \(week.weekNumber))",
                            detail:     String(format: "%.0f mi long run exceeds the Hansons 16-mile cap. The entire Hansons model is built on cumulative fatigue — a longer long run breaks that system and removes the key physiological benefit.",
                                              day.miles),
                            weekNumber: week.weekNumber,
                            dayIndex:   nil
                        ))
                    }
                }
            }

        case .pfitz:
            // Pfitz: expect medium-long runs (≥10 mi) on a mid-week day
            count += 1
            let peakBuildWeeks = plan.weeks.filter {
                $0.phase == .build || $0.phase == .peak
            }
            let weeksMissingMLR = peakBuildWeeks.filter { week in
                let nonSundayNonLongRuns = week.days.filter { day in
                    day.workoutType.contains("Long Run") == false
                        && day.workoutType != "Rest"
                        && day.miles >= 10
                }
                return nonSundayNonLongRuns.isEmpty && week.totalMiles > 30
            }
            if weeksMissingMLR.count > peakBuildWeeks.count / 2 {
                issues.append(ValidationIssue(
                    severity:   .info,
                    code:       "PFITZ_MLR",
                    title:      "Few mid-week long efforts detected",
                    detail:     "Pfitzinger plans are built around medium-long runs (10–16 mi) on weekdays alongside the Sunday long run. These are what make Pfitz hard — and effective.",
                    weekNumber: nil,
                    dayIndex:   nil
                ))
            }

        case .higdon, .higdonIntermediate:
            // Higdon: rest days on at least 2 days/week on average
            count += 1
            let avgRestDays = Double(plan.weeks.flatMap { $0.days }.filter {
                $0.isRestDay
            }.count) / Double(max(plan.weeks.count, 1))

            if avgRestDays < 1.5 {
                issues.append(ValidationIssue(
                    severity:   .warning,
                    code:       "HIGDON_REST_DAYS",
                    title:      "Fewer rest days than Higdon recommends",
                    detail:     String(format: "Higdon plans typically include 2+ rest days per week. This plan averages %.1f rest days — less recovery than the methodology intends.",
                                      avgRestDays),
                    weekNumber: nil,
                    dayIndex:   nil
                ))
            }

        default:
            break
        }

        return issues
    }
}

