import Foundation

// MARK: - First Half Marathon Plan Generator
//
// For runners who can jog 20–25 min continuously but have
// never followed a structured training plan.
// Exactly 4 running days/week. Peak 28 mpw. Long run to 11 mi.
// No quality sessions. All pacing is effort-based.

struct FirstHalfPlanGenerator {

    // MARK: - Hard Caps

    private static let peakWeekly : Double = 28
    private static let peakLong   : Double = 11

    // MARK: - Entry Point

    static func generate(settings: UserSettings) -> [TrainingWeek] {
        let n        = settings.planLength.rawValue
        let schedule = settings.schedule.validated(for: .firstHalf)
        let mileage  = weeklyMileageSchedule(n: n,
                                              base: settings.baseMileage)
        let longRuns = longRunSchedule(n: n)

        var weeks: [TrainingWeek] = []
        for i in 0..<n {
            let wk    = i + 1
            let total = mileage[i]
            let lr    = longRuns[i]
            let (phase, phaseLabel) = phaseInfo(week: wk, total: n)
            let isCut = isCutback(week: wk, total: n)
            let isTap = wk > n - 2

            weeks.append(buildWeek(
                weekNumber: wk,
                phase:      phase,
                phaseLabel: phaseLabel,
                total:      total,
                longMiles:  lr,
                schedule:   schedule,
                isCutback:  isCut,
                isTaper:    isTap,
                totalWeeks: n
            ))
        }

        return PlanGenerator.injectRaceDay(
            into:     weeks,
            schedule: schedule,
            raceType: .halfMarathon
        )
    }

    // MARK: - Weekly Mileage Schedule

    static func weeklyMileageSchedule(n: Int,
                                       base: Double) -> [Double] {
        let peak       = peakWeekly
        let taperStart = n - 1
        let start      = min(max(base, 12), 16).rounded(toPlaces: 0)

        var result  : [Double] = []
        var current             = start

        for i in 0..<n {
            let wk  = i + 1
            let val : Double

            if wk > taperStart {
                val = (peak * 0.28).rounded(toPlaces: 0)
            } else if wk == taperStart {
                val = (peak * 0.62).rounded(toPlaces: 0)
            } else if isCutback(week: wk, total: n) {
                val = max((current * 0.80).rounded(toPlaces: 0), 12)
            } else {
                let progress = Double(i) / Double(taperStart - 1)
                let target   = start + (peak - start) * progress
                let capped   = min(target, current * 1.10)
                val = min(max(capped.rounded(toPlaces: 0), 12), peak)
                current = val
            }

            result.append(min(val, peakWeekly))
        }

        return result
    }

    // MARK: - Long Run Progression

    static func longRunSchedule(n: Int) -> [Double] {
        let canonical16: [Double] = [
            3,  4,  5,  4,
            6,  7,  5,
            8,  9,  7,
            10, 11,
            8,
            5,
            3,
            0
        ]

        let clamped = canonical16.map { min($0, peakLong) }

        if n == 16 { return clamped }
        if n < 16  { return Array(clamped.dropFirst(16 - n)) }
        let extra = Array(repeating: 3.0, count: n - 16)
        return extra + clamped
    }

    // MARK: - Cutback Detection

    static func isCutback(week: Int, total: Int) -> Bool {
        let offset    = 16 - total
        let canonical = week + offset
        return [4, 7, 10].contains(canonical)
    }

    // MARK: - Phase Info
    // Returns both the canonical TrainingPhase enum and the
    // First Half-specific display label.

    static func phaseInfo(week: Int, total: Int) -> (TrainingPhase, String) {
        let isTap  = week > total - 2
        let offset = 16 - total
        let c      = week + offset

        if isTap   { return (.taper, "Taper")            }
        if c <= 4  { return (.base,  "Getting Started")  }
        if c <= 10 { return (.base,  "Building Fitness") }
        return             (.build,  "Race Preparation")
    }

    // MARK: - Week Builder

    static func buildWeek(
        weekNumber : Int,
        phase      : TrainingPhase,   // canonical enum
        phaseLabel : String,          // First Half-specific display
        total      : Double,
        longMiles  : Double,
        schedule   : UserSchedule,
        isCutback  : Bool,
        isTaper    : Bool,
        totalWeeks : Int
    ) -> TrainingWeek {
        let lrDay = schedule.longRunDay
        let q1Day = schedule.workoutDay1
        let q2Day = schedule.workoutDay2
        let rests = schedule.restDays

        let runningDays: Set<Weekday> = [lrDay, q1Day, q2Day]

        let longM       = min(max(longMiles, 3), peakLong)
        let cappedTotal = min(total, peakWeekly)
        let remain      = max(0, cappedTotal - longM)

        let easyM   = (remain / 2.0).rounded(toPlaces: 1)
        let steadyM = max(0, remain - easyM).rounded(toPlaces: 1)

        var days: [TrainingDay] = []

        for day in Weekday.allCases {
            let td: TrainingDay

            if rests.contains(day) {
                td = makeRest(day, isTaper: isTaper)
            } else if day == lrDay {
                td = makeLongRun(day, miles: longM,
                                 weekNumber: weekNumber,
                                 totalWeeks: totalWeeks,
                                 isTaper:    isTaper)
            } else if day == q1Day {
                td = makeEasyRun(day, miles: easyM,
                                 weekNumber: weekNumber,
                                 isCutback:  isCutback)
            } else if day == q2Day {
                td = makeSteadyRun(day, miles: steadyM,
                                   weekNumber: weekNumber,
                                   isTaper:    isTaper)
            } else if runningDays.contains(day) {
                td = makeEasyRun(day, miles: easyM,
                                 weekNumber: weekNumber,
                                 isCutback:  isCutback)
            } else {
                td = makeRest(day, isTaper: isTaper)
            }

            days.append(td)
        }

        return TrainingWeek(
            weekNumber: weekNumber,
            phase:      phase,       // TrainingPhase enum
            phaseLabel: phaseLabel,  // "Getting Started", "Building Fitness", etc.
            days:       days
        )
    }

    // MARK: - Day Makers

    static func makeRest(_ day: Weekday,
                         isTaper: Bool) -> TrainingDay {
        let desc = isTaper
            ? "Rest day. Your body is storing energy for race day. This is not wasted time — it is the plan working."
            : "Full rest. You earned this. Your body rebuilds on rest days — this is where fitness actually improves."
        return TrainingDay(weekday:     day,
                           workoutType: .rest,
                           miles:       0,
                           description: desc,
                           paceNote:    "—")
    }

    static func makeLongRun(_ day      : Weekday,
                             miles     : Double,
                             weekNumber: Int,
                             totalWeeks: Int,
                             isTaper   : Bool) -> TrainingDay {
        let weeksToRace = totalWeeks - weekNumber

        let desc: String
        switch (isTaper, weeksToRace) {
        case (true, 1):
            desc = "Final long run before the race. Keep it easy and comfortable — you are not building fitness today. You are arriving at the start line healthy."
        case (true, _):
            desc = "Taper long run. Run easy and enjoy it. Your peak fitness is already built. Trust the process."
        case (false, _) where miles <= 5:
            desc = "Your long run for the week. Run at a pace where you could hold a full conversation. Time on feet is what matters — not pace."
        case (false, _) where miles <= 8:
            desc = "Long run day. This is the most important run of your week. Start slower than feels right and finish feeling good."
        default:
            desc = "Long run. Run the first half easier than feels necessary. The back half will take care of itself. You are building race-day confidence one long run at a time."
        }

        let paceNote = miles <= 5
            ? "Easy conversational effort — no pace target"
            : "Relaxed and conversational throughout"

        return TrainingDay(weekday:     day,
                           workoutType: .longRun,
                           miles:       miles,
                           description: desc,
                           paceNote:    paceNote)
    }

    static func makeEasyRun(_ day       : Weekday,
                             miles      : Double,
                             weekNumber : Int,
                             isCutback  : Bool) -> TrainingDay {
        let descs: [String] = [
            "Easy run. Keep it genuinely easy — you should be able to speak in full sentences without effort. If you cannot, slow down.",
            "Easy run today. The purpose of this run is aerobic base-building. Pace does not matter. Time on feet does.",
            "Easy run. Go out, move your legs, come home feeling better than when you left. That is the whole goal.",
            "Easy aerobic run. This is not a fitness test. It is a habit-building run. Show up, run easy, recover well.",
            "Easy run. You are building consistency, and consistency is what gets you to the start line healthy and ready."
        ]
        let desc = descs[weekNumber % descs.count]
        let note = isCutback
            ? "Easy effort — this is a lighter week"
            : "Easy conversational pace"

        return TrainingDay(weekday:     day,
                           workoutType: .easy,
                           miles:       miles,
                           description: desc,
                           paceNote:    note)
    }

    static func makeSteadyRun(_ day       : Weekday,
                               miles      : Double,
                               weekNumber : Int,
                               isTaper    : Bool) -> TrainingDay {
        if isTaper {
            return TrainingDay(
                weekday:     day,
                workoutType: .easy,
                miles:       miles,
                description: "Easy run during taper. Keep it comfortable and relaxed. Your legs may feel sluggish — that is normal and temporary.",
                paceNote:    "Easy effort — no pressure this week"
            )
        }

        let descs: [String] = [
            "Steady run. A little more purposeful than your easy days, but never hard. Comfortably controlled — you could talk, but you choose not to.",
            "Steady run. This mid-week effort bridges your easy days and your long run. Comfortably challenging. Not a sufferfest.",
            "Steady run. Think of this as your confidence run — a pace that feels honest but sustainable. You have got this.",
            "Steady mid-week run. Run at an effort you could hold for an hour. Solid, controlled, and consistent.",
            "Steady run. This is the run that quietly builds your fitness while the long run gets all the attention."
        ]
        let desc = descs[weekNumber % descs.count]

        return TrainingDay(weekday:     day,
                           workoutType: .steadyRun,
                           miles:       miles,
                           description: desc,
                           paceNote:    "Comfortably steady — you could talk but prefer not to")
    }
}
