import Foundation

// MARK: - Higdon Intermediate Marathon Generator
//
// Authentic Hal Higdon Intermediate philosophy:
// - 5 runs per week + cross-training
// - Tempo runs introduced from week 3 (casual effort, not structured threshold)
// - Mid-week medium long run
// - Cutback every 3 weeks
// - 3-week taper
// - Peak ~48 mpw, long run peaks at 22 miles
// - Tone: structured but still approachable

struct HigdonIntermediateGenerator {

    // MARK: - Hard Caps
    private static let peakWeekly : Double = 48
    private static let peakLong   : Double = 22

    // MARK: - Entry Point

    static func generate(settings: UserSettings) -> [TrainingWeek] {
        let n        = settings.planLength.rawValue
        let schedule = settings.schedule.validated(for: .higdonIntermediate)
        let mileage  = weeklyMileageSchedule(n: n,
                                              base: settings.baseMileage)
        let longRuns = longRunSchedule(n: n)

        var weeks: [TrainingWeek] = []
        for i in 0..<n {
            let wk       = i + 1
            let total    = mileage[i]
            let lr       = longRuns[i]
            let (phase, phaseLabel) = phaseInfo(week: wk, total: n)
            let isCut    = isCutback(week: wk, total: n)
            let isTap    = wk > n - 3
            let offset   = 18 - n
            let canonical = wk + offset
            let useTempo = canonical >= 3 && !isTap && !isCut

            weeks.append(buildWeek(
                weekNumber: wk,
                phase:      phase,
                phaseLabel: phaseLabel,
                total:      total,
                longMiles:  lr,
                schedule:   schedule,
                isCutback:  isCut,
                isTaper:    isTap,
                useTempo:   useTempo,
                totalWeeks: n
            ))
        }

        return PlanGenerator.injectRaceDay(
            into:     weeks,
            schedule: schedule,
            raceType: .marathon
        )
    }

    // MARK: - Weekly Mileage

    static func weeklyMileageSchedule(n: Int,
                                       base: Double) -> [Double] {
        let peak       = peakWeekly
        let taperStart = n - 2
        let start      = min(max(base, 20), 35).rounded(toPlaces: 0)

        var result  : [Double] = []
        var current             = start

        for i in 0..<n {
            let wk  = i + 1
            let val : Double

            if wk > taperStart + 1 {
                val = (peak * 0.28).rounded(toPlaces: 0)
            } else if wk == taperStart + 1 {
                val = (peak * 0.58).rounded(toPlaces: 0)
            } else if wk == taperStart {
                val = (peak * 0.78).rounded(toPlaces: 0)
            } else if wk == taperStart - 1 {
                val = peak
                current = peak
            } else if isCutback(week: wk, total: n) {
                val = max((current * 0.82).rounded(toPlaces: 0), 20)
            } else {
                let buildWeeks = taperStart - 2
                let progress   = Double(i) / Double(buildWeeks)
                let target     = start + (peak - start) * progress
                let capped     = min(target, current * 1.10)
                val = min(max(capped.rounded(toPlaces: 0), 20), peak)
                current = val
            }

            result.append(min(val, peakWeekly))
        }
        return result
    }

    // MARK: - Long Run Progression

    static func longRunSchedule(n: Int) -> [Double] {
        let canonical18: [Double] = [
            8,  10, 12, 10,
            12, 13, 15, 12,
            15, 17, 18, 14,
            20, 16, 22,
            14,
            8,
            0
        ]

        let clamped = canonical18.map { min($0, peakLong) }

        if n == 18 { return clamped }
        if n < 18  { return Array(clamped.dropFirst(18 - n)) }
        let extra = Array(repeating: 8.0, count: n - 18)
        return extra + clamped
    }

    // MARK: - Cutback Detection

    static func isCutback(week: Int, total: Int) -> Bool {
        let offset    = 18 - total
        let canonical = week + offset
        return [4, 8, 12].contains(canonical)
    }

    // MARK: - Phase Info
    // Returns both the canonical TrainingPhase enum and the
    // Higdon Intermediate-specific display label.

    static func phaseInfo(week: Int, total: Int) -> (TrainingPhase, String) {
        let isTap  = week > total - 3
        let offset = 18 - total
        let c      = week + offset

        if isTap   { return (.taper, "Taper")                  }
        if c <= 4  { return (.base,  "Base Building")          }
        if c <= 9  { return (.base,  "Aerobic Development")    }
        if c <= 14 { return (.build, "Marathon Preparation")   }
        return             (.build,  "Race Sharpening")
    }

    // MARK: - Week Builder

    static func buildWeek(
        weekNumber : Int,
        phase      : TrainingPhase,   // canonical enum
        phaseLabel : String,          // Higdon-specific display
        total      : Double,
        longMiles  : Double,
        schedule   : UserSchedule,
        isCutback  : Bool,
        isTaper    : Bool,
        useTempo   : Bool,
        totalWeeks : Int
    ) -> TrainingWeek {
        let lrDay  = schedule.longRunDay
        let q1Day  = schedule.workoutDay1
        let mwDay  = schedule.midweekLongDay
        let ctDay  = schedule.crossTrainDay
        let rests  = schedule.restDays

        let longM  = min(max(longMiles, 8), peakLong)
        let remain = max(0, min(total, peakWeekly) - longM)

        let tempoM  = useTempo
            ? min(8.0, max(4.0, (remain * 0.22).rounded(toPlaces: 1)))
            : 0
        let midM    = (remain * 0.35).rounded(toPlaces: 1)
        let easyM   = max(0, remain - tempoM - midM)
            .rounded(toPlaces: 1)

        var days: [TrainingDay] = []

        for day in Weekday.allCases {
            let td: TrainingDay

            if rests.contains(day) {
                td = makeRest(day, isTaper: isTaper)
            } else if day == lrDay {
                td = makeLongRun(day, miles: longM,
                                 weekNumber: weekNumber,
                                 totalWeeks: totalWeeks,
                                 isTaper:    isTaper,
                                 isCutback:  isCutback)
            } else if day == mwDay {
                td = makeMidweekLong(day, miles: midM,
                                     weekNumber: weekNumber,
                                     isTaper: isTaper)
            } else if let ct = ctDay, day == ct {
                td = makeCrossTrain(day, isTaper: isTaper)
            } else if day == q1Day {
                td = useTempo
                    ? makeTempo(day, miles: tempoM,
                                weekNumber: weekNumber)
                    : makeEasyRun(day, miles: easyM,
                                  weekNumber: weekNumber,
                                  isCutback: isCutback)
            } else {
                td = makeEasyRun(day, miles: easyM,
                                 weekNumber: weekNumber,
                                 isCutback: isCutback)
            }

            days.append(td)
        }

        return TrainingWeek(
            weekNumber: weekNumber,
            phase:      phase,       // TrainingPhase enum
            phaseLabel: phaseLabel,  // "Base Building", "Aerobic Development", etc.
            days:       days
        )
    }

    // MARK: - Day Makers

    static func makeRest(_ day: Weekday,
                         isTaper: Bool) -> TrainingDay {
        let desc = isTaper
            ? "Rest day. The taper is doing its job. Your muscles are rebuilding and your glycogen is loading. Trust the process."
            : "Rest day. Recovery is when your body adapts to the training. This day is not wasted — it is essential."
        return TrainingDay(weekday:     day,
                           workoutType: .rest,
                           miles:       0,
                           description: desc,
                           paceNote:    "—")
    }

    static func makeLongRun(_ day       : Weekday,
                             miles      : Double,
                             weekNumber : Int,
                             totalWeeks : Int,
                             isTaper    : Bool,
                             isCutback  : Bool) -> TrainingDay {
        let weeksToRace = totalWeeks - weekNumber

        let desc: String
        switch (isTaper, isCutback, weeksToRace) {
        case (true, _, 0), (true, _, 1):
            desc = "Final taper long run. Easy from start to finish. You are not building fitness — you are maintaining rhythm and arriving at the start line fresh."
        case (true, _, _):
            desc = "Taper long run. Shorter and comfortable. Your peak fitness is already built. Run relaxed and trust the work you have done."
        case (false, true, _):
            desc = "Shorter long run by design — this is a recovery week. Your body needs lighter load to absorb the previous training. Run easy and appreciate the rest."
        case (false, false, _) where miles >= 20:
            desc = "Your peak long run. This is the longest you will run before the marathon. Easy effort throughout — the distance is the achievement. Run the first half conservatively."
        case (false, false, _) where miles >= 16:
            desc = "A major long run. Settle into a comfortable rhythm early. The goal is to finish feeling strong, not to run fast. Every mile here is a deposit in your marathon bank."
        case (false, false, _) where miles >= 12:
            desc = "Long run day. Easy and steady. You are building the endurance foundation that will carry you through race day. Pace is irrelevant — effort is everything."
        default:
            desc = "Long run. Start easy, finish easy. Let your body find its natural rhythm."
        }

        let paceNote = miles >= 18
            ? "Easy effort — well below race pace throughout"
            : "Comfortable easy effort"

        return TrainingDay(weekday:     day,
                           workoutType: .longRun,
                           miles:       miles,
                           description: desc,
                           paceNote:    paceNote)
    }

    static func makeMidweekLong(_ day       : Weekday,
                                 miles      : Double,
                                 weekNumber : Int,
                                 isTaper    : Bool) -> TrainingDay {
        if isTaper {
            return TrainingDay(
                weekday:     day,
                workoutType: .midweekLong,
                miles:       miles,
                description: "Mid-week run during taper. Short and comfortable — keep the legs moving without any fatigue. Your focus this week is rest and readiness.",
                paceNote:    "Easy — taper effort"
            )
        }

        let descs: [String] = [
            "Mid-week longer run. This is a Higdon Intermediate signature — a medium long run mid-week that builds your aerobic base beyond what the long run alone can achieve.",
            "Mid-week run. Longer than your easy days, shorter than your long run. Comfortable effort throughout — this is aerobic development, not a workout.",
            "Wednesday medium run. A steady comfortable effort. Not a recovery run, not a workout — somewhere comfortably in between.",
            "Mid-week longer run. This is what separates Intermediate from Novice — an additional longer effort mid-week that accumulates meaningful endurance.",
            "Mid-week run. Comfortably aerobic. This run builds marathon-specific endurance without the recovery cost of the long run."
        ]
        return TrainingDay(weekday:     day,
                           workoutType: .midweekLong,
                           miles:       miles,
                           description: descs[weekNumber % descs.count],
                           paceNote:    "Comfortable aerobic effort — not a recovery shuffle")
    }

    static func makeCrossTrain(_ day: Weekday,
                                isTaper: Bool) -> TrainingDay {
        let desc = isTaper
            ? "Cross-training during taper. 30–40 minutes of easy cycling, swimming, or elliptical. Keep the heart rate low and the effort relaxed."
            : "Cross-training day. 45–60 minutes of low-impact aerobic work — cycling, swimming, or elliptical. This maintains fitness while giving your joints a break from running impact."
        return TrainingDay(weekday:     day,
                           workoutType: .crossTrain,
                           miles:       0,
                           description: desc,
                           paceNote:    "Low-impact aerobic effort")
    }

    static func makeTempo(_ day       : Weekday,
                           miles      : Double,
                           weekNumber : Int) -> TrainingDay {
        let canonical  = weekNumber
        let tempoMiles = max(2, min(6, canonical / 3))
        let warmup     = 1
        let cooldown   = 1
        let totalDesc  = warmup + tempoMiles + cooldown

        let descs: [String] = [
            "Tempo run. \(warmup) mile easy warm-up, \(tempoMiles) miles at a comfortably hard effort — faster than your easy pace but not a race. \(cooldown) mile easy cool-down. You should be working but not gasping.",
            "Tempo run. After a \(warmup)-mile warm-up, run \(tempoMiles) miles at a steady, honest effort — the pace you could sustain for about an hour. Cool down \(cooldown) mile easy.",
            "Tempo run. \(warmup) mile warm-up. \(tempoMiles) miles comfortably hard — a pace that feels challenging but controlled. You could speak a short sentence if needed. \(cooldown) mile easy.",
            "Tempo run. Warm up \(warmup) mile, run \(tempoMiles) miles at a firm comfortable pace, cool down \(cooldown) mile. This is aerobic development, not an all-out effort.",
            "Tempo run. \(tempoMiles) miles at a sustained, comfortably hard effort sandwiched between \(warmup)-mile warm-up and cool-down. Run by feel — slightly harder than your usual easy pace."
        ]

        return TrainingDay(weekday:     day,
                           workoutType: .tempoRun,
                           miles:       Double(totalDesc),
                           description: descs[weekNumber % descs.count],
                           paceNote:    "Comfortably hard — about half marathon effort, not all-out")
    }

    static func makeEasyRun(_ day       : Weekday,
                             miles      : Double,
                             weekNumber : Int,
                             isCutback  : Bool) -> TrainingDay {
        let descs: [String] = [
            "Easy run. Comfortable effort from start to finish. If you cannot hold a conversation, slow down. These runs are the foundation of your marathon fitness.",
            "Easy run. Relaxed pace, no pressure. Your aerobic engine builds run by run through consistent easy effort.",
            "Easy run. Go at a pace that feels comfortable and sustainable. Hal Higdon's plans are built on this kind of consistent, unpressured running.",
            "Easy run. Keep it genuinely easy. The tempo and long runs provide the stimulus — easy runs provide the recovery and volume base that supports them.",
            "Easy run. No structure, no target pace. Just comfortable running that accumulates miles without accumulating unnecessary fatigue."
        ]
        let note = isCutback
            ? "Easy — recovery week, keep the effort light"
            : "Easy conversational effort"

        return TrainingDay(weekday:     day,
                           workoutType: .easy,
                           miles:       miles,
                           description: descs[weekNumber % descs.count],
                           paceNote:    note)
    }
}
