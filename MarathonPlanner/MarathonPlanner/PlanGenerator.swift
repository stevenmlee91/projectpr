import Foundation

// MARK: - Mileage Tier

enum MileageTier: Equatable {
    case low, moderate, high, advanced

    var maxQualityFraction: Double {
        switch self {
        case .low: return 0.15; case .moderate: return 0.18
        case .high: return 0.20; case .advanced: return 0.22
        }
    }
    var qualityIntroWeek: Int {
        switch self {
        case .low: return 5; case .moderate: return 4
        case .high: return 2; case .advanced: return 1
        }
    }
}

func determineMileageTier(_ base: Double) -> MileageTier {
    if base < 25 { return .low }
    if base < 40 { return .moderate }
    if base < 56 { return .high }
    return .advanced
}

// MARK: - Week Blueprint

struct WeekBlueprint {
    var weekNumber         : Int
    var phase              : String
    var totalMiles         : Double
    var longMiles          : Double
    var primaryWorkout     : WorkoutType
    var secondaryWorkout   : WorkoutType
    var isCutback          : Bool
    var includesMediumLong : Bool
    var mediumLongMiles    : Double
}

// MARK: - Plan Generator

struct PlanGenerator {

    // MARK: - Entry Point

    static func generate(settings: UserSettings) -> [TrainingWeek] {
        let tier        = determineMileageTier(settings.baseMileage)
        let constraints = getMethodConstraints(for: settings.planType)
        let peaks       = calculatePeakTargets(
            method:     settings.planType,
            planLength: settings.planLength.rawValue
        )
        let schedule = settings.schedule.validated(for: settings.planType)

        let blueprints = buildBlueprints(
            settings:    settings,
            tier:        tier,
            constraints: constraints,
            peaks:       peaks
        )

        // Safety guard: if blueprints are empty something is badly wrong
        guard !blueprints.isEmpty else {
            print("⚠️ PlanGenerator: buildBlueprints returned empty for \(settings.planType)")
            return []
        }

        var weeks = blueprints
            .map { enforceMethodConstraints($0, constraints: constraints) }
            .map { assignDays(
                blueprint:   $0,
                planType:    settings.planType,
                schedule:    schedule,
                goalMinutes: settings.goalTimeMinutes,
                tier:        tier,
                constraints: constraints
            )}

        weeks = injectRaceDay(into: weeks, schedule: schedule)
        return weeks
    }

    // MARK: - Race Day Injection

    static func injectRaceDay(into weeks: [TrainingWeek],
                               schedule: UserSchedule) -> [TrainingWeek] {
        guard !weeks.isEmpty else { return weeks }

        var allWeeks  = weeks
        let lastIndex = allWeeks.count - 1
        var lastWeek  = allWeeks[lastIndex]

        let raceDayWeekday  : Weekday = .sunday
        let shakeoutWeekday : Weekday = .saturday

        let newDays: [TrainingDay] = lastWeek.days.map { day in
            if day.weekday == raceDayWeekday {
                return TrainingDay(
                    weekday:     .sunday,
                    workoutType: .raceDay,
                    miles:       26.2,
                    description: "Race Day. Everything you have trained for comes down to this. Run your own race, trust your pacing, and enjoy every mile.",
                    paceNote:    "Goal marathon pace — trust your training"
                )
            }
            if day.weekday == shakeoutWeekday {
                return TrainingDay(
                    weekday:     .saturday,
                    workoutType: .shakeout,
                    miles:       3.0,
                    description: "Shakeout Run. Easy relaxed 3 miles with a few short strides at the end. Stay loose and fresh — save everything for tomorrow.",
                    paceNote:    "Very easy — fully conversational"
                )
            }
            return day
        }

        lastWeek = TrainingWeek(
            weekNumber: lastWeek.weekNumber,
            phase:      "Race Week 🏁",
            days:       newDays
        )
        allWeeks[lastIndex] = lastWeek
        return allWeeks
    }

    // MARK: - Mileage Schedule

    static func weeklyMileage(
        baseMileage  : Double,
        peakMileage  : Double,
        weeks        : Int,
        peakWeek     : Int,
        cutbackEvery : Int,
        cutbackFactor: Double,
        constraints  : MethodConstraints
    ) -> [Double] {
        // Safety: protect against degenerate inputs
        guard weeks > 0, peakWeek > 0, peakWeek <= weeks else {
            print("⚠️ weeklyMileage: invalid input weeks=\(weeks) peakWeek=\(peakWeek)")
            return Array(repeating: baseMileage, count: max(weeks, 1))
        }

        let taperStart = peakWeek + 1
        let minW = constraints.absoluteMinWeekly
        let maxW = constraints.absoluteMaxWeekly

        var nonCutCount = 0
        for w in 1...peakWeek {
            if !(cutbackEvery < 99 && w % cutbackEvery == 0) { nonCutCount += 1 }
        }

        // Back-calculate week 1 mileage from peak
        let backCalc = nonCutCount > 0
            ? peakMileage / pow(1.09, Double(nonCutCount))
            : peakMileage * 0.6

        // Clamp week1 to sensible range
        let week1 = min(
            max(max(backCalc, min(baseMileage, peakMileage * 0.65)), minW),
            maxW
        )

        // Guard against NaN
        guard week1.isFinite else {
            print("⚠️ weeklyMileage: week1 is not finite, falling back")
            return Array(repeating: baseMileage, count: weeks)
        }

        var result : [Double] = []
        var current = week1

        for week in 1...weeks {
            let isTaper   = week >= taperStart
            let isCutback = !isTaper && cutbackEvery < 99 && week % cutbackEvery == 0

            if isTaper {
                let w = week - taperStart
                let f: Double = w == 0 ? 0.82 : w == 1 ? 0.65 : 0.45
                let val = min(max(peakMileage * f, minW * 0.4), maxW)
                    .rounded(toPlaces: 0)
                result.append(val.isFinite ? val : minW)

            } else if week == peakWeek {
                result.append(peakMileage.rounded(toPlaces: 0))

            } else if isCutback {
                let val = min(
                    max((current * cutbackFactor).rounded(toPlaces: 0), minW),
                    peakMileage
                )
                result.append(val.isFinite ? val : current)

            } else {
                // Linear progression with 10% weekly cap
                let progress = peakWeek > 1
                    ? Double(week - 1) / Double(peakWeek - 1)
                    : 1.0
                let curved = week1 + (peakMileage - week1) * progress
                let capped = min(curved, current * 1.10)
                let val    = min(max(capped, minW), maxW).rounded(toPlaces: 0)
                let safe   = val.isFinite ? val : current
                result.append(safe)
                current = safe
            }
        }

        return result
    }

    // MARK: - Long Run Distance

    static func longRunDistance(
        week         : Int,
        method       : PlanType,
        baseMileage  : Double,
        peaks        : PeakTargets,
        constraints  : MethodConstraints,
        weeklyMileage: Double,
        isCutback    : Bool
    ) -> Double {
        let peak       = peaks.peakLongRun
        let peakWeek   = peaks.peakWeekNumber
        let taperStart = peakWeek + 1
        let isTaper    = week >= taperStart
        let startLong  = min(
            max(min(baseMileage * 0.40, peak * 0.55), constraints.minLongRunMiles),
            peak
        )

        var lm: Double

        if isTaper {
            // Graceful taper: reduce 3 miles per taper week
            let weeksIntoPeak = week - taperStart
            lm = peak - Double(weeksIntoPeak + 1) * 3.0
        } else if week == peakWeek {
            lm = peak
        } else if isCutback {
            let p = peakWeek > 1
                ? Double(week - 1) / Double(peakWeek - 1)
                : 1.0
            lm = startLong + (peak - startLong) * p - 2.5
        } else {
            let p = peakWeek > 1
                ? Double(week - 1) / Double(peakWeek - 1)
                : 1.0
            lm = startLong + (peak - startLong) * p
        }

        // Enforce method constraints
        lm = min(max(lm, constraints.minLongRunMiles), constraints.maxLongRunMiles)

        // Jack Daniels 25% weekly cap
        if method == .jackDaniels && weeklyMileage > 0 {
            lm = min(lm, weeklyMileage * constraints.longRunAsPercentage)
        }

        // Final safety clamp
        lm = max(lm, constraints.minLongRunMiles)

        guard lm.isFinite else {
            print("⚠️ longRunDistance returned non-finite, using minimum")
            return constraints.minLongRunMiles
        }

        return lm.rounded(toPlaces: 0)
    }

    // MARK: - Workout Types
    //
    // BUG 1 ROOT CAUSE (Hansons secondary workout):
    // The old workoutTypes() returned (.easy, .easy) for secondaryWorkout
    // during the Hansons speed phase. This meant assignDays() saw
    // secondaryWorkout == .easy and skipped placing it on q2Day.
    //
    // Fix: Hansons always returns a real secondary workout type.
    // Speed phase Q2 = marathonPace (easy MP run)
    // Strength phase Q2 = marathonPace (longer MP run)

    static func workoutTypes(
        week       : Int,
        method     : PlanType,
        tier       : MileageTier,
        totalWeeks : Int,
        constraints: MethodConstraints
    ) -> (primary: WorkoutType, secondary: WorkoutType) {
        let taperCutoff = method == .pfitz ? totalWeeks - 3 : totalWeeks - 2
        let isTaper     = week >= taperCutoff
        let tooEarly    = week < max(tier.qualityIntroWeek,
                                     constraints.earliestQualityWeek)

        if isTaper || tooEarly { return (.easy, .easy) }

        switch method {

        case .hansons:
            // Speed phase (weeks 1–5): Speed workout + Marathon Pace run
            // Strength phase (week 6+): Strength MP + Marathon Pace run
            // Q2 is always marathonPace so assignDays() places it correctly
            if week <= 5 {
                return (.speedWork, .marathonPace)
            } else {
                return (.strengthMP, .marathonPace)
            }

        case .pfitz:
            // Pfitz: LT primary, medium-long handled separately via blueprint
            return (.lactateThreshold, .easy)

        case .higdon:
            return (.easy, .easy)

        case .higdonIntermediate:
            return (week >= 3 ? .tempoRun : .easy, .easy)

        case .jackDaniels:
            if week <= 4 {
                return (.repetitionWork,
                        tier == .low ? .easy : .repetitionWork)
            } else {
                return (.cruiseIntervals,
                        (tier == .low && week < 8) ? .easy : .intervalWork)
            }
        }
    }

    // MARK: - Method Constraint Enforcement

    static func enforceMethodConstraints(
        _ bp        : WeekBlueprint,
        constraints : MethodConstraints
    ) -> WeekBlueprint {
        var b = bp

        // Clamp long run and total miles to valid ranges
        b.longMiles  = min(max(b.longMiles,  constraints.minLongRunMiles),
                           constraints.maxLongRunMiles)
        b.totalMiles = min(max(b.totalMiles, constraints.absoluteMinWeekly),
                           constraints.absoluteMaxWeekly)

        // Taper weeks can drop below normal minimum
        if b.phase.contains("Taper") {
            b.totalMiles = max(b.totalMiles, constraints.absoluteMinWeekly * 0.4)
        }

        // Pfitz: ensure medium-long run is included in non-taper, non-cutback weeks
        if constraints.requiresMediumLong
            && !b.isCutback
            && !b.phase.contains("Taper") {
            b.includesMediumLong = true
            if b.mediumLongMiles < 10 {
                b.mediumLongMiles = max(
                    10.0,
                    (b.longMiles * 0.6).rounded(toPlaces: 0)
                )
            }
        }

        // Ensure quality workout is assigned if plan requires it
        let qualTypes: Set<WorkoutType> = [
            .speedWork, .strengthMP, .lactateThreshold,
            .cruiseIntervals, .intervalWork, .repetitionWork, .tempoRun
        ]
        if !b.phase.contains("Taper")
            && b.weekNumber >= constraints.earliestQualityWeek
            && b.primaryWorkout == .easy
            && constraints.requiredWorkouts.contains(where: { qualTypes.contains($0) }) {
            b.primaryWorkout = constraints.requiredWorkouts
                .first { qualTypes.contains($0) } ?? .easy
        }

        // Safety: NaN guard
        if !b.totalMiles.isFinite { b.totalMiles = constraints.absoluteMinWeekly }
        if !b.longMiles.isFinite  { b.longMiles  = constraints.minLongRunMiles   }

        return b
    }

    // MARK: - Blueprint Router

    static func buildBlueprints(
        settings    : UserSettings,
        tier        : MileageTier,
        constraints : MethodConstraints,
        peaks       : PeakTargets
    ) -> [WeekBlueprint] {
        switch settings.planType {
        case .hansons:            return hansons(settings, tier, constraints, peaks)
        case .pfitz:              return pfitz(settings, tier, constraints, peaks)
        case .higdon:             return higdon(settings, tier, constraints, peaks)
        case .higdonIntermediate: return higdonInt(settings, tier, constraints, peaks)
        case .jackDaniels:        return daniels(settings, tier, constraints, peaks)
        }
    }

    // MARK: Hansons

    static func hansons(_ s: UserSettings, _ t: MileageTier,
                         _ c: MethodConstraints, _ p: PeakTargets) -> [WeekBlueprint] {
        let n  = s.planLength.rawValue
        let mi = weeklyMileage(baseMileage: s.baseMileage,
                               peakMileage: p.peakWeeklyMiles,
                               weeks: n, peakWeek: p.peakWeekNumber,
                               cutbackEvery: 99, cutbackFactor: 1.0,
                               constraints: c)
        return (0..<n).map { i in
            let wk       = i + 1
            let (pr, sc) = workoutTypes(week: wk, method: .hansons,
                                         tier: t, totalWeeks: n, constraints: c)
            let lm = longRunDistance(week: wk, method: .hansons,
                                     baseMileage: s.baseMileage, peaks: p,
                                     constraints: c, weeklyMileage: mi[i],
                                     isCutback: false)
            let phase: String
            if wk > p.peakWeekNumber { phase = "Taper" }
            else if wk <= 5          { phase = "Speed Phase" }
            else                     { phase = "Strength Phase" }

            return WeekBlueprint(
                weekNumber: wk, phase: phase,
                totalMiles: mi[i], longMiles: lm,
                primaryWorkout: pr, secondaryWorkout: sc,
                isCutback: false, includesMediumLong: false, mediumLongMiles: 0
            )
        }
    }

    // MARK: Pfitz
    //
    // BUG 2 ROOT CAUSE:
    // The Pfitz blueprint was identical to others but
    // enforceMethodConstraints was clamping totalMiles using
    // absoluteMaxWeekly (85) which is correct, but longRunDistance
    // was returning values below minLongRunMiles (12) in early weeks
    // when baseMileage is low, causing a crash or empty return in
    // some edge cases.
    //
    // Fix: longRunDistance now has a hard floor of minLongRunMiles
    // and a NaN guard. Pfitz blueprint also validates mi array length.

    static func pfitz(_ s: UserSettings, _ t: MileageTier,
                       _ c: MethodConstraints, _ p: PeakTargets) -> [WeekBlueprint] {
        let n  = s.planLength.rawValue
        let mi = weeklyMileage(baseMileage: s.baseMileage,
                               peakMileage: p.peakWeeklyMiles,
                               weeks: n, peakWeek: p.peakWeekNumber,
                               cutbackEvery: 4, cutbackFactor: 0.80,
                               constraints: c)

        guard mi.count == n else {
            print("⚠️ Pfitz: mileage array length mismatch \(mi.count) vs \(n)")
            return []
        }

        return (0..<n).map { i in
            let wk    = i + 1
            let isCut = wk % 4 == 0 && wk <= p.peakWeekNumber
            let isTap = wk > p.peakWeekNumber

            let (pr, _) = workoutTypes(week: wk, method: .pfitz,
                                        tier: t, totalWeeks: n, constraints: c)
            let lm = longRunDistance(week: wk, method: .pfitz,
                                     baseMileage: s.baseMileage, peaks: p,
                                     constraints: c, weeklyMileage: mi[i],
                                     isCutback: isCut)

            let phase: String
            if isTap         { phase = "Taper" }
            else if wk <= 5  { phase = "Aerobic Base" }
            else if wk <= 11 { phase = "Lactate Threshold" }
            else             { phase = "Race-Specific" }

            let useML   = !isTap && !isCut
            let mlMiles = useML
                ? max(10.0, (lm * 0.65).rounded(toPlaces: 0))
                : 0.0
            let useLRMP = !isTap && wk >= n - 7 && lm >= 18

            return WeekBlueprint(
                weekNumber: wk, phase: phase,
                totalMiles: mi[i], longMiles: lm,
                primaryWorkout: useLRMP ? .longRunWithMP : pr,
                secondaryWorkout: .easy,
                isCutback: isCut,
                includesMediumLong: useML, mediumLongMiles: mlMiles
            )
        }
    }

    // MARK: Higdon

    static func higdon(_ s: UserSettings, _ t: MileageTier,
                        _ c: MethodConstraints, _ p: PeakTargets) -> [WeekBlueprint] {
        let n  = s.planLength.rawValue
        let mi = weeklyMileage(baseMileage: s.baseMileage,
                               peakMileage: p.peakWeeklyMiles,
                               weeks: n, peakWeek: p.peakWeekNumber,
                               cutbackEvery: 4, cutbackFactor: 0.75,
                               constraints: c)
        return (0..<n).map { i in
            let wk    = i + 1
            let isCut = wk % 4 == 0 && wk <= p.peakWeekNumber
            let isTap = wk > p.peakWeekNumber
            let lm = longRunDistance(week: wk, method: .higdon,
                                     baseMileage: s.baseMileage, peaks: p,
                                     constraints: c, weeklyMileage: mi[i],
                                     isCutback: isCut)
            return WeekBlueprint(
                weekNumber: wk,
                phase: isTap ? "Taper" : (isCut ? "Recovery Week" : "Base Building"),
                totalMiles: mi[i], longMiles: lm,
                primaryWorkout: .easy, secondaryWorkout: .easy,
                isCutback: isCut, includesMediumLong: false, mediumLongMiles: 0
            )
        }
    }

    // MARK: Higdon Intermediate

    static func higdonInt(_ s: UserSettings, _ t: MileageTier,
                           _ c: MethodConstraints, _ p: PeakTargets) -> [WeekBlueprint] {
        let n  = s.planLength.rawValue
        let mi = weeklyMileage(baseMileage: s.baseMileage,
                               peakMileage: p.peakWeeklyMiles,
                               weeks: n, peakWeek: p.peakWeekNumber,
                               cutbackEvery: 4, cutbackFactor: 0.78,
                               constraints: c)
        return (0..<n).map { i in
            let wk    = i + 1
            let isCut = wk % 4 == 0 && wk <= p.peakWeekNumber
            let isTap = wk > p.peakWeekNumber
            let (pr, _) = workoutTypes(week: wk, method: .higdonIntermediate,
                                        tier: t, totalWeeks: n, constraints: c)
            let lm = longRunDistance(week: wk, method: .higdonIntermediate,
                                     baseMileage: s.baseMileage, peaks: p,
                                     constraints: c, weeklyMileage: mi[i],
                                     isCutback: isCut)
            return WeekBlueprint(
                weekNumber: wk,
                phase: isTap ? "Taper" : (isCut ? "Recovery Week" : "Building"),
                totalMiles: mi[i], longMiles: lm,
                primaryWorkout: pr, secondaryWorkout: .easy,
                isCutback: isCut, includesMediumLong: false, mediumLongMiles: 0
            )
        }
    }

    // MARK: Jack Daniels

    static func daniels(_ s: UserSettings, _ t: MileageTier,
                         _ c: MethodConstraints, _ p: PeakTargets) -> [WeekBlueprint] {
        let n  = s.planLength.rawValue
        let mi = weeklyMileage(baseMileage: s.baseMileage,
                               peakMileage: p.peakWeeklyMiles,
                               weeks: n, peakWeek: p.peakWeekNumber,
                               cutbackEvery: 4, cutbackFactor: 0.80,
                               constraints: c)
        return (0..<n).map { i in
            let wk    = i + 1
            let isCut = wk % 4 == 0 && wk <= p.peakWeekNumber
            let isTap = wk > p.peakWeekNumber
            let (pr, sc) = workoutTypes(week: wk, method: .jackDaniels,
                                         tier: t, totalWeeks: n, constraints: c)
            let lm = longRunDistance(week: wk, method: .jackDaniels,
                                     baseMileage: s.baseMileage, peaks: p,
                                     constraints: c, weeklyMileage: mi[i],
                                     isCutback: isCut)
            let phase: String
            if isTap         { phase = "Phase IV — Taper" }
            else if wk <= 4  { phase = "Phase I — Base" }
            else if wk <= 11 { phase = "Phase II — Threshold" }
            else             { phase = "Phase III — Race-Specific" }

            return WeekBlueprint(
                weekNumber: wk, phase: phase,
                totalMiles: mi[i], longMiles: lm,
                primaryWorkout: pr, secondaryWorkout: sc,
                isCutback: isCut, includesMediumLong: false, mediumLongMiles: 0
            )
        }
    }

    // MARK: - Day Assignment
    //
    // BUG 1 FIX (Hansons Q2 not appearing):
    // The old condition was:
    //   planType.requiresTwoWorkoutDays && day == q2Day
    //   && blueprint.secondaryWorkout != .easy
    //
    // Since Hansons secondary was .easy, the condition was always false
    // and Q2 never got placed. Fix: Hansons uses .marathonPace as secondary
    // (set in workoutTypes above), so the != .easy check now passes.
    //
    // The condition is intentionally kept as != .easy so that plans which
    // genuinely have no secondary workout don't place a duplicate easy run.

    static func assignDays(
        blueprint   : WeekBlueprint,
        planType    : PlanType,
        schedule    : UserSchedule,
        goalMinutes : Int,
        tier        : MileageTier,
        constraints : MethodConstraints
    ) -> TrainingWeek {
        let paces  = PaceEngine(goalMinutes: goalMinutes)
        let lrDay  = schedule.longRunDay
        let q1Day  = schedule.workoutDay1
        let q2Day  = schedule.workoutDay2
        let rest   = schedule.restDays
        let ctDay  = schedule.crossTrainDay
        let mwDay  = schedule.midweekLongDay

        // Pfitz medium-long run: first free day not claimed by any role
        let pfitzMLDay: Weekday? = blueprint.includesMediumLong
            ? Weekday.allCases.first {
                !([lrDay, q1Day, q2Day, mwDay] + rest).contains($0)
              }
            : nil

        let mwMiles = max(
            constraints.minLongRunMiles,
            (blueprint.longMiles * 0.55).rounded(toPlaces: 0)
        )

        var days: [TrainingDay] = []

        for day in Weekday.allCases {
            let td: TrainingDay

            if rest.contains(day) {
                td = makeRest(day)

            } else if day == lrDay {
                td = makeLongRun(day, blueprint, paces)

            } else if planType.usesMidweekLongRun && day == mwDay {
                td = makeMidweekLong(day, miles: mwMiles, paces: paces)

            } else if planType.usesCrossTraining, let ct = ctDay, day == ct {
                td = makeCrossTrain(day)

            } else if day == q1Day {
                // Always place Q1 — even if primaryWorkout is .easy
                td = makeQuality(day, workoutType: blueprint.primaryWorkout,
                                 blueprint: blueprint, paces: paces, tier: tier)

            } else if planType.requiresTwoWorkoutDays
                        && day == q2Day
                        && blueprint.secondaryWorkout != .easy {
                // Q2 only placed when secondaryWorkout is a real workout type
                // Hansons now correctly passes .marathonPace so this fires
                td = makeQuality(day, workoutType: blueprint.secondaryWorkout,
                                 blueprint: blueprint, paces: paces, tier: tier)

            } else if let ml = pfitzMLDay, day == ml {
                td = makeMediumLong(day, blueprint, paces)

            } else {
                td = makeEasy(day, paces: paces, longRunDay: lrDay)
            }

            days.append(td)
        }

        return TrainingWeek(
            weekNumber: blueprint.weekNumber,
            phase:      blueprint.phase,
            days:       distributeMiles(days, blueprint, tier)
        )
    }

    // MARK: - Day Makers

    static func makeRest(_ day: Weekday) -> TrainingDay {
        TrainingDay(weekday: day, workoutType: .rest, miles: 0,
            description: "Full rest or gentle cross-training (swimming, cycling, yoga).",
            paceNote: "—")
    }

    static func makeLongRun(_ day: Weekday, _ bp: WeekBlueprint,
                              _ paces: PaceEngine) -> TrainingDay {
        let miles = bp.longMiles
        if bp.primaryWorkout == .longRunWithMP {
            let mp   = max(4, Int(miles / 3))
            let easy = Int(miles) - mp
            return TrainingDay(weekday: day, workoutType: .longRunWithMP,
                miles: miles,
                description: "Long run with MP finish. First \(easy) mi easy, final \(mp) mi at goal marathon pace.",
                paceNote: "Easy: \(paces.rangeString(paces.longRun)) → MP: \(paces.singleString(paces.MP))")
        }
        let desc = bp.phase.contains("Taper")
            ? "Taper long run. Easy and relaxed — trust your training."
            : "Long run at fully conversational effort. Speak in full sentences throughout."
        return TrainingDay(weekday: day, workoutType: .longRun, miles: miles,
            description: desc, paceNote: paces.rangeString(paces.longRun))
    }

    static func makeMidweekLong(_ day: Weekday, miles: Double,
                                  paces: PaceEngine) -> TrainingDay {
        TrainingDay(weekday: day, workoutType: .midweekLong, miles: miles,
            description: "Midweek longer run — longer than easy days, shorter than long run. Easy effort throughout.",
            paceNote: paces.rangeString(paces.easy))
    }

    static func makeCrossTrain(_ day: Weekday) -> TrainingDay {
        TrainingDay(weekday: day, workoutType: .crossTrain, miles: 0,
            description: "Cross-training: 45–60 min low-impact aerobic — cycling, swimming, elliptical, or yoga.",
            paceNote: "Aerobic effort")
    }

    static func makeMediumLong(_ day: Weekday, _ bp: WeekBlueprint,
                                 _ paces: PaceEngine) -> TrainingDay {
        TrainingDay(weekday: day, workoutType: .mediumLong,
            miles: bp.mediumLongMiles,
            description: "Medium-long run — a Pfitz signature. General aerobic effort. Not a jog, not a hard workout.",
            paceNote: paces.rangeString(paces.generalAero))
    }

    static func makeEasy(_ day: Weekday, paces: PaceEngine,
                           longRunDay: Weekday) -> TrainingDay {
        if day == longRunDay.next {
            return TrainingDay(weekday: day, workoutType: .recovery, miles: 0,
                description: "Recovery run. Go slower than feels necessary. Adaptation happens here.",
                paceNote: paces.singleString(paces.recovery))
        }
        return TrainingDay(weekday: day, workoutType: .easy, miles: 0,
            description: "Easy aerobic run. If you cannot speak in full sentences, slow down.",
            paceNote: paces.rangeString(paces.easy))
    }

    static func makeQuality(
        _ day        : Weekday,
        workoutType  : WorkoutType,
        blueprint    : WeekBlueprint,
        paces        : PaceEngine,
        tier         : MileageTier
    ) -> TrainingDay {
        let maxQ = (blueprint.totalMiles * tier.maxQualityFraction)
            .rounded(toPlaces: 1)

        switch workoutType {

        case .speedWork:
            let r = tier == .low ? 6 : tier == .moderate ? 8 : 10
            return TrainingDay(weekday: day, workoutType: .speedWork,
                miles: min(maxQ, 9),
                description: "1.5 mi warm-up. \(r) × 600m at 10K pace with 90 sec jog rest. 1.5 mi cool-down.",
                paceNote: "10K pace: \(paces.singleString(paces.hansonsSpeed))")

        case .strengthMP:
            let mp: Int
            switch tier {
            case .low:      mp = max(4, min(6,  blueprint.weekNumber - 2))
            case .moderate: mp = max(5, min(8,  blueprint.weekNumber - 2))
            case .high:     mp = max(6, min(9,  blueprint.weekNumber - 2))
            case .advanced: mp = max(7, min(10, blueprint.weekNumber - 2))
            }
            return TrainingDay(weekday: day, workoutType: .strengthMP,
                miles: Double(mp + 2),
                description: "1 mi warm-up. \(mp) mi at exactly marathon pace. 1 mi cool-down. Arrive tired — that is the point.",
                paceNote: "MP: \(paces.rangeString(paces.hansonsStrength))")

        // BUG 1 FIX: Added .marathonPace case so Hansons Q2 renders correctly
        case .marathonPace:
            let mpMiles: Int
            switch tier {
            case .low:      mpMiles = max(4, min(6,  blueprint.weekNumber - 1))
            case .moderate: mpMiles = max(5, min(8,  blueprint.weekNumber - 1))
            case .high:     mpMiles = max(6, min(10, blueprint.weekNumber - 1))
            case .advanced: mpMiles = max(7, min(12, blueprint.weekNumber - 1))
            }
            return TrainingDay(weekday: day, workoutType: .marathonPace,
                miles: Double(mpMiles + 4),
                description: "2 mi warm-up. \(mpMiles) mi at goal marathon pace. 2 mi cool-down. Controlled and confident.",
                paceNote: "MP: \(paces.singleString(paces.MP))")

        case .lactateThreshold:
            let lt: Int
            switch tier {
            case .low:      lt = max(3, min(5,  blueprint.weekNumber / 2))
            case .moderate: lt = max(4, min(7,  blueprint.weekNumber / 2 + 1))
            case .high:     lt = max(5, min(9,  blueprint.weekNumber / 2 + 2))
            case .advanced: lt = max(6, min(10, blueprint.weekNumber / 2 + 3))
            }
            return TrainingDay(weekday: day, workoutType: .lactateThreshold,
                miles: min(maxQ, Double(lt + 3)),
                description: "1.5 mi warm-up. \(lt) mi at lactate threshold — comfortably hard, 15K–HM effort. 1.5 mi cool-down.",
                paceNote: "LT: \(paces.singleString(paces.pfitzLT))")

        case .cruiseIntervals:
            let r = tier == .low ? 3 : tier == .moderate ? 4 : 5
            return TrainingDay(weekday: day, workoutType: .cruiseIntervals,
                miles: min(maxQ, 10),
                description: "2 mi warm-up. \(r) × 1 mile at T pace with 60 sec standing rest. 2 mi cool-down.",
                paceNote: "T pace: \(paces.singleString(paces.dThreshold))")

        case .intervalWork:
            let r = tier == .low ? 3 : tier == .moderate ? 4 : 5
            return TrainingDay(weekday: day, workoutType: .intervalWork,
                miles: min(maxQ, 10),
                description: "2 mi warm-up. \(r) × 1000m at interval pace with 90 sec jog rest. 2 mi cool-down.",
                paceNote: "I pace: \(paces.singleString(paces.dInterval))")

        case .repetitionWork:
            let r = tier == .low ? 5 : tier == .moderate ? 6 : 8
            return TrainingDay(weekday: day, workoutType: .repetitionWork,
                miles: min(maxQ, 8),
                description: "2 mi warm-up. \(r) × 200m at R pace with full recovery. 2 mi cool-down.",
                paceNote: "R pace: \(paces.singleString(paces.dRepetition))")

        case .tempoRun:
            let tm: Int
            switch tier {
            case .low:      tm = max(2, min(4, blueprint.weekNumber / 4))
            case .moderate: tm = max(3, min(5, blueprint.weekNumber / 3))
            case .high:     tm = max(4, min(6, blueprint.weekNumber / 3))
            case .advanced: tm = max(5, min(7, blueprint.weekNumber / 3))
            }
            return TrainingDay(weekday: day, workoutType: .tempoRun,
                miles: min(maxQ, Double(tm + 3)),
                description: "1.5 mi warm-up. \(tm) mi comfortably hard. 1.5 mi cool-down.",
                paceNote: "Tempo: \(paces.singleString(paces.higdonTempo))")

        default:
            return TrainingDay(weekday: day, workoutType: .easy, miles: 6,
                description: "Easy aerobic run at conversational pace.",
                paceNote: paces.rangeString(paces.easy))
        }
    }

    // MARK: - Mile Distribution

    static func distributeMiles(
        _ days : [TrainingDay],
        _ bp   : WeekBlueprint,
        _ tier : MileageTier
    ) -> [TrainingDay] {
        let fixed: Set<WorkoutType> = [
            .rest, .longRun, .longRunWithMP, .mediumLong, .midweekLong,
            .crossTrain, .strengthMP, .lactateThreshold, .cruiseIntervals,
            .intervalWork, .repetitionWork, .speedWork, .tempoRun,
            .marathonPace, .raceDay, .shakeout
        ]

        let fixedTotal = days
            .filter { fixed.contains($0.workoutType) }
            .reduce(0.0) { $0 + $1.miles }

        let remaining = max(0.0, bp.totalMiles - fixedTotal)

        let flex = days.indices.filter {
            !fixed.contains(days[$0].workoutType) && days[$0].workoutType != .rest
        }

        guard !flex.isEmpty else { return days }

        let minE: Double = tier == .low     ? 3.0  : 4.0
        let maxE: Double = tier == .advanced ? 12.0 : 9.0
        let per = min(maxE, max(minE, remaining / Double(flex.count)))
            .rounded(toPlaces: 1)

        var result = days
        for i in flex {
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

    static func firstFreeDay(excluding: [Weekday]) -> Weekday? {
        Weekday.allCases.first { !excluding.contains($0) }
    }
}

// MARK: - Double Extension

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let d = pow(10.0, Double(places))
        return (self * d).rounded() / d
    }
}
