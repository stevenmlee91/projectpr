// PfitzMarathonGenerator.swift

import Foundation

enum PfitzMarathonGenerator {

    private enum Phase {
        static let aerobicBase  = "Aerobic Base"
        static let lactate      = "Lactate Threshold"
        static let raceSpecific = "Race-Specific Endurance"
        static let taper        = "Taper"
    }

    private static let basePhaseLength:    Int = 3
    private static let lactatePhaseLength: Int = 5

    static func generate(settings: UserSettings) -> [TrainingWeek] {
        let n        = settings.planLength.rawValue
        let schedule = settings.schedule.validated(for: .pfitz)
        let paces    = PaceEngine(goalMinutes: settings.goalTimeMinutes,
                                  distance:    RaceType.marathon.distance)
        let tier     = determineMileageTier(settings.baseMileage)
        let peaks    = calculatePeakTargets(
            method:        .pfitz,
            planLength:    n,
            taperDuration: settings.taperDuration
        )

        let mileageSchedule = buildMileageSchedule(
            baseMileage: settings.baseMileage,
            peakMileage: peaks.peakWeeklyMiles,
            weeks:       n,
            peakWeek:    peaks.peakWeekNumber
        )

        var weeks: [TrainingWeek] = []

        for i in 0..<n {
            let weekNum   = i + 1
            let weekMiles = mileageSchedule[i]
            let phase     = determinePhase(weekNum: weekNum, totalWeeks: n, peakWeekNum: peaks.peakWeekNumber)
            let isCutback = isCutbackWeek(weekNum: weekNum, phase: phase, peakWeekNum: peaks.peakWeekNumber)
            let days      = buildWeekDays(
                weekNum:     weekNum,
                totalWeeks:  n,
                phase:       phase,
                weekMiles:   weekMiles,
                isCutback:   isCutback,
                schedule:    schedule,
                paces:       paces,
                tier:        tier,
                peakWeekNum: peaks.peakWeekNumber
            )

            weeks.append(TrainingWeek(weekNumber: weekNum, phase: phase, days: days))
        }

        return PlanGenerator.injectRaceDay(into: weeks, schedule: schedule, raceType: .marathon)
    }

    // MARK: - Phase

    private static func determinePhase(weekNum: Int, totalWeeks: Int, peakWeekNum: Int) -> String {
        let taperStart    = totalWeeks - 2
        let lactateStart  = basePhaseLength + 1
        let raceSpecStart = basePhaseLength + lactatePhaseLength + 1

        if weekNum > peakWeekNum || weekNum >= taperStart { return Phase.taper }
        if weekNum >= raceSpecStart                       { return Phase.raceSpecific }
        if weekNum >= lactateStart                        { return Phase.lactate }
        return Phase.aerobicBase
    }

    private static func isCutbackWeek(weekNum: Int, phase: String, peakWeekNum: Int) -> Bool {
        guard phase != Phase.taper else { return false }
        return weekNum % 4 == 0 && weekNum < peakWeekNum
    }

    // MARK: - Mileage

    private static func buildMileageSchedule(baseMileage: Double, peakMileage: Double, weeks: Int, peakWeek: Int) -> [Double] {
        guard weeks > 0, peakWeek > 0, peakWeek <= weeks else {
            return Array(repeating: baseMileage, count: max(weeks, 1))
        }

        let taperStartWeek = weeks - 2
        let startMiles     = (peakMileage * 0.65).rounded(toPlaces: 0)
        var schedule: [Double] = []

        for week in 1...weeks {
            let miles: Double
            if week >= taperStartWeek {
                let weeksFromEnd = weeks - week
                let factor: Double
                switch weeksFromEnd {
                case 2:  factor = 0.80
                case 1:  factor = 0.65
                default: factor = 0.40
                }
                miles = (peakMileage * factor).rounded(toPlaces: 0)
            } else if week == peakWeek {
                miles = peakMileage.rounded(toPlaces: 0)
            } else if week % 4 == 0 && week < peakWeek {
                let fraction  = Double(week - 1) / Double(peakWeek - 1)
                let rawTarget = startMiles + fraction * (peakMileage - startMiles)
                miles = (rawTarget * 0.83).rounded(toPlaces: 0)
            } else {
                let fraction = Double(week - 1) / Double(peakWeek - 1)
                miles = (startMiles + fraction * (peakMileage - startMiles)).rounded(toPlaces: 0)
            }
            schedule.append(max(miles, 25.0))
        }
        return schedule
    }

    // MARK: - Week Days

    private static func buildWeekDays(
        weekNum:     Int,
        totalWeeks:  Int,
        phase:       String,
        weekMiles:   Double,
        isCutback:   Bool,
        schedule:    UserSchedule,
        paces:       PaceEngine,
        tier:        MileageTier,
        peakWeekNum: Int
    ) -> [TrainingDay] {

        let lrDay    = schedule.longRunDay
        let ltDay    = schedule.workoutDay1
        let restDays = schedule.restDays
        let mlrDay   = schedule.midweekLongDay ?? resolveMlrDay(lrDay: lrDay, ltDay: ltDay, restDays: restDays)

        let longMiles = longRunMiles(weekNum: weekNum, totalWeeks: totalWeeks, weekMiles: weekMiles, phase: phase, isCutback: isCutback)
        let mlrMiles  = mediumLongRunMiles(weekMiles: weekMiles, phase: phase, isCutback: isCutback)

        let qualityWorkout = makeQualitySession(
            weekNum:     weekNum,
            totalWeeks:  totalWeeks,
            phase:       phase,
            isCutback:   isCutback,
            tier:        tier,
            paces:       paces,
            peakWeekNum: peakWeekNum
        )

        var days: [TrainingDay] = Weekday.allCases.map { day in
            if restDays.contains(day)                                        { return makeRest(day) }
            if day == lrDay                                                  { return makeLongRun(day, miles: longMiles, paces: paces, phase: phase, weekNum: weekNum, totalWeeks: totalWeeks) }
            if day == mlrDay && !isCutback && phase != Phase.taper           { return makeMediumLongRun(day, miles: mlrMiles, paces: paces, phase: phase) }
            if day == ltDay, let q = qualityWorkout                          { return q }
            if day == lrDay.next                                             { return makeRecovery(day, paces: paces) }
            return makeGeneralAerobic(day, paces: paces)
        }

        days = distributeMiles(days, weeklyTarget: weekMiles, tier: tier)
        return days
    }

    // MARK: - MLR Day

    private static func resolveMlrDay(lrDay: Weekday, ltDay: Weekday, restDays: [Weekday]) -> Weekday {
        let unavailable: Set<Weekday> = Set(restDays).union([lrDay, ltDay])
        let preferences: [Weekday]   = [.tuesday, .wednesday, .thursday]
        return preferences.first { !unavailable.contains($0) }
            ?? Weekday.allCases.first { !unavailable.contains($0) }
            ?? .tuesday
    }

    // MARK: - Long Run Distance

    private static func longRunMiles(weekNum: Int, totalWeeks: Int, weekMiles: Double, phase: String, isCutback: Bool) -> Double {
        switch phase {
        case Phase.aerobicBase:
            return (weekMiles * 0.28).rounded(toPlaces: 0).clamped(to: 12...16)
        case Phase.lactate:
            return (weekMiles * 0.30).rounded(toPlaces: 0).clamped(to: 15...18)
        case Phase.raceSpecific:
            let range: ClosedRange<Double> = isCutback ? 16...18 : 18...22
            return (weekMiles * 0.32).rounded(toPlaces: 0).clamped(to: range)
        case Phase.taper:
            let weeksFromEnd = totalWeeks - weekNum
            switch weeksFromEnd {
            case 2:  return 14
            case 1:  return 12
            default: return 8
            }
        default:
            return 14
        }
    }

    private static func mediumLongRunMiles(weekMiles: Double, phase: String, isCutback: Bool) -> Double {
        guard !isCutback else { return 0 }
        switch phase {
        case Phase.aerobicBase:  return (weekMiles * 0.20).rounded(toPlaces: 0).clamped(to: 10...13)
        case Phase.lactate:      return (weekMiles * 0.22).rounded(toPlaces: 0).clamped(to: 12...15)
        case Phase.raceSpecific: return (weekMiles * 0.24).rounded(toPlaces: 0).clamped(to: 13...17)
        default:                 return 10
        }
    }

    // MARK: - Quality Sessions

    private static func makeQualitySession(weekNum: Int, totalWeeks: Int, phase: String, isCutback: Bool, tier: MileageTier, paces: PaceEngine, peakWeekNum: Int) -> TrainingDay? {
        if phase == Phase.aerobicBase || isCutback { return nil }

        if phase == Phase.taper {
            return makeTaperQuality(weekNum: weekNum, totalWeeks: totalWeeks, paces: paces)
        }

        if phase == Phase.raceSpecific {
            let rseWeek = weekNum - basePhaseLength - lactatePhaseLength
            return rseWeek.isMultiple(of: 2)
                ? makeMarathonPaceSession(rseWeek: rseWeek, tier: tier, paces: paces)
                : makeLTSession(weekNum: weekNum, tier: tier, paces: paces)
        }

        return makeLTSession(weekNum: weekNum, tier: tier, paces: paces)
    }

    private static func makeLTSession(weekNum: Int, tier: MileageTier, paces: PaceEngine) -> TrainingDay {
        let ltWeek = weekNum - basePhaseLength
        let isCruise = ltWeek <= 3

        let ltMiles: Double
        switch tier {
        case .low:      ltMiles = (4.0 + Double(ltWeek) * 0.25).clamped(to: 4...6)
        case .moderate: ltMiles = (4.0 + Double(ltWeek) * 0.35).clamped(to: 4...7)
        case .high:     ltMiles = (5.0 + Double(ltWeek) * 0.40).clamped(to: 5...8)
        case .advanced: ltMiles = (6.0 + Double(ltWeek) * 0.45).clamped(to: 6...9)
        }

        let description: String
        if isCruise {
            let reps = max(Int(ltMiles / 1.5), 2)
            description = "Lactate Threshold — Cruise Intervals. 1.5 mi easy warm-up. \(reps) × 1.5 mi at lactate threshold effort with 1-min standing rest between reps. 1.5 mi easy cool-down. Cruise intervals develop your lactate threshold in repeatable chunks — ideal early LT development before transitioning to sustained tempo work."
        } else {
            description = "Lactate Threshold — Continuous Tempo. 1.5 mi easy warm-up. \(ltMiles.cleanString) mi continuous at lactate threshold — the pace you could sustain for roughly one hour in a race. 1.5 mi easy cool-down. Sustained LT work raises your aerobic ceiling and develops the metabolic resilience to hold marathon pace through the race's second half."
        }

        return TrainingDay(
            weekday:     .wednesday,
            workoutType: .lactateThreshold,
            miles:       ltMiles + 3.0,
            description: description,
            paceNote:    "LT — comfortably hard, ~HM to 15K race effort: \(paces.singleString(paces.pfitzLT))"
        )
    }

    private static func makeMarathonPaceSession(rseWeek: Int, tier: MileageTier, paces: PaceEngine) -> TrainingDay {
        let maxMP: Double
        switch tier {
        case .low:      maxMP = 6
        case .moderate: maxMP = 8
        case .high:     maxMP = 10
        case .advanced: maxMP = 12
        }

        let mpMiles = (3.0 + Double(rseWeek) * 0.75).rounded(toPlaces: 0).clamped(to: 3...maxMP)

        return TrainingDay(
            weekday:     .wednesday,
            workoutType: .marathonPace,
            miles:       mpMiles + 5.0,
            description: "Marathon-Pace Run. 2.5 mi easy warm-up. \(mpMiles.cleanString) mi at goal marathon pace. 2.5 mi easy cool-down. Marathon-pace runs bridge aerobic fitness and race-day execution. The goal pace should feel controlled at the start and comfortably hard by the end — exactly how the race should feel through mile 18. Run precise pace, not approximate.",
            paceNote:    "Goal marathon pace: \(paces.singleString(paces.MP))"
        )
    }

    private static func makeTaperQuality(weekNum: Int, totalWeeks: Int, paces: PaceEngine) -> TrainingDay? {
        let weeksFromEnd = totalWeeks - weekNum
        switch weeksFromEnd {
        case 2:
            return TrainingDay(
                weekday:     .wednesday,
                workoutType: .lactateThreshold,
                miles:       9,
                description: "Taper LT Run. 1.5 mi easy warm-up. 6 mi at lactate threshold effort. 1.5 mi easy cool-down. Full LT volume is behind you — this session preserves the aerobic sharpness you have built. Controlled and sharp, not strained.",
                paceNote:    "LT effort: \(paces.singleString(paces.pfitzLT))"
            )
        case 1:
            return TrainingDay(
                weekday:     .wednesday,
                workoutType: .marathonPace,
                miles:       7,
                description: "Taper Tune-Up — MP Segments. 2 mi easy warm-up. 2 × 2 mi at goal marathon pace with 90-sec easy jog recovery. 1 mi easy cool-down. Confirms the race pace feels natural — not fast, not labored. Two weeks from today you will be running that pace for 26.2 miles. It should feel familiar and controlled.",
                paceNote:    "Goal marathon pace: \(paces.singleString(paces.MP))"
            )
        default:
            return nil
        }
    }

    // MARK: - Day Makers

    private static func makeLongRun(_ day: Weekday, miles: Double, paces: PaceEngine, phase: String, weekNum: Int, totalWeeks: Int) -> TrainingDay {
        let includesMP  = phase == Phase.raceSpecific && miles >= 18
        let workoutType : WorkoutType = includesMP ? .longRunWithMP : .longRun
        let description : String

        if phase == Phase.taper {
            description = "Taper Long Run — \(miles.cleanString) mi. Easy aerobic effort throughout. The fitness is fully in place. Your job right now is simple: arrive at the start line fresh."
        } else if includesMP {
            let mpMiles   = max(4, Int(miles / 4))
            let easyMiles = Int(miles) - mpMiles
            description = "Long Run with Marathon-Pace Finish — \(miles.cleanString) mi. First \(easyMiles) mi easy aerobic. Final \(mpMiles) mi at goal marathon pace. This is Pfitz's race-specific long run: significant aerobic stimulus at meaningful effort, teaching the body to sustain pace when glycogen is taxed."
        } else if phase == Phase.lactate {
            description = "Long Run — \(miles.cleanString) mi. Easy-to-moderate aerobic effort throughout. Optional moderate push in the final 3–4 miles (not marathon pace). Building fatigue resistance for the back half of the marathon."
        } else {
            description = "Long Run — \(miles.cleanString) mi at easy conversational pace. The foundation of Pfitz marathon training. Run entirely at easy-to-moderate effort — the goal is time on feet and mitochondrial adaptation, not pace. Eat and hydrate as you would on race day."
        }

        let paceNote = includesMP
            ? "Easy: \(paces.rangeString(paces.longRun)) → MP: \(paces.singleString(paces.MP))"
            : "Easy aerobic: \(paces.rangeString(paces.longRun))"

        return TrainingDay(weekday: day, workoutType: workoutType, miles: miles, description: description, paceNote: paceNote)
    }

    private static func makeMediumLongRun(_ day: Weekday, miles: Double, paces: PaceEngine, phase: String) -> TrainingDay {
        let context: String
        switch phase {
        case Phase.aerobicBase:  context = "No intensity pressure — this is aerobic volume accumulation."
        case Phase.lactate:      context = "Keep it easy-to-moderate throughout. Lower recovery cost than the long run, but meaningful aerobic stimulus."
        default:                 context = "Peak-phase MLR. These \(miles.cleanString)-mile efforts are a cornerstone of Pfitz training. The aerobic adaptation from consistent MLRs is enormous."
        }

        return TrainingDay(
            weekday:     day,
            workoutType: .mediumLong,
            miles:       miles,
            description: "Medium-Long Run — \(miles.cleanString) mi. \(context) Easy to moderate aerobic effort. Heart rate stays in the aerobic zone. This is a development run, not a workout.",
            paceNote:    "Easy-moderate aerobic: \(paces.rangeString(paces.generalAero))"
        )
    }

    private static func makeGeneralAerobic(_ day: Weekday, paces: PaceEngine) -> TrainingDay {
        TrainingDay(
            weekday:     day,
            workoutType: .easy,
            miles:       0,
            description: "General Aerobic Run. Easy-to-moderate effort — more purposeful than a recovery jog, less demanding than a quality session. Core aerobic volume that supports everything else in the plan.",
            paceNote:    "General aerobic: \(paces.rangeString(paces.generalAero))"
        )
    }

    private static func makeRecovery(_ day: Weekday, paces: PaceEngine) -> TrainingDay {
        TrainingDay(
            weekday:     day,
            workoutType: .recovery,
            miles:       0,
            description: "Recovery Run. Very easy effort — almost embarrassingly slow. Purpose is blood flow and active recovery. If heart rate is climbing, slow down. These runs protect your ability to execute quality sessions.",
            paceNote:    "Recovery pace: \(paces.singleString(paces.recovery))"
        )
    }

    private static func makeRest(_ day: Weekday) -> TrainingDay {
        TrainingDay(
            weekday:     day,
            workoutType: .rest,
            miles:       0,
            description: "Rest Day. Recovery drives aerobic adaptation — the runs created the stimulus; today the body responds to it.",
            paceNote:    "—"
        )
    }

    // MARK: - Mile Distribution

    private static func distributeMiles(_ days: [TrainingDay], weeklyTarget: Double, tier: MileageTier) -> [TrainingDay] {
        let fixed: Set<WorkoutType> = [.rest, .longRun, .longRunWithMP, .mediumLong, .lactateThreshold, .marathonPace, .raceDay, .shakeout]

        let fixedTotal  = days.filter { fixed.contains($0.workoutType) }.reduce(0.0) { $0 + $1.miles }
        let remaining   = max(0.0, weeklyTarget - fixedTotal)
        let flexIndices = days.indices.filter { !fixed.contains(days[$0].workoutType) && days[$0].workoutType != .rest }

        guard !flexIndices.isEmpty else { return days }

        let minE: Double = tier == .low ? 3.0 : 4.0
        let maxE: Double = tier == .advanced ? 10.0 : 8.0
        let per = min(maxE, max(minE, remaining / Double(flexIndices.count))).rounded(toPlaces: 1)

        var result = days
        for i in flexIndices {
            let d = result[i]
            result[i] = TrainingDay(weekday: d.weekday, workoutType: d.workoutType, miles: per, description: d.description, paceNote: d.paceNote)
        }
        return result
    }
}

// MARK: - Helpers

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
    var cleanString: String {
        truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(format: "%.1f", self)
    }
}
