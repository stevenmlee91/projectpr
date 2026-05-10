import Foundation

// MARK: - Higdon Novice Marathon Generator
//
// Authentic Hal Higdon Novice philosophy:
// - 4–5 runs per week, mostly easy
// - Long run is the only event that matters
// - Cutback every 3 weeks
// - 3-week taper
// - Walk breaks are explicitly permitted
// - Peak ~40 mpw, long run peaks at 20 miles
// - Zero structured quality work
// - Tone: warm, encouraging, accessible

struct HigdonNoviceGenerator {

    // MARK: - Hard Caps
    private static let peakWeekly : Double = 40
    private static let peakLong   : Double = 20

    // MARK: - Entry Point

    static func generate(settings: UserSettings) -> [TrainingWeek] {
        let n        = settings.planLength.rawValue
        let schedule = settings.schedule.validated(for: .higdon)
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
            let isTap = wk > n - 3   // 3-week taper

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
            raceType: .marathon
        )
    }

    // MARK: - Weekly Mileage

    static func weeklyMileageSchedule(n: Int,
                                       base: Double) -> [Double] {
        let peak       = peakWeekly
        let taperStart = n - 2
        let start      = min(max(base, 15), 25).rounded(toPlaces: 0)

        var result  : [Double] = []
        var current             = start

        for i in 0..<n {
            let wk  = i + 1
            let val : Double

            if wk > taperStart + 1 {
                val = (peak * 0.25).rounded(toPlaces: 0)
            } else if wk == taperStart + 1 {
                val = (peak * 0.55).rounded(toPlaces: 0)
            } else if wk == taperStart {
                val = (peak * 0.75).rounded(toPlaces: 0)
            } else if wk == taperStart - 1 {
                val = peak
                current = peak
            } else if isCutback(week: wk, total: n) {
                val = max((current * 0.80).rounded(toPlaces: 0), 15)
            } else {
                let buildWeeks = taperStart - 2
                let progress   = Double(i) / Double(buildWeeks)
                let target     = start + (peak - start) * progress
                let capped     = min(target, current * 1.10)
                val = min(max(capped.rounded(toPlaces: 0), 15), peak)
                current = val
            }

            result.append(min(val, peakWeekly))
        }
        return result
    }

    // MARK: - Long Run Progression

    static func longRunSchedule(n: Int) -> [Double] {
        let canonical18: [Double] = [
            6,  8,  10, 8,
            10, 11, 13, 10,
            13, 15, 16, 12,
            18, 14, 20,
            12,
            8,
            0
        ]

        let clamped = canonical18.map { min($0, peakLong) }

        if n == 18 { return clamped }
        if n < 18  { return Array(clamped.dropFirst(18 - n)) }
        let extra = Array(repeating: 6.0, count: n - 18)
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
    // Higdon-specific display label.

    static func phaseInfo(week: Int, total: Int) -> (TrainingPhase, String) {
        let isTap  = week > total - 3
        let offset = 18 - total
        let c      = week + offset

        if isTap   { return (.taper, "Taper")                    }
        if c <= 4  { return (.base,  "Getting Started")          }
        if c <= 9  { return (.base,  "Building Endurance")       }
        if c <= 14 { return (.build, "Going the Distance")       }
        return             (.build,  "Race Preparation")
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
        totalWeeks : Int
    ) -> TrainingWeek {
        let lrDay = schedule.longRunDay
        let q1Day = schedule.workoutDay1
        let q2Day = schedule.workoutDay2
        let rests = schedule.restDays
        let mwDay = schedule.midweekLongDay

        let longM  = min(max(longMiles, 6), peakLong)
        let remain = max(0, min(total, peakWeekly) - longM)

        let thirdM  = (remain * 0.28).rounded(toPlaces: 1)
        let easyM   = (remain * 0.38).rounded(toPlaces: 1)
        let midM    = max(0, remain - thirdM - easyM)
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
                td = makeMidweekEasy(day, miles: midM,
                                     weekNumber: weekNumber,
                                     isTaper: isTaper)
            } else if day == q1Day {
                td = makeEasyRun(day, miles: easyM,
                                 weekNumber: weekNumber,
                                 isCutback: isCutback)
            } else if day == q2Day {
                td = makeShortEasy(day, miles: thirdM,
                                   weekNumber: weekNumber,
                                   isTaper: isTaper)
            } else {
                td = makeRest(day, isTaper: isTaper)
            }

            days.append(td)
        }

        return TrainingWeek(
            weekNumber: weekNumber,
            phase:      phase,       // TrainingPhase enum
            phaseLabel: phaseLabel,  // "Getting Started", "Building Endurance", etc.
            days:       days
        )
    }

    // MARK: - Day Makers

    static func makeRest(_ day: Weekday,
                         isTaper: Bool) -> TrainingDay {
        let desc = isTaper
            ? "Rest day. Your body is banking energy for race day. This is training — it just looks like doing nothing."
            : "Rest day. Hal Higdon believes rest is as important as running. Take it seriously."
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
            desc = "Taper long run. Keep it comfortable and relaxed. Your fitness is built — this run maintains rhythm, nothing more. Walking is fine."
        case (true, _, _):
            desc = "Easy taper run. Short and comfortable. Save your legs for race day."
        case (false, true, _):
            desc = "Recovery long run — shorter than last week by design. Your body needs this lighter week to absorb the training. Run easy and enjoy the reduced load."
        case (false, false, _) where miles >= 18:
            desc = "Your longest training run. This is the one. Run easy from start to finish — walking is completely acceptable and encouraged if you need it. Finishing strong matters more than pace."
        case (false, false, _) where miles >= 14:
            desc = "A big long run. Settle into an easy rhythm early and hold it. If you need to walk, walk — Hal Higdon says this is fine. The goal is time on feet, not speed."
        case (false, false, _) where miles >= 10:
            desc = "Long run day. The most important run of your week. Run slow enough that you could hold a full conversation. Every mile you run today makes race day easier."
        default:
            desc = "Long run. Go slower than feels right and you will almost certainly finish feeling good. The long run is not a race — it is an investment."
        }

        let paceNote = miles >= 16
            ? "Very easy — walking is encouraged if needed"
            : "Easy conversational pace — no pace target"

        return TrainingDay(weekday:     day,
                           workoutType: .longRun,
                           miles:       miles,
                           description: desc,
                           paceNote:    paceNote)
    }

    static func makeMidweekEasy(_ day       : Weekday,
                                 miles      : Double,
                                 weekNumber : Int,
                                 isTaper    : Bool) -> TrainingDay {
        if isTaper {
            return TrainingDay(
                weekday:     day,
                workoutType: .easy,
                miles:       miles,
                description: "Easy mid-week run. Keep it short and relaxed. Your body is recovering and storing energy. Enjoy this light week.",
                paceNote:    "Easy — relaxed and comfortable"
            )
        }

        let descs: [String] = [
            "Mid-week run. This is the heartbeat of your training week — a comfortable effort that keeps your legs moving between the long run and your other easy days.",
            "Wednesday run. Medium distance, easy effort. This run builds your weekly mileage base quietly and consistently.",
            "Mid-week easy run. Run at a pace you could sustain for hours. No pressure, no structure — just running.",
            "Easy mid-week run. Hal Higdon's plans are built around consistency. This run is part of that consistency.",
            "Mid-week run. Go out, run comfortably, come home. That is the entire instruction."
        ]
        return TrainingDay(weekday:     day,
                           workoutType: .easy,
                           miles:       miles,
                           description: descs[weekNumber % descs.count],
                           paceNote:    "Comfortable easy effort")
    }

    static func makeEasyRun(_ day       : Weekday,
                             miles      : Double,
                             weekNumber : Int,
                             isCutback  : Bool) -> TrainingDay {
        let descs: [String] = [
            "Easy run. The goal is simple: go out, run at a comfortable pace, finish feeling like you could have kept going.",
            "Easy run. Keep it conversational — if you cannot speak comfortably, slow down. There is no pace goal today.",
            "Easy run. Every easy mile makes your long run easier. This is the foundation Higdon's plan is built on.",
            "Easy run. Relaxed effort from start to finish. Your aerobic base grows one comfortable run at a time.",
            "Easy run day. Run at a pace that feels sustainable and enjoyable. Consistency builds marathoners."
        ]
        let note = isCutback
            ? "Easy — lighter week, keep the effort relaxed"
            : "Easy conversational effort"

        return TrainingDay(weekday:     day,
                           workoutType: .easy,
                           miles:       miles,
                           description: descs[weekNumber % descs.count],
                           paceNote:    note)
    }

    static func makeShortEasy(_ day       : Weekday,
                               miles      : Double,
                               weekNumber : Int,
                               isTaper    : Bool) -> TrainingDay {
        if isTaper {
            return TrainingDay(
                weekday:     day,
                workoutType: .easy,
                miles:       miles,
                description: "Short easy run. Legs moving, nothing more. Race week is about staying loose, not building fitness.",
                paceNote:    "Very easy — just shake the legs out"
            )
        }
        return TrainingDay(
            weekday:     day,
            workoutType: .easy,
            miles:       miles,
            description: "Short easy run. This supports the long run — it adds mileage without adding fatigue. Keep it comfortable and brief.",
            paceNote:    "Easy — shorter and comfortable"
        )
    }
}
