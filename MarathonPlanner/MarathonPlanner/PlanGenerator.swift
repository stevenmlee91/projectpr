import Foundation

// MARK: - Mileage Tier

enum MileageTier: Equatable {
    case low        // < 25 mpw
    case moderate   // 25–39 mpw
    case high       // 40–55 mpw
    case advanced   // 56+ mpw

    var maxQualityFraction: Double {
        switch self {
        case .low:      return 0.15
        case .moderate: return 0.18
        case .high:     return 0.20
        case .advanced: return 0.22
        }
    }

    var qualityIntroWeek: Int {
        switch self {
        case .low:      return 5
        case .moderate: return 4
        case .high:     return 2
        case .advanced: return 1
        }
    }
}

func determineMileageTier(_ base: Double) -> MileageTier {
    if base < 25  { return .low }
    if base < 40  { return .moderate }
    if base < 56  { return .high }
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

        let rawBlueprints     = buildBlueprints(settings: settings, tier: tier, constraints: constraints, peaks: peaks)
        let enforcedBlueprints = rawBlueprints.map { enforceMethodConstraints($0, constraints: constraints, peaks: peaks) }
        let weeks              = enforcedBlueprints.map { assignDays(blueprint: $0, settings: settings, tier: tier) }
        return weeks
    }

    // MARK: - Weekly Mileage Generator
    // Builds backward from peak to guarantee every user
    // reaches the correct peak week mileage regardless of base.

    static func generateWeeklyMileage(
        baseMileage  : Double,
        peakMileage  : Double,
        weeks        : Int,
        peakWeek     : Int,
        taperWeeks   : Int,
        cutbackEvery : Int,
        cutbackFactor: Double,
        constraints  : MethodConstraints
    ) -> [Double] {

        let taperStart = peakWeek + 1
        let minWeekly  = constraints.absoluteMinWeekly
        let maxWeekly  = constraints.absoluteMaxWeekly

        // Count non-cutback build weeks to back-calculate week 1
        var nonCutbackCount = 0
        for w in 1...peakWeek {
            let isCutback = cutbackEvery < 99 && w % cutbackEvery == 0
            if !isCutback { nonCutbackCount += 1 }
        }

        // Back-calculate starting mileage
        let rate           = 0.09
        let exponent       = Double(nonCutbackCount)
        let backCalculated = peakMileage / pow(1.0 + rate, exponent)
        let floorMiles     = peakMileage * 0.65
        let rawWeek1       = max(backCalculated, min(baseMileage, floorMiles))
        let week1Miles     = min(max(rawWeek1, minWeekly), maxWeekly)

        var schedule : [Double] = []
        var current  = week1Miles

        for week in 1...weeks {
            let isTaper   = week >= taperStart
            let isCutback = !isTaper && cutbackEvery < 99 && week % cutbackEvery == 0

            if isTaper {
                let weeksIn = week - taperStart
                let factor: Double
                if weeksIn == 0      { factor = 0.82 }
                else if weeksIn == 1 { factor = 0.65 }
                else                 { factor = 0.45 }
                let tapered = peakMileage * factor
                let lo      = minWeekly * 0.4
                let clamped = min(max(tapered, lo), maxWeekly)
                schedule.append(clamped.rounded(toPlaces: 0))

            } else if week == peakWeek {
                schedule.append(peakMileage.rounded(toPlaces: 0))

            } else if isCutback {
                let cutback = (current * cutbackFactor).rounded(toPlaces: 0)
                let clamped = min(max(cutback, minWeekly), peakMileage)
                schedule.append(clamped)

            } else {
                let progress    = Double(week - 1) / Double(peakWeek - 1)
                let curved      = week1Miles + (peakMileage - week1Miles) * progress
                let tenPct      = current * 1.10
                let safeMiles   = min(curved, tenPct)
                let clamped     = min(max(safeMiles, minWeekly), maxWeekly)
                schedule.append(clamped.rounded(toPlaces: 0))
                current = clamped
            }
        }

        return schedule
    }

    // MARK: - Long Run Generator
    // Always hits method-required peak. Base mileage only
    // controls the starting distance and rate of progression.

    static func generateLongRunDistance(
        week         : Int,
        method       : PlanType,
        baseMileage  : Double,
        peaks        : PeakTargets,
        constraints  : MethodConstraints,
        totalWeeks   : Int,
        weeklyMileage: Double,
        isCutback    : Bool
    ) -> Double {

        let peakLong   = peaks.peakLongRun
        let peakWeek   = peaks.peakWeekNumber
        let taperStart = peakWeek + 1
        let isTaper    = week >= taperStart

        // Start long run at 40% of base or 55% of peak, whichever is smaller
        let rawStart  = min(baseMileage * 0.40, peakLong * 0.55)
        let startLong = min(max(rawStart, constraints.minLongRunMiles), peakLong)

        var longMiles: Double

        if isTaper {
            let drop  = Double(week - taperStart + 1)
            longMiles = peakLong - (drop * 3.0)

        } else if week == peakWeek {
            longMiles = peakLong

        } else if isCutback {
            let progress  = Double(week - 1) / Double(peakWeek - 1)
            let projected = startLong + (peakLong - startLong) * progress
            longMiles = projected - 2.5

        } else {
            let progress = Double(week - 1) / Double(peakWeek - 1)
            longMiles = startLong + (peakLong - startLong) * progress
        }

        // Apply floors and ceilings
        longMiles = min(longMiles, constraints.maxLongRunMiles)
        longMiles = max(longMiles, constraints.minLongRunMiles)

        // Daniels: long run capped at 25% of weekly total
        if method == .jackDaniels {
            let cap   = weeklyMileage * constraints.longRunAsPercentage
            longMiles = min(longMiles, cap)
        }

        return longMiles.rounded(toPlaces: 0)
    }

    // MARK: - Workout Assignment

    static func generateWorkouts(
        for week      : Int,
        method        : PlanType,
        mileageTier   : MileageTier,
        totalWeeks    : Int,
        constraints   : MethodConstraints
    ) -> (primary: WorkoutType, secondary: WorkoutType) {

        let taperCutoff = method == .pfitz ? totalWeeks - 3 : totalWeeks - 2
        let isTaper     = week >= taperCutoff
        let introWeek   = max(mileageTier.qualityIntroWeek, constraints.earliestQualityWeek)
        let tooEarly    = week < introWeek

        if isTaper || tooEarly {
            return (.easy, .easy)
        }

        switch method {
        case .hansons:
            let primary: WorkoutType = week <= 5 ? .speedWork : .strengthMP
            return (primary, .easy)

        case .pfitz:
            return (.lactateThreshold, .easy)

        case .higdon:
            return (.easy, .easy)

        case .higdonIntermediate:
            return (.tempoRun, .easy)

        case .jackDaniels:
            if week <= 4 {
                let q2: WorkoutType = mileageTier == .low ? .easy : .repetitionWork
                return (.repetitionWork, q2)
            } else {
                let q2: WorkoutType = (mileageTier == .low && week < 8) ? .easy : .intervalWork
                return (.cruiseIntervals, q2)
            }
        }
    }

    // MARK: - Enforcement Layer

    static func enforceMethodConstraints(
        _ bp        : WeekBlueprint,
        constraints : MethodConstraints,
        peaks       : PeakTargets
    ) -> WeekBlueprint {
        var b = bp

        // Long run bounds
        b.longMiles = min(b.longMiles, constraints.maxLongRunMiles)
        b.longMiles = max(b.longMiles, constraints.minLongRunMiles)

        // Weekly mileage bounds
        b.totalMiles = max(b.totalMiles, constraints.absoluteMinWeekly)
        b.totalMiles = min(b.totalMiles, constraints.absoluteMaxWeekly)

        // Taper floor
        if b.phase.contains("Taper") {
            let floor = constraints.absoluteMinWeekly * 0.4
            b.totalMiles = max(b.totalMiles, floor)
        }

        // Pfitz medium-long run protection
        let isTaper = b.phase.contains("Taper")
        if constraints.requiresMediumLong && !b.isCutback && !isTaper {
            b.includesMediumLong = true
            if b.mediumLongMiles < 10 {
                b.mediumLongMiles = max(10.0, (b.longMiles * 0.6).rounded(toPlaces: 0))
            }
        }

        // Quality workout protection
        let qualityTypes: Set<WorkoutType> = [
            .speedWork, .strengthMP, .lactateThreshold,
            .cruiseIntervals, .intervalWork, .repetitionWork, .tempoRun
        ]
        if !isTaper && b.weekNumber >= constraints.earliestQualityWeek {
            let planNeedsQuality = constraints.requiredWorkouts.contains { qualityTypes.contains($0) }
            if planNeedsQuality && b.primaryWorkout == .easy {
                let restored = constraints.requiredWorkouts.first { qualityTypes.contains($0) }
                b.primaryWorkout = restored ?? .easy
            }
        }

        return b
    }

    // MARK: - Peak Compliance Validation

    static func validatePeakCompliance(
        plan   : [TrainingWeek],
        method : PlanType,
        peaks  : PeakTargets
    ) -> Bool {
        let longRunTypes: Set<WorkoutType> = [.longRun, .longRunWithMP]
        let allDays  = plan.flatMap { $0.days }
        let longDays = allDays.filter { longRunTypes.contains($0.workoutType) }
        let maxLong  = longDays.map { $0.miles }.max() ?? 0

        guard maxLong >= peaks.peakLongRun - 1 else {
            print("FAIL: Max long run \(maxLong) < required \(peaks.peakLongRun)")
            return false
        }

        let peakPhaseWeeks = plan.filter {
            $0.weekNumber >= peaks.peakWeekNumber - 3 &&
            $0.weekNumber <= peaks.peakWeekNumber
        }
        let peakTypes = Set(peakPhaseWeeks.flatMap { $0.days }.map { $0.workoutType })
        let mc        = getMethodConstraints(for: method)

        for required in mc.requiredWorkouts {
            if required == .rest { continue }
            if !peakTypes.contains(required) {
                print("FAIL: \(required.rawValue) missing from peak phase")
                return false
            }
        }

        print("PASS: Long run \(maxLong) mi achieved")
        return true
    }

    // MARK: - Blueprint Router

    static func buildBlueprints(
        settings    : UserSettings,
        tier        : MileageTier,
        constraints : MethodConstraints,
        peaks       : PeakTargets
    ) -> [WeekBlueprint] {
        switch settings.planType {
        case .hansons:
            return hansonsBlueprints(settings: settings, tier: tier, constraints: constraints, peaks: peaks)
        case .pfitz:
            return pfitzBlueprints(settings: settings, tier: tier, constraints: constraints, peaks: peaks)
        case .higdon:
            return higdonBlueprints(settings: settings, tier: tier, constraints: constraints, peaks: peaks)
        case .higdonIntermediate:
            return higdonIntBlueprints(settings: settings, tier: tier, constraints: constraints, peaks: peaks)
        case .jackDaniels:
            return danielsBlueprints(settings: settings, tier: tier, constraints: constraints, peaks: peaks)
        }
    }

    // MARK: - Hansons

    static func hansonsBlueprints(
        settings    : UserSettings,
        tier        : MileageTier,
        constraints : MethodConstraints,
        peaks       : PeakTargets
    ) -> [WeekBlueprint] {
        let n = settings.planLength.rawValue
        let mileage = generateWeeklyMileage(
            baseMileage:   settings.baseMileage,
            peakMileage:   peaks.peakWeeklyMiles,
            weeks:         n,
            peakWeek:      peaks.peakWeekNumber,
            taperWeeks:    peaks.taperWeeks,
            cutbackEvery:  99,
            cutbackFactor: 1.0,
            constraints:   constraints
        )

        var result: [WeekBlueprint] = []
        for i in 0..<n {
            let week    = i + 1
            let isTaper = week > peaks.peakWeekNumber
            let (primary, secondary) = generateWorkouts(
                for: week, method: .hansons,
                mileageTier: tier, totalWeeks: n, constraints: constraints
            )
            let longMiles = generateLongRunDistance(
                week: week, method: .hansons,
                baseMileage: settings.baseMileage,
                peaks: peaks, constraints: constraints,
                totalWeeks: n, weeklyMileage: mileage[i],
                isCutback: false
            )
            let phase = isTaper ? "Taper" : (week <= 5 ? "Speed Phase" : "Strength Phase")
            let bp = WeekBlueprint(
                weekNumber: week, phase: phase,
                totalMiles: mileage[i], longMiles: longMiles,
                primaryWorkout: primary, secondaryWorkout: secondary,
                isCutback: false, includesMediumLong: false, mediumLongMiles: 0
            )
            result.append(bp)
        }
        return result
    }

    // MARK: - Pfitz

    static func pfitzBlueprints(
        settings    : UserSettings,
        tier        : MileageTier,
        constraints : MethodConstraints,
        peaks       : PeakTargets
    ) -> [WeekBlueprint] {
        let n = settings.planLength.rawValue
        let mileage = generateWeeklyMileage(
            baseMileage:   settings.baseMileage,
            peakMileage:   peaks.peakWeeklyMiles,
            weeks:         n,
            peakWeek:      peaks.peakWeekNumber,
            taperWeeks:    peaks.taperWeeks,
            cutbackEvery:  4,
            cutbackFactor: 0.80,
            constraints:   constraints
        )

        var result: [WeekBlueprint] = []
        for i in 0..<n {
            let week      = i + 1
            let isCutback = week % 4 == 0 && week <= peaks.peakWeekNumber
            let isTaper   = week > peaks.peakWeekNumber
            let (primary, _) = generateWorkouts(
                for: week, method: .pfitz,
                mileageTier: tier, totalWeeks: n, constraints: constraints
            )
            let longMiles = generateLongRunDistance(
                week: week, method: .pfitz,
                baseMileage: settings.baseMileage,
                peaks: peaks, constraints: constraints,
                totalWeeks: n, weeklyMileage: mileage[i],
                isCutback: isCutback
            )

            let phase: String
            if isTaper         { phase = "Taper" }
            else if week <= 5  { phase = "Aerobic Base" }
            else if week <= 11 { phase = "Lactate Threshold" }
            else               { phase = "Race-Specific" }

            let useML   = !isTaper && !isCutback
            let mlMiles = useML ? max(10.0, (longMiles * 0.65).rounded(toPlaces: 0)) : 0.0
            let isLRwithMP = !isTaper && week >= n - 7 && longMiles >= 18
            let longType: WorkoutType = isLRwithMP ? .longRunWithMP : .longRun
            let finalPrimary: WorkoutType = isLRwithMP ? longType : primary

            let bp = WeekBlueprint(
                weekNumber: week, phase: phase,
                totalMiles: mileage[i], longMiles: longMiles,
                primaryWorkout: finalPrimary, secondaryWorkout: .easy,
                isCutback: isCutback, includesMediumLong: useML, mediumLongMiles: mlMiles
            )
            result.append(bp)
        }
        return result
    }

    // MARK: - Higdon Novice

    static func higdonBlueprints(
        settings    : UserSettings,
        tier        : MileageTier,
        constraints : MethodConstraints,
        peaks       : PeakTargets
    ) -> [WeekBlueprint] {
        let n = settings.planLength.rawValue
        let mileage = generateWeeklyMileage(
            baseMileage:   settings.baseMileage,
            peakMileage:   peaks.peakWeeklyMiles,
            weeks:         n,
            peakWeek:      peaks.peakWeekNumber,
            taperWeeks:    peaks.taperWeeks,
            cutbackEvery:  4,
            cutbackFactor: 0.75,
            constraints:   constraints
        )

        var result: [WeekBlueprint] = []
        for i in 0..<n {
            let week      = i + 1
            let isCutback = week % 4 == 0 && week <= peaks.peakWeekNumber
            let isTaper   = week > peaks.peakWeekNumber
            let longMiles = generateLongRunDistance(
                week: week, method: .higdon,
                baseMileage: settings.baseMileage,
                peaks: peaks, constraints: constraints,
                totalWeeks: n, weeklyMileage: mileage[i],
                isCutback: isCutback
            )
            let phase = isTaper ? "Taper" : (isCutback ? "Recovery Week" : "Base Building")
            let bp = WeekBlueprint(
                weekNumber: week, phase: phase,
                totalMiles: mileage[i], longMiles: longMiles,
                primaryWorkout: .easy, secondaryWorkout: .easy,
                isCutback: isCutback, includesMediumLong: false, mediumLongMiles: 0
            )
            result.append(bp)
        }
        return result
    }

    // MARK: - Higdon Intermediate

    static func higdonIntBlueprints(
        settings    : UserSettings,
        tier        : MileageTier,
        constraints : MethodConstraints,
        peaks       : PeakTargets
    ) -> [WeekBlueprint] {
        let n = settings.planLength.rawValue
        let mileage = generateWeeklyMileage(
            baseMileage:   settings.baseMileage,
            peakMileage:   peaks.peakWeeklyMiles,
            weeks:         n,
            peakWeek:      peaks.peakWeekNumber,
            taperWeeks:    peaks.taperWeeks,
            cutbackEvery:  4,
            cutbackFactor: 0.78,
            constraints:   constraints
        )

        var result: [WeekBlueprint] = []
        for i in 0..<n {
            let week      = i + 1
            let isCutback = week % 4 == 0 && week <= peaks.peakWeekNumber
            let isTaper   = week > peaks.peakWeekNumber
            let (primary, _) = generateWorkouts(
                for: week, method: .higdonIntermediate,
                mileageTier: tier, totalWeeks: n, constraints: constraints
            )
            let longMiles = generateLongRunDistance(
                week: week, method: .higdonIntermediate,
                baseMileage: settings.baseMileage,
                peaks: peaks, constraints: constraints,
                totalWeeks: n, weeklyMileage: mileage[i],
                isCutback: isCutback
            )
            let phase = isTaper ? "Taper" : (isCutback ? "Recovery Week" : "Building")
            let bp = WeekBlueprint(
                weekNumber: week, phase: phase,
                totalMiles: mileage[i], longMiles: longMiles,
                primaryWorkout: primary, secondaryWorkout: .easy,
                isCutback: isCutback, includesMediumLong: false, mediumLongMiles: 0
            )
            result.append(bp)
        }
        return result
    }

    // MARK: - Jack Daniels

    static func danielsBlueprints(
        settings    : UserSettings,
        tier        : MileageTier,
        constraints : MethodConstraints,
        peaks       : PeakTargets
    ) -> [WeekBlueprint] {
        let n = settings.planLength.rawValue
        let mileage = generateWeeklyMileage(
            baseMileage:   settings.baseMileage,
            peakMileage:   peaks.peakWeeklyMiles,
            weeks:         n,
            peakWeek:      peaks.peakWeekNumber,
            taperWeeks:    peaks.taperWeeks,
            cutbackEvery:  4,
            cutbackFactor: 0.80,
            constraints:   constraints
        )

        var result: [WeekBlueprint] = []
        for i in 0..<n {
            let week      = i + 1
            let isCutback = week % 4 == 0 && week <= peaks.peakWeekNumber
            let isTaper   = week > peaks.peakWeekNumber
            let (primary, secondary) = generateWorkouts(
                for: week, method: .jackDaniels,
                mileageTier: tier, totalWeeks: n, constraints: constraints
            )
            let longMiles = generateLongRunDistance(
                week: week, method: .jackDaniels,
                baseMileage: settings.baseMileage,
                peaks: peaks, constraints: constraints,
                totalWeeks: n, weeklyMileage: mileage[i],
                isCutback: isCutback
            )

            let phase: String
            if isTaper         { phase = "Phase IV — Taper" }
            else if week <= 4  { phase = "Phase I — Base" }
            else if week <= 11 { phase = "Phase II — Threshold" }
            else               { phase = "Phase III — Race-Specific" }

            let bp = WeekBlueprint(
                weekNumber: week, phase: phase,
                totalMiles: mileage[i], longMiles: longMiles,
                primaryWorkout: primary, secondaryWorkout: secondary,
                isCutback: isCutback, includesMediumLong: false, mediumLongMiles: 0
            )
            result.append(bp)
        }
        return result
    }

    // MARK: - Day Assignment

    static func assignDays(
        blueprint : WeekBlueprint,
        settings  : UserSettings,
        tier      : MileageTier
    ) -> TrainingWeek {
        let paces    = PaceEngine(goalMinutes: settings.goalTimeMinutes)
        var days     : [TrainingDay] = []

        let q1Day    = settings.workoutDay1
        let q2Day    = settings.workoutDay2
        let lrDay    = settings.longRunDay
        let restDays = settings.restDays

        let mlDay: Weekday?
        if blueprint.includesMediumLong {
            mlDay = firstAvailableDay(excluding: [q1Day, q2Day, lrDay] + restDays)
        } else {
            mlDay = nil
        }

        for day in Weekday.allCases {
            let td: TrainingDay
            if restDays.contains(day) {
                td = makeRest(day: day)
            } else if day == lrDay {
                td = makeLongRun(day: day, blueprint: blueprint, paces: paces)
            } else if day == q1Day {
                td = makeQuality(
                    day: day, workoutType: blueprint.primaryWorkout,
                    blueprint: blueprint, paces: paces, tier: tier
                )
            } else if day == q2Day && blueprint.secondaryWorkout != .easy {
                td = makeQuality(
                    day: day, workoutType: blueprint.secondaryWorkout,
                    blueprint: blueprint, paces: paces, tier: tier
                )
            } else if let ml = mlDay, day == ml {
                td = makeMediumLong(day: day, blueprint: blueprint, paces: paces)
            } else {
                td = makeEasyPlaceholder(day: day, paces: paces, settings: settings)
            }
            days.append(td)
        }

        let distributed = distributeMiles(days: days, blueprint: blueprint, tier: tier)
        return TrainingWeek(
            weekNumber: blueprint.weekNumber,
            phase:      blueprint.phase,
            days:       distributed
        )
    }

    // MARK: - Day Makers

    static func makeRest(day: Weekday) -> TrainingDay {
        TrainingDay(
            weekday:     day,
            workoutType: .rest,
            miles:       0,
            description: "Full rest or gentle cross-training (swimming, cycling, yoga).",
            paceNote:    "—"
        )
    }

    static func makeLongRun(
        day       : Weekday,
        blueprint : WeekBlueprint,
        paces     : PaceEngine
    ) -> TrainingDay {
        let miles = blueprint.longMiles

        if blueprint.primaryWorkout == .longRunWithMP {
            let mpMiles   = max(4, Int(miles / 3))
            let easyMiles = Int(miles) - mpMiles
            let desc = "Long run with MP finish. First \(easyMiles) mi easy, final \(mpMiles) mi at marathon pace. Your hardest long run of the cycle."
            let pace = "Easy: \(paces.rangeString(paces.longRun)) → MP: \(paces.singleString(paces.MP))"
            return TrainingDay(weekday: day, workoutType: .longRunWithMP,
                miles: miles, description: desc, paceNote: pace)
        }

        let desc: String
        if blueprint.phase.contains("Taper") {
            desc = "Taper long run. Easy and relaxed — trust your training."
        } else if blueprint.phase == "Speed Phase" {
            desc = "Long run at easy conversational effort. Arrive already tired from the week. That is normal and intentional."
        } else {
            desc = "Long run at fully conversational effort. Speak in full sentences throughout. No pace pressure."
        }
        return TrainingDay(weekday: day, workoutType: .longRun,
            miles: miles, description: desc, paceNote: paces.rangeString(paces.longRun))
    }

    static func makeQuality(
        day         : Weekday,
        workoutType : WorkoutType,
        blueprint   : WeekBlueprint,
        paces       : PaceEngine,
        tier        : MileageTier
    ) -> TrainingDay {
        let maxQ = (blueprint.totalMiles * tier.maxQualityFraction).rounded(toPlaces: 1)

        switch workoutType {

        case .speedWork:
            let reps: Int
            switch tier {
            case .low:      reps = 6
            case .moderate: reps = 8
            default:        reps = 10
            }
            let desc = "1.5 mi easy warm-up. \(reps) × 600m at 10K pace with 90 sec jog rest. 1.5 mi easy cool-down."
            return TrainingDay(weekday: day, workoutType: .speedWork,
                miles: min(maxQ, 9), description: desc,
                paceNote: "Intervals: \(paces.singleString(paces.hansonsSpeed))")

        case .strengthMP:
            let mpMiles: Int
            switch tier {
            case .low:      mpMiles = max(4, min(6,  blueprint.weekNumber - 2))
            case .moderate: mpMiles = max(5, min(8,  blueprint.weekNumber - 2))
            case .high:     mpMiles = max(6, min(9,  blueprint.weekNumber - 2))
            case .advanced: mpMiles = max(7, min(10, blueprint.weekNumber - 2))
            }
            let desc = "1 mi easy warm-up. \(mpMiles) mi at exactly marathon pace. 1 mi easy cool-down. You will arrive tired. That is the point of Hansons."
            return TrainingDay(weekday: day, workoutType: .strengthMP,
                miles: Double(mpMiles + 2), description: desc,
                paceNote: "MP segment: \(paces.rangeString(paces.hansonsStrength))")

        case .lactateThreshold:
            let ltMiles: Int
            switch tier {
            case .low:      ltMiles = max(3, min(5,  blueprint.weekNumber / 2))
            case .moderate: ltMiles = max(4, min(7,  blueprint.weekNumber / 2 + 1))
            case .high:     ltMiles = max(5, min(9,  blueprint.weekNumber / 2 + 2))
            case .advanced: ltMiles = max(6, min(10, blueprint.weekNumber / 2 + 3))
            }
            let desc = "1.5 mi easy warm-up. \(ltMiles) mi continuous at lactate threshold — comfortably hard, 15K to half marathon effort. 1.5 mi cool-down. Faster than marathon pace."
            return TrainingDay(weekday: day, workoutType: .lactateThreshold,
                miles: min(maxQ, Double(ltMiles + 3)), description: desc,
                paceNote: "LT: \(paces.singleString(paces.pfitzLT))")

        case .cruiseIntervals:
            let reps: Int
            switch tier {
            case .low:      reps = 3
            case .moderate: reps = 4
            default:        reps = 5
            }
            let desc = "2 mi easy warm-up. \(reps) × 1 mile at T pace with 60 sec standing rest. 2 mi easy cool-down."
            return TrainingDay(weekday: day, workoutType: .cruiseIntervals,
                miles: min(maxQ, 10), description: desc,
                paceNote: "T pace: \(paces.singleString(paces.dThreshold))")

        case .intervalWork:
            let reps: Int
            switch tier {
            case .low:      reps = 3
            case .moderate: reps = 4
            default:        reps = 5
            }
            let desc = "2 mi easy warm-up. \(reps) × 1000m at interval pace (5K effort) with 90 sec jog rest. 2 mi easy cool-down."
            return TrainingDay(weekday: day, workoutType: .intervalWork,
                miles: min(maxQ, 10), description: desc,
                paceNote: "I pace: \(paces.singleString(paces.dInterval))")

        case .repetitionWork:
            let reps: Int
            switch tier {
            case .low:      reps = 5
            case .moderate: reps = 6
            default:        reps = 8
            }
            let desc = "2 mi easy warm-up. \(reps) × 200m at repetition pace with full recovery between each. 2 mi cool-down."
            return TrainingDay(weekday: day, workoutType: .repetitionWork,
                miles: min(maxQ, 8), description: desc,
                paceNote: "R pace: \(paces.singleString(paces.dRepetition))")

        case .tempoRun:
            let tempoMiles: Int
            switch tier {
            case .low:      tempoMiles = max(2, min(4, blueprint.weekNumber / 4))
            case .moderate: tempoMiles = max(3, min(5, blueprint.weekNumber / 3))
            case .high:     tempoMiles = max(4, min(6, blueprint.weekNumber / 3))
            case .advanced: tempoMiles = max(5, min(7, blueprint.weekNumber / 3))
            }
            let desc = "1.5 mi easy warm-up. \(tempoMiles) mi comfortably hard. 1.5 mi easy cool-down."
            return TrainingDay(weekday: day, workoutType: .tempoRun,
                miles: min(maxQ, Double(tempoMiles + 3)), description: desc,
                paceNote: "Tempo: \(paces.singleString(paces.higdonTempo))")

        default:
            return TrainingDay(weekday: day, workoutType: .easy,
                miles: 6, description: "Easy aerobic run at conversational pace.",
                paceNote: paces.rangeString(paces.easy))
        }
    }

    static func makeMediumLong(
        day       : Weekday,
        blueprint : WeekBlueprint,
        paces     : PaceEngine
    ) -> TrainingDay {
        let desc = "Medium-long run — a Pfitz signature. General aerobic effort. Not a jog, not a hard workout. This is what structurally separates Pfitz from every other plan."
        return TrainingDay(weekday: day, workoutType: .mediumLong,
            miles: blueprint.mediumLongMiles, description: desc,
            paceNote: paces.rangeString(paces.generalAero))
    }

    static func makeEasyPlaceholder(
        day      : Weekday,
        paces    : PaceEngine,
        settings : UserSettings
    ) -> TrainingDay {
        let nextDay      = (settings.longRunDay.rawValue + 1) % 7
        let isAfterLong  = day.rawValue == nextDay

        if isAfterLong {
            return TrainingDay(weekday: day, workoutType: .recovery,
                miles: 0,
                description: "Recovery run. Go slower than feels necessary. This is where adaptation happens.",
                paceNote: paces.singleString(paces.recovery))
        }
        return TrainingDay(weekday: day, workoutType: .easy,
            miles: 0,
            description: "Easy aerobic run. If you cannot speak in full sentences, slow down.",
            paceNote: paces.rangeString(paces.easy))
    }

    // MARK: - Mile Distribution

    static func distributeMiles(
        days      : [TrainingDay],
        blueprint : WeekBlueprint,
        tier      : MileageTier
    ) -> [TrainingDay] {
        let fixedTypes: Set<WorkoutType> = [
            .rest, .longRun, .longRunWithMP, .mediumLong,
            .strengthMP, .lactateThreshold, .cruiseIntervals,
            .intervalWork, .repetitionWork, .speedWork, .tempoRun
        ]

        let fixedMiles = days
            .filter { fixedTypes.contains($0.workoutType) }
            .reduce(0.0) { $0 + $1.miles }

        let remaining = max(0.0, blueprint.totalMiles - fixedMiles)

        let flexIndices = days.indices.filter {
            let wt = days[$0].workoutType
            return !fixedTypes.contains(wt) && wt != .rest
        }

        guard !flexIndices.isEmpty else { return days }

        let minEasy: Double = tier == .low ? 3.0 : 4.0
        let maxEasy: Double = tier == .advanced ? 12.0 : 9.0
        let raw    = remaining / Double(flexIndices.count)
        let perDay = min(maxEasy, max(minEasy, raw)).rounded(toPlaces: 1)

        var result = days
        for i in flexIndices {
            let d = result[i]
            result[i] = TrainingDay(
                weekday:     d.weekday,
                workoutType: d.workoutType,
                miles:       perDay,
                description: d.description,
                paceNote:    d.paceNote
            )
        }
        return result
    }

    // MARK: - Utilities

    static func firstAvailableDay(excluding: [Weekday]) -> Weekday? {
        Weekday.allCases.first { !excluding.contains($0) }
    }
}

// MARK: - Extensions

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let d = pow(10.0, Double(places))
        return (self * d).rounded() / d
    }

    func clamped(to range: ClosedRange<Double>) -> Double {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
