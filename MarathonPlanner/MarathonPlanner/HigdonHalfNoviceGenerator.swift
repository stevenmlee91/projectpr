import Foundation

// MARK: - Higdon Half Marathon Novice Generator
//
// TARGET RUNNER: First or second race. May be running consistently but has
// never followed a structured plan. May be nervous about the distance.
//
// PHILOSOPHY: Hal Higdon's approach is completion over optimization.
// The plan builds confidence progressively and never overwhelms.
// Every week should feel achievable. Every long run should feel like a victory.
//
// STRUCTURE:
//   3 running days per week — long run (weekend) + 2 easy mid-week
//   2 cross-training days — low-impact aerobic, joint-friendly
//   2 rest days
//   No quality/speed/tempo work — ALL running is easy
//   Long run peaks at 10 miles
//   Cutback every 3rd week
//   2-week taper
//
// COACHING VOICE:
//   Encouraging, jargon-free, confidence-building.
//   Explanations for every workout type.
//   The runner should always feel: "I can do this."

struct HigdonHalfNoviceGenerator {

    // MARK: - Constants

    private static let peakWeekly : Double = 28
    private static let peakLong   : Double = 10

    // MARK: - Entry Point

    static func generate(settings: UserSettings) -> [TrainingWeek] {
        let n          = settings.planLength.rawValue
        let taperWeeks = settings.taperDuration.rawValue
        let schedule   = settings.schedule.validated(for: .higdonHalfNovice)
        let paces      = PaceEngine(goalMinutes: settings.goalTimeMinutes,
                                     distance: 13.1)
        let mileage    = weeklyMileageSchedule(n: n, base: settings.baseMileage,
                                               taperWeeks: taperWeeks)
        let longRuns   = longRunSchedule(n: n, taperWeeks: taperWeeks,
                                          base: settings.baseMileage)

        var weeks: [TrainingWeek] = []
        for i in 0..<n {
            let wk    = i + 1
            let lr    = longRuns[i]
            let total = mileage[i]
            let isTap = wk > n - taperWeeks
            let isCut = isCutback(week: wk, total: n, taperWeeks: taperWeeks)
            let (phase, phaseLabel) = phaseInfo(week: wk, total: n, taperWeeks: taperWeeks)

            weeks.append(buildWeek(
                weekNumber: wk,
                phase:      phase,
                phaseLabel: phaseLabel,
                total:      total,
                longMiles:  lr,
                schedule:   schedule,
                isCutback:  isCut,
                isTaper:    isTap,
                totalWeeks: n,
                paces:      paces
            ))
        }

        return PlanGenerator.injectRaceDay(into: weeks, schedule: schedule,
                                            raceType: .halfMarathon)
    }

    // MARK: - Weekly Mileage Schedule

    static func weeklyMileageSchedule(n: Int, base: Double,
                                       taperWeeks: Int) -> [Double] {
        let peak       = peakWeekly
        let buildWeeks = n - taperWeeks

        // FIXED: Adaptive start that works for true beginners.
        // Old: min(max(base, 9), 16) forced 0 mpw runners to start at 9 mpw.
        // New: starts near the runner's actual base, floor at 6 mpw (2 mi × 3 days).
        // A 0 mpw runner starts at 6. A 15 mpw runner starts at 15. A 25 mpw runner
        // starts at 25 (capped near peak). No artificial regression for high-base runners.
        let start = max(base + 2.0, 6.0).rounded(toPlaces: 0)

        // FIXED: Compute achievablePeak — what this runner can realistically reach.
        // Old: targeted peakWeekly (28) regardless of base. A 0 mpw runner could
        // never reach 28 in 10 build weeks, causing the smooth target to always
        // be capped by the 10% rule, producing a valid curve but aimed at the wrong peak.
        // New: 10% rule ceiling from actual start, with 3 cutback-week deductions.
        let cutbacksInPlan = 3  // canonical weeks 3, 6, 9
        let effectiveBuildWeeks = max(1, buildWeeks - cutbacksInPlan)
        let rawAchievable = start * pow(1.10, Double(effectiveBuildWeeks))
        let achievablePeak = min(peak, rawAchievable).rounded(toPlaces: 0)

        var result  : [Double] = []
        var current             = start

        for i in 0..<buildWeeks {
            let wk = i + 1
            if isCutback(week: wk, total: n, taperWeeks: taperWeeks) {
                let val = max(start, (current * 0.80).rounded(toPlaces: 0))
                result.append(val)
                // current does not update on cutback weeks
            } else {
                let progress = buildWeeks > 1
                    ? Double(i) / Double(buildWeeks - 1) : 1.0
                let target = start + (achievablePeak - start) * progress
                let capped = min(target, current * 1.10)
                let val    = min(max(capped.rounded(toPlaces: 0), start), achievablePeak)
                result.append(val)
                current = val
            }
        }

        // Taper from achievedPeak — the actual highest week, not the target ceiling.
        let achievedPeak = result.max() ?? achievablePeak

        // RACE WEEK: append 0 so buildWeek receives longMiles=0 and isRaceWeek
        // detection suppresses easy runs. injectRaceDay then adds only:
        // shakeout (2 mi) + race (13.1 mi) = 15.1 miles total for race week.
        // This prevents race week from becoming the highest bar in the chart.
        var taperMiles: [Double]
        if taperWeeks == 3 {
            taperMiles = [(achievedPeak * 0.70).rounded(toPlaces: 0),
                          (achievedPeak * 0.50).rounded(toPlaces: 0),
                          0]   // race week placeholder
        } else {
            taperMiles = [(achievedPeak * 0.60).rounded(toPlaces: 0),
                          0]   // race week placeholder
        }
        return result + taperMiles
    }

    // MARK: - Long Run Schedule
    //
    // Canonical 12-week sequence. Cutbacks every 3rd week.
    // Peaks at 10 miles across two weeks, then taper.

    static func longRunSchedule(n: Int, taperWeeks: Int, base: Double) -> [Double] {
        let buildWeeks = n - taperWeeks

        // longStart adapts from base. Floor raised to 4.0 (from 3.0) so
        // week 2 cutback has a real destination: max(3.0, 4-2) = 3, not 3→3.
        let longStart  = max(base * 0.40, 4.0).rounded(toPlaces: 0)
        let longPeak   = peakLong  // 10 miles

        let progressiveWeeks = (0..<buildWeeks).filter { i in
            !isCutback(week: i + 1, total: n, taperWeeks: taperWeeks)
        }.count

        // PROGRESSION RULE:
        //   idx 0             → longStart   (first progressive week anchors at entry)
        //   idx 1..(p-2)      → current + 1  (steady +1/week, no surprises)
        //   idx (p-1) (final) → min(longPeak, current + 2)  (peak push, ≤ +2)
        //
        // This guarantees all progressive week-to-week transitions ≤ +1,
        // except the final progressive week which may be +2 if needed to
        // reach longPeak. The final +2 is the climactic long run before
        // taper — physiologically appropriate and psychologically satisfying.
        //
        // Cutback floor: max(3.0, ...) — absolute minimum, not longStart floor,
        // so cutbacks are meaningful even when longStart is small.

        var buildLRs   : [Double] = []
        var current     = longStart
        var progressIdx = 0

        for i in 0..<buildWeeks {
            let wk    = i + 1
            let isCut = isCutback(week: wk, total: n, taperWeeks: taperWeeks)

            if isCut {
                let cutback = max(3.0, current - 2.0)
                buildLRs.append(cutback)
                // current does not update — next progressive week resumes from here
            } else {
                let val: Double
                if progressIdx == 0 {
                    val = longStart
                } else if progressIdx == progressiveWeeks - 1 {
                    val = min(longPeak, current + 2.0)  // final: up to +2
                } else {
                    val = min(current + 1.0, longPeak)
                }
                buildLRs.append(val)
                current     = val
                progressIdx += 1
            }
        }

        let achievedPeak = buildLRs.filter { $0 > 0 }.max() ?? longPeak
        let taperLR      = max(longStart, (achievedPeak * 0.60).rounded(toPlaces: 0))
        let taperLRs: [Double] = taperWeeks == 3
            ? [taperLR, (achievedPeak * 0.45).rounded(toPlaces: 0), 0]
            : [taperLR, 0]

        return buildLRs + taperLRs
    }

    // MARK: - Cutback Detection

    static func isCutback(week: Int, total: Int, taperWeeks: Int) -> Bool {
        guard week <= total - taperWeeks else { return false }
        let buildWeeks = total - taperWeeks
        let offset     = 11 - buildWeeks   // FIXED: matches canonical11 (11 entries)
        let canonical  = week + offset
        return [3, 6, 9].contains(canonical)
    }

    // MARK: - Phase Info

    static func phaseInfo(week: Int, total: Int,
                           taperWeeks: Int) -> (TrainingPhase, String) {
        let isTap      = week > total - taperWeeks
        let buildWeeks = total - taperWeeks
        let firstThird = buildWeeks / 3
        let twoThirds  = (buildWeeks * 2) / 3

        if isTap              { return (.taper, "Taper — Almost There") }
        if week <= firstThird { return (.base,  "Getting Started")      }
        if week <= twoThirds  { return (.base,  "Building Confidence")  }
        return                        (.build, "Peak Training")
    }

    // MARK: - Week Builder
    //
    // 3 running days: long run + 2 easy
    // 2 cross-training days: any unassigned non-rest days
    // 2 rest days: from schedule.restDays

    static func buildWeek(
        weekNumber : Int,
        phase      : TrainingPhase,
        phaseLabel : String,
        total      : Double,
        longMiles  : Double,
        schedule   : UserSchedule,
        isCutback  : Bool,
        isTaper    : Bool,
        totalWeeks : Int,
        paces      : PaceEngine
    ) -> TrainingWeek {
        let lrDay   = schedule.longRunDay
        let runDay1 = schedule.workoutDay1
        let runDay2 = schedule.workoutDay2
        let rests   = Set(schedule.restDays)
        let runDays = Set([lrDay, runDay1, runDay2])
        let crossDays = Set(Weekday.allCases).subtracting(runDays).subtracting(rests)

        // RACE WEEK DETECTION:
        // When longMiles == 0 and we're in the taper, this is the race week.
        // Suppress all running so injectRaceDay is the sole contributor of miles:
        //   Saturday → shakeout (2 mi), Sunday → race (13.1 mi).
        // This prevents race week from appearing as the highest mileage week
        // on the chart for beginner runners with modest training volumes.
        let isRaceWeek = isTaper && longMiles <= 0

        if isRaceWeek {
            let days = Weekday.allCases.map { day in
                makeRest(day, isTaper: true)   // injectRaceDay overwrites Sat/Sun
            }
            return TrainingWeek(weekNumber: weekNumber, phase: phase,
                                phaseLabel: phaseLabel, days: days)
        }

        let longM       = min(max(longMiles, 3), peakLong)
        let cappedTotal = min(total, peakWeekly)
        let remain      = max(0, cappedTotal - longM)
        let easyPerRun  = (remain / 2.0).rounded(toPlaces: 1)

        var days: [TrainingDay] = []

        for day in Weekday.allCases {
            let td: TrainingDay
            if rests.contains(day) {
                td = makeRest(day, isTaper: isTaper)
            } else if day == lrDay {
                td = makeLongRun(day, miles: longM, weekNumber: weekNumber,
                                  totalWeeks: totalWeeks, isTaper: isTaper,
                                  isCutback: isCutback, paces: paces)
            } else if day == runDay1 {
                td = makeEasyRun(day, miles: easyPerRun, weekNumber: weekNumber,
                                  isTaper: isTaper, isCutback: isCutback,
                                  slot: .first, paces: paces)
            } else if day == runDay2 {
                td = makeEasyRun(day, miles: max(0, cappedTotal - longM - easyPerRun),
                                  weekNumber: weekNumber, isTaper: isTaper,
                                  isCutback: isCutback, slot: .second, paces: paces)
            } else if crossDays.contains(day) {
                td = makeCrossTrain(day, isTaper: isTaper)
            } else {
                td = makeRest(day, isTaper: isTaper)
            }
            days.append(td)
        }

        return TrainingWeek(weekNumber: weekNumber, phase: phase,
                            phaseLabel: phaseLabel, days: days)
    }

    enum EasySlot { case first, second }

    // MARK: - Day Makers

    static func makeRest(_ day: Weekday, isTaper: Bool) -> TrainingDay {
        let desc = isTaper
            ? "Rest day. You are in the final countdown. Rest is part of the plan — your body is storing energy for race day."
            : "Rest day. Recovery is where fitness actually improves. Your legs are rebuilding on rest days. Enjoy it."
        return TrainingDay(weekday: day, workoutType: .rest, miles: 0,
                           description: desc, paceNote: "—")
    }

    static func makeCrossTrain(_ day: Weekday, isTaper: Bool) -> TrainingDay {
        let descs: [String] = [
            "Cross-training day. 30–45 minutes of low-impact aerobic activity — cycling, swimming, elliptical, walking, or yoga. Keep the effort easy and enjoyable. This builds your cardiovascular base without the impact of running.",
            "Cross-training. Today is about moving your body without stressing your joints. Swim, bike, or use an elliptical for 30–45 minutes at comfortable effort. This is active recovery and aerobic development combined.",
            "Cross-training day. Any low-impact activity you enjoy counts — dancing, hiking, yoga, or an easy bike ride. The goal is 30–45 minutes of gentle movement. You do not need to work hard today.",
            "Cross-training. 30–45 minutes easy. This keeps your aerobic engine developing on the days between runs. Cycling and swimming are excellent choices — they build fitness with zero running impact."
        ]
        let taperDesc = "Cross-training during taper. Keep it short and gentle — 20–30 minutes maximum. Your goal is staying loose and energized, not building fitness."
        return TrainingDay(weekday: day, workoutType: .crossTrain, miles: 0,
                           description: isTaper ? taperDesc : descs[day.rawValue % descs.count],
                           paceNote: "Easy aerobic effort — 30–45 min")
    }

    static func makeEasyRun(_ day       : Weekday,
                              miles      : Double,
                              weekNumber : Int,
                              isTaper    : Bool,
                              isCutback  : Bool,
                              slot       : EasySlot,
                              paces      : PaceEngine) -> TrainingDay {
        let easyRange = paces.rangeString(paces.easy)
        // FIX: No max(2.0) floor. Budget math is the source of truth.
        // In peak weeks (10-mile long run, 12-mile week total), the remaining
        // 2 miles split into ~1-mile easy runs. That is correct — the long run
        // carried the week's stress. Inflating easy runs to 2.0 miles causes
        // 14-mile actual weeks against 12-mile scheduled targets, destroying
        // the chart's mileage accuracy and overstressing beginners at peak.
        let m = max(0.0, miles)

        let descs: [String]
        switch slot {
        case .first:
            descs = [
                "Easy run. The most important rule: you should be able to hold a full conversation the entire time. If you are breathing too hard to talk, slow down. This is not a fitness test — it is a habit-building run.",
                "Easy run. Keep it genuinely easy. Your body is still recovering from the weekend long run and building toward the next one. This run keeps the habit going without adding stress.",
                "Easy run. Go out, move your legs, come home feeling better than when you left. That is the entire goal today. Pace does not matter. Consistency does.",
                "Easy run. Running easy develops your aerobic system without the recovery cost of hard efforts. These runs are quietly making you fitter each week.",
                "Easy run. Showing up for this run — even on days when motivation is low — is what half marathon runners are made of. Keep it easy and keep it consistent."
            ]
        case .second:
            descs = [
                "Easy run. Your second run of the week. Same effort as Tuesday — fully conversational and comfortable. These mid-week miles are building the aerobic foundation your long run depends on.",
                "Easy run. Two easy runs per week plus the long run on the weekend — that rhythm is your training. Run comfortable and protect your legs for Saturday or Sunday.",
                "Easy run. Keep it easy. By the time you reach race day, these consistent mid-week runs will have quietly built more fitness than you realize.",
                "Easy run. No pace targets, no pressure. Just easy movement that keeps your body in a running rhythm between long run days.",
                "Easy run. Comfortable from start to finish. Walk hills if needed. Today is about building the habit and the aerobic base."
            ]
        }

        let desc = descs[weekNumber % descs.count]
        let note: String
        if isTaper        { note = "Easy — taper week, keep it relaxed" }
        else if isCutback { note = "Easy effort — lighter week by design" }
        else              { note = "\(easyRange) — fully conversational" }

        return TrainingDay(weekday: day, workoutType: m > 0 ? .easy : .rest,
                           miles: m, description: desc, paceNote: note)
    }

    static func makeLongRun(_ day       : Weekday,
                              miles      : Double,
                              weekNumber : Int,
                              totalWeeks : Int,
                              isTaper    : Bool,
                              isCutback  : Bool,
                              paces      : PaceEngine) -> TrainingDay {
        let easyRange   = paces.rangeString(paces.longRun)
        let weeksToRace = totalWeeks - weekNumber

        let desc: String
        switch (isTaper, isCutback, weeksToRace) {
        case (true, _, 1):
            desc = "Your final long run before race day. Run it easy and enjoy it — this is not a fitness session, it's a celebration of how far you've come. Run somewhere you like."
        case (true, _, _):
            desc = "Taper long run. Shorter than what you've been doing — and that's exactly right. Your fitness is built. These final runs keep you fresh and confident without adding new fatigue."
        case (false, true, _):
            desc = "Recovery week long run — intentionally shorter. Your body is absorbing the training from the past few weeks. This lighter run is not a step backward. It is the plan working."
        case (false, false, _) where miles <= 5:
            desc = "Long run day. This is the most important run of your week. Run at a pace where you could chat with a friend the whole way. Time on your feet matters more than speed right now."
        case (false, false, _) where miles <= 8:
            desc = "Long run. Start slower than feels right and hold that pace throughout. The second half of this run should feel the same as the first. If it gets harder, you went out too fast."
        default:
            desc = "Your longest run yet. Take a moment to appreciate that — this distance would have seemed impossible a few months ago. Run easy, run steady, and trust what you've built. You are becoming a half marathoner."
        }

        return TrainingDay(weekday: day, workoutType: .longRun, miles: miles,
                           description: desc,
                           paceNote: "\(easyRange) — fully conversational throughout")
    }
}
