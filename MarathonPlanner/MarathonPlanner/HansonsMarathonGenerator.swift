// HansonsMarathonGenerator.swift
// Mile Zero
//
// Hansons-inspired marathon training generator.
//
// PHASE STRUCTURE:
//   Base → Speed Development → Strength Build → Marathon Focus → Taper
//
// DAY MAPPING:
//   HansonsDayMap is computed ONCE from the user's schedule at plan start.
//   All weeks use the same map. Days never drift. Workout content evolves;
//   day assignments do not.
//
// REST DAY:
//   Treated as non-negotiable. The first check in every day assignment.
//   The safety net enforces this a second time after the full map is built.
//
// LONG RUN CAP:
//   16 miles. Hard limit. Never exceeded regardless of plan length,
//   peak mileage, or goal time. Enforced at both calculation and creation.

import Foundation

// MARK: - Phase System

private enum HansonsPhase {
    /// Easy aerobic foundation. No quality sessions.
    case base
    /// Short fast intervals. Economy, leg turnover, aerobic power.
    case speedDevelopment
    /// Intervals lengthen. Threshold work grows. Fatigue resistance builds.
    case strengthBuild
    /// Peak marathon-specific work. Longest pace intervals. Maximum specificity.
    case marathonFocus
    /// Volume reduction. Intensity maintained. Legs sharpen for race day.
    case taper
}

// MARK: - Day Map
//
// Computed once from UserSchedule at plan generation time.
// Immutable for the life of the plan.

private struct HansonsDayMap {
    /// Days with zero workouts — always enforced.
    let rest:             Set<Weekday>
    /// Long run day — from user's longRunDay selection.
    let longRun:          Weekday
    /// Primary quality session (Speed → Marathon-Specific) — from workoutDay1.
    let primaryQuality:   Weekday
    /// Secondary quality session (Strength → Pace Intervals) — from workoutDay2.
    let secondaryQuality: Weekday
    /// Threshold/Tempo session — resolved from remaining available days.
    let threshold:        Weekday?
    /// Active recovery — day after long run, if it is not a rest day.
    let postLongRun:      Weekday?
}

// MARK: - Generator

enum HansonsMarathonGenerator {

    private static let longRunHardCap: Double = 16.0

    // MARK: - Entry Point

    static func generate(settings: UserSettings) -> [TrainingWeek] {
        let n     = settings.planLength.rawValue
        let paces = PaceEngine(goalMinutes: settings.goalTimeMinutes,
                               distance:    RaceType.marathon.distance)
        let tier  = determineMileageTier(settings.baseMileage)
        let peaks = calculatePeakTargets(
            method:        .hansons,
            planLength:    n,
            taperDuration: settings.taperDuration
        )

        // ── Day map: computed ONCE. Never recomputed per week. ────────────
        let dayMap  = buildDayMap(from: settings.schedule)
        let mileage = buildMileageSchedule(
            baseMileage: settings.baseMileage,
            peakMileage: peaks.peakWeeklyMiles,
            weeks:       n,
            peakWeek:    peaks.peakWeekNumber
        )

        var weeks: [TrainingWeek] = []

        for i in 0..<n {
            let weekNum   = i + 1
            let phase     = computePhase(weekNum:     weekNum,
                                         totalWeeks:  n,
                                         peakWeekNum: peaks.peakWeekNumber)
            let longMiles = cappedLongRun(weekNum:     weekNum,
                                          totalWeeks:  n,
                                          peakWeekNum: peaks.peakWeekNumber)
            let days      = buildWeekDays(
                weekNum:     weekNum,
                totalWeeks:  n,
                phase:       phase,
                weekMiles:   mileage[i],
                longMiles:   longMiles,
                dayMap:      dayMap,
                paces:       paces,
                tier:        tier,
                peakWeekNum: peaks.peakWeekNumber
            )

            weeks.append(TrainingWeek(
                weekNumber: weekNum,
                phase:      phaseLabel(phase),
                days:       days
            ))
        }

        return PlanGenerator.injectRaceDay(
            into:     weeks,
            schedule: settings.schedule.validated(for: .hansons),
            raceType: .marathon
        )
    }

    // MARK: - Day Map Builder
    //
    // All slot assignments happen here, in dependency order:
    //   longRun → primaryQuality → secondaryQuality → postLongRun → threshold
    //
    // Each slot's "blocked" set grows as slots are assigned.
    // A slot is only placed on a day that is not already taken.
    // The user's preference is honored when it does not conflict.

    private static func buildDayMap(from schedule: UserSchedule) -> HansonsDayMap {
        let rest = Set(schedule.restDays)

        // Long run: user's choice, must not be a rest day.
        let longRun = pickDay(preferred:  schedule.longRunDay,
                              blocked:    rest)

        // Primary quality: workoutDay1, must avoid rest and long run.
        let primaryQ = pickDay(preferred: schedule.workoutDay1,
                               blocked:   rest.union([longRun]))

        // Secondary quality: workoutDay2, must avoid rest, long run, primary.
        let secondaryQ = pickDay(preferred: schedule.workoutDay2,
                                 blocked:   rest.union([longRun, primaryQ]))

        // Post-long-run recovery: day after long run, only if not a rest day.
        let nextDay    = longRun.next
        let postLongRun: Weekday? = rest.contains(nextDay) ? nil : nextDay

        // Threshold: a free day, preferring one between primary and secondary.
        let threshBlocked = rest
            .union([longRun, primaryQ, secondaryQ])
            .union(postLongRun.map { [$0] } ?? [])
        let threshold = pickThresholdDay(primary:   primaryQ,
                                         secondary: secondaryQ,
                                         blocked:   threshBlocked)

        return HansonsDayMap(
            rest:             rest,
            longRun:          longRun,
            primaryQuality:   primaryQ,
            secondaryQuality: secondaryQ,
            threshold:        threshold,
            postLongRun:      postLongRun
        )
    }

    /// Returns `preferred` if it is not blocked.
    /// Falls back to the first unblocked weekday.
    private static func pickDay(preferred: Weekday, blocked: Set<Weekday>) -> Weekday {
        if !blocked.contains(preferred) { return preferred }
        return Weekday.allCases.first { !blocked.contains($0) } ?? preferred
    }

    /// Prefers a day sandwiched between `primary` and `secondary`.
    /// Falls back to any unblocked weekday.
    private static func pickThresholdDay(
        primary:   Weekday,
        secondary: Weekday,
        blocked:   Set<Weekday>
    ) -> Weekday? {
        let all = Weekday.allCases
        guard let pIdx = all.firstIndex(of: primary),
              let sIdx = all.firstIndex(of: secondary) else {
            return all.first { !blocked.contains($0) }
        }

        let lo = min(pIdx, sIdx)
        let hi = max(pIdx, sIdx)

        // Prefer a day between the two quality sessions.
        for i in (lo + 1)..<hi {
            if !blocked.contains(all[i]) { return all[i] }
        }

        // Any remaining free day.
        return all.first { !blocked.contains($0) }
    }

    // MARK: - Phase System
    //
    // Four quality phases, proportional to plan length.
    // Phase boundaries scale with peakWeekNum so a 12-week plan
    // and an 18-week plan both feel correctly paced.
    //
    // For an 18-week plan (peakWeek = 16, qualityWeeks = 14):
    //   Base:             weeks 1–2
    //   Speed Dev:        weeks 3–6   (~28% of quality block)
    //   Strength Build:   weeks 7–10  (~29% of quality block)
    //   Marathon Focus:   weeks 11–16 (~43% of quality block)
    //   Taper:            weeks 17–18

    private static func computePhase(
        weekNum:     Int,
        totalWeeks:  Int,
        peakWeekNum: Int
    ) -> HansonsPhase {
        guard peakWeekNum > 2 else { return weekNum > peakWeekNum ? .taper : .base }

        if weekNum > peakWeekNum { return .taper }
        if weekNum <= 2          { return .base }

        let qualityWeeks = peakWeekNum - 2
        let qualityWeek  = weekNum - 2   // 1-indexed within the quality block

        let speedEnd    = max(4, Int((Double(qualityWeeks) * 0.28).rounded()))
        let strengthEnd = max(speedEnd + 3, Int((Double(qualityWeeks) * 0.57).rounded()))

        if qualityWeek <= speedEnd    { return .speedDevelopment }
        if qualityWeek <= strengthEnd { return .strengthBuild }
        return .marathonFocus
    }

    private static func phaseLabel(_ phase: HansonsPhase) -> String {
        switch phase {
        case .base:             return "Base Building"
        case .speedDevelopment: return "Speed Development"
        case .strengthBuild:    return "Strength Build"
        case .marathonFocus:    return "Marathon Focus"
        case .taper:            return "Taper"
        }
    }

    // MARK: - Mileage Progression
    //
    // Hansons: flat ramp, consistent weekly volume.
    // No cutback weeks. Cumulative load is maintained deliberately.
    // Taper is 2 weeks: ~80% then ~50% of peak.

    private static func buildMileageSchedule(
        baseMileage: Double,
        peakMileage: Double,
        weeks:       Int,
        peakWeek:    Int
    ) -> [Double] {
        guard weeks > 0, peakWeek > 0, peakWeek <= weeks else {
            return Array(repeating: baseMileage, count: max(weeks, 1))
        }

        let startMiles = (peakMileage * 0.62).rounded(toPlaces: 0)
        var schedule: [Double] = []

        for week in 1...weeks {
            let miles: Double

            if week > peakWeek {
                // 2-week moderate taper.
                let factor: Double = (week == peakWeek + 1) ? 0.80 : 0.50
                miles = (peakMileage * factor).rounded(toPlaces: 0)

            } else if week == peakWeek {
                miles = peakMileage.rounded(toPlaces: 0)

            } else {
                let fraction = Double(week - 1) / Double(max(peakWeek - 1, 1))
                miles = (startMiles + fraction * (peakMileage - startMiles))
                    .rounded(toPlaces: 0)
            }

            schedule.append(max(miles, 20.0))
        }

        return schedule
    }

    // MARK: - Long Run (Hard Capped at 16 miles)

    private static func cappedLongRun(
        weekNum:     Int,
        totalWeeks:  Int,
        peakWeekNum: Int
    ) -> Double {
        let phase = computePhase(weekNum:     weekNum,
                                 totalWeeks:  totalWeeks,
                                 peakWeekNum: peakWeekNum)
        let raw: Double

        switch phase {
        case .base:
            // 8 miles week 1, 9 miles week 2.
            raw = 7.0 + Double(weekNum)

        case .speedDevelopment:
            // Builds from 10 to roughly 13 across the speed block.
            let qualityWeek = weekNum - 2
            raw = 10.0 + Double(qualityWeek - 1) * 0.60

        case .strengthBuild, .marathonFocus:
            // Ramps toward the cap and holds it.
            let qualityWeek  = weekNum - 2
            let qualityWeeks = peakWeekNum - 2
            let fraction     = Double(qualityWeek) / Double(max(qualityWeeks, 1))
            raw = 12.0 + fraction * 4.5

        case .taper:
            raw = totalWeeks - weekNum == 0 ? 8.0 : 12.0
        }

        // Hard cap enforced unconditionally.
        return min(raw, longRunHardCap).rounded(toPlaces: 0)
    }

    // MARK: - Week Builder

    private static func buildWeekDays(
        weekNum:     Int,
        totalWeeks:  Int,
        phase:       HansonsPhase,
        weekMiles:   Double,
        longMiles:   Double,
        dayMap:      HansonsDayMap,
        paces:       PaceEngine,
        tier:        MileageTier,
        peakWeekNum: Int
    ) -> [TrainingDay] {

        // Compute quality workout content for this week and phase.
        // Returns nil for days that should be easy during this phase.
        let primaryContent   = primaryQualityContent(phase: phase, weekNum: weekNum,
                                                      peakWeekNum: peakWeekNum, tier: tier)
        let thresholdContent = thresholdContent(phase: phase, weekNum: weekNum,
                                                 peakWeekNum: peakWeekNum)
        let strengthContent  = strengthContent(phase: phase, weekNum: weekNum,
                                               peakWeekNum: peakWeekNum, tier: tier)

        // Build all 7 days.
        // REST CHECK IS ALWAYS FIRST — it cannot be bypassed by any other condition.
        var days: [TrainingDay] = Weekday.allCases.map { day in

            // 1. REST: first, always wins. ─────────────────────────────────
            if dayMap.rest.contains(day) {
                return makeRest(day)
            }

            // 2. LONG RUN ──────────────────────────────────────────────────
            if day == dayMap.longRun {
                return makeLongRun(day, miles: longMiles, phase: phase, paces: paces)
            }

            // 3. PRIMARY QUALITY (Speed → Marathon-Specific) ───────────────
            if day == dayMap.primaryQuality, let c = primaryContent {
                return makePrimaryQualityDay(day, content: c, paces: paces)
            }

            // 4. THRESHOLD RUN ─────────────────────────────────────────────
            if let td = dayMap.threshold, day == td, let c = thresholdContent {
                return makeThresholdDay(day, content: c)
            }

            // 5. SECONDARY QUALITY (Strength → Pace Intervals) ────────────
            if day == dayMap.secondaryQuality, let c = strengthContent {
                return makeStrengthDay(day, content: c, paces: paces)
            }

            // 6. POST LONG-RUN RECOVERY ───────────────────────────────────
            if let rec = dayMap.postLongRun, day == rec {
                return makeRecovery(day, paces: paces)
            }

            // 7. EASY AEROBIC ─────────────────────────────────────────────
            return makeEasy(day, paces: paces)
        }

        // Safety net: replace any workout that somehow landed on a rest day.
        days = enforceRestDays(days, blocked: dayMap.rest)

        // Distribute remaining weekly mileage across easy/recovery days.
        days = distributeMiles(days, weeklyTarget: weekMiles, tier: tier)

        return days
    }

    // MARK: - Quality Workout Content
    //
    // Content structs carry the workout parameters. Day assignment is separate.
    // This decoupling is what makes day mapping deterministic.

    // ── Primary Quality: Speed → Marathon-Specific ─────────────────────────
    //
    //  Speed Development:  Short track intervals (400m–800m). Economy, turnover.
    //  Strength Build:     Longer track intervals (800m–1200m). Aerobic power grows.
    //  Marathon Focus:     Moderate intervals (800m). Sharpness without overload.
    //  Taper:              Light tune-up (4 × 600m). Legs stay awake.

    private struct PrimaryContent {
        let reps: Int; let repDist: String; let totalMiles: Double; let description: String
    }

    private static func primaryQualityContent(
        phase:       HansonsPhase,
        weekNum:     Int,
        peakWeekNum: Int,
        tier:        MileageTier
    ) -> PrimaryContent? {

        switch phase {

        case .base:
            return nil

        case .speedDevelopment:
            let qualityWeek = weekNum - 2
            let (reps, dist): (Int, String)
            switch qualityWeek {
            case 1...2: reps = tier == .low ? 6 : 8;  dist = "400m"
            case 3...4: reps = tier == .low ? 8 : 10; dist = "600m"
            default:    reps = tier == .low ? 6 : 8;  dist = "800m"
            }
            let miles: Double = tier == .low ? 6.0 : tier == .moderate ? 7.0 : 8.0
            return PrimaryContent(
                reps: reps, repDist: dist, totalMiles: miles,
                description: "Speed Session. " +
                    "1.5 mi easy warm-up. " +
                    "\(reps) × \(dist) at 5K–10K race effort with " +
                    "equal-distance jog recovery between each rep. " +
                    "1.5 mi easy cool-down. " +
                    "The focus is leg turnover and running economy. " +
                    "Short and sharp — controlled aggression, not all-out effort."
            )

        case .strengthBuild:
            let qualityWeeks = peakWeekNum - 2
            let speedEnd     = max(4, Int((Double(qualityWeeks) * 0.28).rounded()))
            let transWeek    = weekNum - 2 - speedEnd
            let (reps, dist): (Int, String)
            switch transWeek {
            case 1...2: reps = tier == .low ? 5 : 6; dist = "800m"
            case 3...4: reps = tier == .low ? 4 : 5; dist = "1000m"
            default:    reps = tier == .low ? 4 : 5; dist = "1200m"
            }
            let miles: Double = tier == .low ? 7.0 : tier == .moderate ? 8.5 : 9.0
            return PrimaryContent(
                reps: reps, repDist: dist, totalMiles: miles,
                description: "Speed Session. " +
                    "1.5 mi easy warm-up. " +
                    "\(reps) × \(dist) at 5K–10K race effort with " +
                    "equal-distance jog recovery. " +
                    "1.5 mi easy cool-down. " +
                    "Intervals are longer now — still sharp, but the aerobic demand is growing. " +
                    "Stay controlled on the first two reps and let the effort build naturally."
            )

        case .marathonFocus:
            let reps  = tier == .low ? 4 : 6
            let miles: Double = tier == .low ? 6.5 : tier == .moderate ? 7.5 : 8.5
            return PrimaryContent(
                reps: reps, repDist: "800m", totalMiles: miles,
                description: "Speed Session. " +
                    "1.5 mi easy warm-up. " +
                    "\(reps) × 800m at 5K–10K race effort with 400m jog recovery. " +
                    "1.5 mi easy cool-down. " +
                    "Speed work at this stage maintains running economy without adding " +
                    "excessive fatigue alongside the heavier marathon-pace sessions. " +
                    "Quality over volume."
            )

        case .taper:
            return PrimaryContent(
                reps: 4, repDist: "600m", totalMiles: 5.5,
                description: "Speed Tune-Up. " +
                    "1.5 mi easy warm-up. " +
                    "4 × 600m at 5K effort with 400m jog recovery. " +
                    "1.5 mi easy cool-down. " +
                    "Light speed session to keep the legs sharp during taper. " +
                    "The fitness is fully built — this is maintenance, not development."
            )
        }
    }

    // ── Threshold Run: grows steadily through the plan ────────────────────
    //
    //  Speed Development:  4–5 mi. Introduces sustained threshold effort.
    //  Strength Build:     5–7 mi. Metabolic development grows.
    //  Marathon Focus:     7–8 mi. Peak lactate threshold demand.
    //  Taper:              4 mi. Sharpness preserved, volume reduced.

    private struct ThresholdRunContent {
        let threshMiles: Double; let totalMiles: Double; let description: String
    }

    private static func thresholdContent(
        phase:       HansonsPhase,
        weekNum:     Int,
        peakWeekNum: Int
    ) -> ThresholdRunContent? {

        switch phase {

        case .base:
            return nil

        case .speedDevelopment:
            let qualityWeek = weekNum - 2
            let tMiles = (3.5 + Double(qualityWeek) * 0.30).clamped(to: 3.5...5.0)
            return ThresholdRunContent(
                threshMiles: tMiles, totalMiles: tMiles + 3.0,
                description: "Threshold Run. " +
                    "1.5 mi easy warm-up. " +
                    "\(tMiles.cleanString) mi at a sustained, comfortably hard effort — " +
                    "the pace you could maintain for roughly 60 minutes in a race. " +
                    "1.5 mi easy cool-down. " +
                    "This introduces sustained threshold work alongside the speed sessions. " +
                    "The effort should feel controlled — hard but not desperate."
            )

        case .strengthBuild:
            let qualityWeeks = peakWeekNum - 2
            let speedEnd     = max(4, Int((Double(qualityWeeks) * 0.28).rounded()))
            let transWeek    = weekNum - 2 - speedEnd
            let tMiles = (5.0 + Double(transWeek) * 0.40).clamped(to: 5.0...7.0)
            return ThresholdRunContent(
                threshMiles: tMiles, totalMiles: tMiles + 3.0,
                description: "Threshold Run. " +
                    "1.5 mi easy warm-up. " +
                    "\(tMiles.cleanString) mi at sustained threshold effort. " +
                    "1.5 mi easy cool-down. " +
                    "Threshold sessions are getting longer. The goal is to hold " +
                    "a comfortably hard, controlled pace without the effort becoming " +
                    "a race effort. This builds metabolic efficiency and fatigue resistance."
            )

        case .marathonFocus:
            let qualityWeeks = peakWeekNum - 2
            let strengthEnd  = max(6, Int((Double(qualityWeeks) * 0.57).rounded()))
            let focusWeek    = weekNum - 2 - strengthEnd
            let tMiles = (6.5 + Double(focusWeek) * 0.25).clamped(to: 6.5...8.5)
            return ThresholdRunContent(
                threshMiles: tMiles, totalMiles: tMiles + 3.0,
                description: "Threshold Run. " +
                    "1.5 mi easy warm-up. " +
                    "\(tMiles.cleanString) mi at threshold effort. " +
                    "1.5 mi easy cool-down. " +
                    "Peak threshold demand of the training block. " +
                    "You are running on substantial accumulated fatigue — " +
                    "that is by design. Comfortably hard, not racing. Maintain form throughout."
            )

        case .taper:
            return ThresholdRunContent(
                threshMiles: 4.0, totalMiles: 7.0,
                description: "Threshold Run. " +
                    "1.5 mi easy warm-up. " +
                    "4 mi at threshold effort. " +
                    "1.5 mi easy cool-down. " +
                    "Reduced threshold session during taper. " +
                    "Preserves aerobic sharpness without adding meaningful fatigue."
            )
        }
    }

    // ── Strength / Pace Intervals: the marathon-specific cornerstone ───────
    //
    //  Speed Development:  2 × 2 mi. Introduces marathon-pace concept early.
    //  Strength Build:     2–3 × 2–4 mi. Intervals lengthen progressively.
    //  Marathon Focus:     2 × 4–5 mi. Peak specificity. Maximum fatigue demand.
    //  Taper:              2 × 2 mi. Pace feel confirmed, volume pulled back.

    private struct StrengthRunContent {
        let reps: Int; let repMiles: Double; let totalMiles: Double; let description: String
    }

    private static func strengthContent(
        phase:       HansonsPhase,
        weekNum:     Int,
        peakWeekNum: Int,
        tier:        MileageTier
    ) -> StrengthRunContent? {

        switch phase {

        case .base:
            return nil

        case .speedDevelopment:
            return StrengthRunContent(
                reps: 2, repMiles: 2.0, totalMiles: 8.0,
                description: "Pace Interval Session. " +
                    "2 mi easy warm-up. " +
                    "2 × 2 mi at marathon goal pace minus 10 seconds per mile, " +
                    "with 1 mi easy jog recovery between reps. " +
                    "2 mi easy cool-down. " +
                    "An early introduction to running at marathon-specific pace. " +
                    "These reps should feel controlled — you will be running longer " +
                    "versions of this session in the weeks ahead."
            )

        case .strengthBuild:
            let qualityWeeks = peakWeekNum - 2
            let speedEnd     = max(4, Int((Double(qualityWeeks) * 0.28).rounded()))
            let transWeek    = weekNum - 2 - speedEnd
            let (reps, repMiles): (Int, Double)
            switch transWeek {
            case 1...2: reps = 2; repMiles = 3.0
            case 3...4: reps = 3; repMiles = 2.0
            default:    reps = 2; repMiles = 4.0
            }
            return StrengthRunContent(
                reps: reps, repMiles: repMiles,
                totalMiles: Double(reps) * repMiles + 4.0,
                description: "Pace Interval Session. " +
                    "2 mi easy warm-up. " +
                    "\(reps) × \(repMiles.cleanString) mi at marathon goal pace " +
                    "minus 10 seconds per mile, with 1 mi jog recovery between reps. " +
                    "2 mi easy cool-down. " +
                    "Running near race pace on accumulated weekly fatigue — by design. " +
                    "This builds the physical and mental resilience to hold pace " +
                    "through the final miles of a marathon."
            )

        case .marathonFocus:
            let qualityWeeks = peakWeekNum - 2
            let strengthEnd  = max(6, Int((Double(qualityWeeks) * 0.57).rounded()))
            let focusWeek    = weekNum - 2 - strengthEnd
            let repMiles: Double = focusWeek <= 2 ? 4.0 : 5.0
            return StrengthRunContent(
                reps: 2, repMiles: repMiles,
                totalMiles: 2.0 * repMiles + 4.0,
                description: "Pace Interval Session. " +
                    "2 mi easy warm-up. " +
                    "2 × \(repMiles.cleanString) mi at marathon goal pace minus 10 seconds per mile, " +
                    "with 1 mi jog recovery. " +
                    "2 mi easy cool-down. " +
                    "The longest pace intervals of the training block. " +
                    "Your legs carry the full week's training load into this session — " +
                    "that is the stimulus. Hold the pace and trust the structure."
            )

        case .taper:
            return StrengthRunContent(
                reps: 2, repMiles: 2.0, totalMiles: 8.0,
                description: "Pace Interval Session. " +
                    "2 mi easy warm-up. " +
                    "2 × 2 mi at marathon goal pace minus 10 seconds per mile, " +
                    "with 1 mi jog recovery. " +
                    "2 mi easy cool-down. " +
                    "Reduced pace work during taper. " +
                    "The heavy sessions are complete. This confirms the pace feels natural."
            )
        }
    }

    // MARK: - Day Makers
    //
    // Every maker takes `_ day: Weekday` as its first argument.
    // That parameter is always used for TrainingDay.weekday.
    // No hardcoded weekday values exist anywhere in this file.

    private static func makePrimaryQualityDay(
        _ day: Weekday, content: PrimaryContent, paces: PaceEngine
    ) -> TrainingDay {
        TrainingDay(
            weekday:     day,
            workoutType: .speedWork,
            miles:       content.totalMiles,
            description: content.description,
            paceNote:    "5K–10K race effort: \(paces.singleString(paces.hansonsSpeed))"
        )
    }

    private static func makeThresholdDay(
        _ day: Weekday, content: ThresholdRunContent
    ) -> TrainingDay {
        TrainingDay(
            weekday:     day,
            workoutType: .tempoRun,
            miles:       content.totalMiles,
            description: content.description,
            paceNote:    "Threshold effort — comfortably hard, 10K to half marathon race range"
        )
    }

    private static func makeStrengthDay(
        _ day: Weekday, content: StrengthRunContent, paces: PaceEngine
    ) -> TrainingDay {
        TrainingDay(
            weekday:     day,
            workoutType: .strengthMP,
            miles:       content.totalMiles,
            description: content.description,
            paceNote:    "~10 sec/mi faster than goal MP: \(paces.rangeString(paces.hansonsStrength))"
        )
    }

    private static func makeLongRun(
        _ day: Weekday, miles: Double, phase: HansonsPhase, paces: PaceEngine
    ) -> TrainingDay {
        let safeMiles = min(miles, longRunHardCap)

        let description: String
        switch phase {
        case .base:
            description = "Long Aerobic Run — \(safeMiles.cleanString) mi. " +
                          "Easy and conversational start to finish. " +
                          "Building comfortable aerobic volume."
        case .speedDevelopment:
            description = "Long Aerobic Run — \(safeMiles.cleanString) mi. " +
                          "Easy, conversational pace throughout. " +
                          "This run lands after a week that includes track intervals and threshold work. " +
                          "That accumulated load is part of the training effect — " +
                          "keep the effort genuinely aerobic. Not a progression run."
        case .strengthBuild, .marathonFocus:
            description = "Long Aerobic Run — \(safeMiles.cleanString) mi. " +
                          "Easy, conversational pace throughout. " +
                          "Running long on a week of heavy training load builds the fatigue resistance " +
                          "needed to hold form through miles 18 to 26. " +
                          "Fully aerobic. Finish feeling like you have more."
        case .taper:
            description = "Taper Long Run — \(safeMiles.cleanString) mi. " +
                          "Easy and relaxed. The hard training is complete. " +
                          "This run maintains aerobic rhythm without adding fatigue."
        }

        return TrainingDay(
            weekday:     day,
            workoutType: .longRun,
            miles:       safeMiles,
            description: description,
            paceNote:    "Easy aerobic — 60–90 sec/mi slower than goal marathon pace: " +
                         paces.rangeString(paces.longRun)
        )
    }

    private static func makeRecovery(_ day: Weekday, paces: PaceEngine) -> TrainingDay {
        TrainingDay(
            weekday:     day,
            workoutType: .recovery,
            miles:       0,
            description: "Recovery Run. Very easy movement after yesterday's long effort. " +
                         "The goal is blood flow, not aerobic stimulus. " +
                         "If the pace feels embarrassingly slow, it is probably about right.",
            paceNote:    "Very easy: \(paces.singleString(paces.recovery))"
        )
    }

    private static func makeEasy(_ day: Weekday, paces: PaceEngine) -> TrainingDay {
        TrainingDay(
            weekday:     day,
            workoutType: .easy,
            miles:       0,
            description: "Easy Aerobic Run. Comfortable, conversational effort. " +
                         "These runs support the week's quality sessions without adding intensity stress. " +
                         "If you cannot speak in full sentences, slow down.",
            paceNote:    "Easy aerobic: \(paces.rangeString(paces.easy))"
        )
    }

    private static func makeRest(_ day: Weekday) -> TrainingDay {
        TrainingDay(
            weekday:     day,
            workoutType: .rest,
            miles:       0,
            description: "Rest Day. Full rest is built into the plan structure. " +
                         "Adaptation happens during recovery, not during the run itself.",
            paceNote:    "—"
        )
    }

    // MARK: - Safety Net

    private static func enforceRestDays(
        _ days: [TrainingDay], blocked: Set<Weekday>
    ) -> [TrainingDay] {
        days.map { day in
            guard blocked.contains(day.weekday), day.workoutType != .rest else { return day }
            return makeRest(day.weekday)
        }
    }

    // MARK: - Mileage Distribution

    private static func distributeMiles(
        _ days: [TrainingDay], weeklyTarget: Double, tier: MileageTier
    ) -> [TrainingDay] {
        let fixed: Set<WorkoutType> = [
            .rest, .longRun, .speedWork, .strengthMP, .tempoRun, .raceDay, .shakeout
        ]

        let fixedTotal  = days.filter { fixed.contains($0.workoutType) }
                             .reduce(0.0) { $0 + $1.miles }
        let remaining   = max(0.0, weeklyTarget - fixedTotal)
        let flexIndices = days.indices.filter {
            !fixed.contains(days[$0].workoutType) && days[$0].workoutType != .rest
        }

        guard !flexIndices.isEmpty else { return days }

        let minMiles: Double = tier == .low     ? 3.0 : 4.0
        let maxMiles: Double = tier == .advanced ? 9.0 : 8.0
        let per = min(maxMiles, max(minMiles, remaining / Double(flexIndices.count)))
            .rounded(toPlaces: 1)

        var result = days
        for i in flexIndices {
            let d = result[i]
            result[i] = TrainingDay(
                weekday:     d.weekday,
                workoutType: d.workoutType,
                miles:       per,
                description: d.description,
                paceNote:    d.paceNote
            )
        }
        return result
    }
}

// MARK: - Private Extensions

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
    var cleanString: String {
        truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(self)) : String(format: "%.1f", self)
    }
}
