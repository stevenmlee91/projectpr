import Foundation

// MARK: - First Half Marathon Plan Generator
//
// TARGET RUNNER: Can jog 20–30 minutes continuously. First-time racer.
//
// PHILOSOPHY: Successful completion with confidence — NOT performance optimization.
//
// STRUCTURE:
//   - 3 running days per week (appropriate for true beginners)
//   - Peak 22 mpw (keeps mid-week easy runs at 5–6 miles, not 8)
//   - Long run peaks at 10 miles
//   - No threshold or interval work
//   - Cutbacks at canonical weeks 4, 8, 11
//   - 2-week or 3-week taper from settings.taperDuration
//   - Strides introduced at canonical week 11 (late build only)
//   - All intensity effort-based — no pace targets
//
// TAPER BEHAVIOR:
//   2-week: peak → 62% → 28%
//   3-week: peak → 78% → 58% → 28%
//
// MILEAGE ALIGNMENT:
//   longRunSchedule, weeklyMileageSchedule, isCutback, and phaseInfo
//   all use the same canonical offset (16 - planLength) so phase
//   boundaries and cutback weeks are always consistent regardless
//   of plan length or taper duration.

struct FirstHalfPlanGenerator {

    // MARK: - Constants

    private static let peakWeekly  : Double = 22
    private static let peakLong    : Double = 10
    // Strides introduced at this canonical week — about 2/3 through the plan.
    private static let stridesIntro: Int    = 11

    // MARK: - Entry Point

    static func generate(settings: UserSettings) -> [TrainingWeek] {
        let n          = settings.planLength.rawValue
        let taperWeeks = settings.taperDuration.rawValue      // 2 or 3
        let schedule   = settings.schedule.validated(for: .firstHalf)
        let mileage    = weeklyMileageSchedule(n: n,
                                               base:       settings.baseMileage,
                                               taperWeeks: taperWeeks)
        let longRuns   = longRunSchedule(n: n, taperWeeks: taperWeeks)

        var weeks: [TrainingWeek] = []
        for i in 0..<n {
            let wk       = i + 1
            let total    = mileage[i]
            let lr       = longRuns[i]
            let (phase, phaseLabel) = phaseInfo(week: wk, total: n,
                                                 taperWeeks: taperWeeks)
            let isCut    = isCutback(week: wk, total: n, taperWeeks: taperWeeks)
            let isTap    = wk > n - taperWeeks
            let canonical = wk + (16 - n)
            let useStrides = canonical >= stridesIntro && !isTap && !isCut

            weeks.append(buildWeek(
                weekNumber: wk,
                phase:      phase,
                phaseLabel: phaseLabel,
                total:      total,
                longMiles:  lr,
                schedule:   schedule,
                isCutback:  isCut,
                isTaper:    isTap,
                useStrides: useStrides,
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
    //
    // TAPER MILEAGE:
    //   2-week taper:   [62%, 28%]  of peak
    //   3-week taper:   [78%, 58%, 28%]  of peak
    //
    // BUILD MILEAGE:
    //   Linear progression from start toward peak, capped at 10%/week.
    //   Cutback weeks step back to 80% of current (not from peak).
    //   Floor: start value (prevents plan from going below entry mileage).

    static func weeklyMileageSchedule(n: Int,
                                       base: Double,
                                       taperWeeks: Int) -> [Double] {
        let peak  = peakWeekly
        // Beginner floor: 10 mpw (matches ~3×20-min jogs/week at 10 min/mi).
        // Previous version floored at 12, which was too high.
        let start = min(max(base, 10), 16).rounded(toPlaces: 0)

        var result  : [Double] = []
        var current             = start

        for i in 0..<n {
            let wk            = i + 1
            let taperPosition = wk - (n - taperWeeks)
            // taperPosition ≤ 0 → build phase
            // taperPosition  1 → first taper week
            // taperPosition  2 → second taper week (3-week only)
            // taperPosition  3 → race week (3-week) / 2 → race week (2-week)

            let val: Double

            if taperPosition > 0 {
                // Taper — explicit percentages per position
                switch (taperWeeks, taperPosition) {
                case (3, 1): val = (peak * 0.78).rounded(toPlaces: 0)
                case (3, 2): val = (peak * 0.58).rounded(toPlaces: 0)
                case (3, 3): val = (peak * 0.28).rounded(toPlaces: 0)
                case (2, 1): val = (peak * 0.62).rounded(toPlaces: 0)
                case (2, 2): val = (peak * 0.28).rounded(toPlaces: 0)
                default:     val = (peak * 0.28).rounded(toPlaces: 0)
                }
            } else if isCutback(week: wk, total: n, taperWeeks: taperWeeks) {
                // Cutback: 80% of current (not from peak — prevents excessive drops)
                val = max((current * 0.80).rounded(toPlaces: 0), start)
                // current stays unchanged — next week resumes from pre-cutback level
            } else {
                // Build: linear progression toward peak, capped at 10% per week
                let buildWeeks = max(1, n - taperWeeks - 1)
                let progress   = Double(i) / Double(buildWeeks)
                let target     = start + (peak - start) * progress
                let capped     = min(target, current * 1.10)
                val = min(max(capped.rounded(toPlaces: 0), start), peak)
                current = val
            }

            result.append(min(val, peakWeekly))
        }
        return result
    }

    // MARK: - Long Run Schedule
    //
    // DESIGN: Uses the same canonical offset (16 - planLength) as isCutback
    // and phaseInfo, ensuring cutback weeks in the long run sequence always
    // align with cutback weeks in the mileage schedule.
    //
    // CANONICAL BUILD SEQUENCE (14 entries, canonical weeks 1–14):
    //   [3, 4, 5, 4,   ← cutback at canonical 4
    //    5, 6, 7, 5,   ← cutback at canonical 8
    //    7, 8, 6,      ← cutback at canonical 11
    //    8, 9, 10]     ← peak
    //
    // For a plan of length n with taperWeeks t:
    //   offset     = 16 - n
    //   buildWeeks = n - t
    //   slice      = buildCanonical[offset ..< offset + buildWeeks]
    //
    // This guarantees that canonical week 8 (cutback long run = 5 miles) always
    // falls on the same actual week as the mileage cutback at canonical 8.
    //
    // TAPER LONG RUNS:
    //   2-week: [7, 0]     (pre-race 7mi, race day overwritten by injectRaceDay)
    //   3-week: [7, 5, 0]

    static func longRunSchedule(n: Int, taperWeeks: Int) -> [Double] {
        let buildCanonical: [Double] = [
            3, 4, 5, 4,    // canonical weeks  1–4   (4=cutback)
            5, 6, 7, 5,    // canonical weeks  5–8   (8=cutback)
            7, 8, 6,       // canonical weeks  9–11  (11=cutback)
            8, 9, 10       // canonical weeks 12–14  (peak)
        ]

        let taperLongRuns: [Double]
        switch taperWeeks {
        case 3: taperLongRuns = [7, 5, 0]
        default: taperLongRuns = [7, 0]
        }

        let offset     = 16 - n
        let buildWeeks = n - taperWeeks
        let startIdx   = offset
        let endIdx     = offset + buildWeeks

        let buildSlice: [Double]
        if startIdx >= buildCanonical.count || buildWeeks <= 0 {
            buildSlice = []
        } else {
            let safeEnd = min(endIdx, buildCanonical.count)
            buildSlice  = Array(buildCanonical[startIdx..<safeEnd])
                .map { min($0, peakLong) }
        }

        // Pad with entry-level miles if plan is longer than the canonical sequence
        let shortfall = buildWeeks - buildSlice.count
        let prefix    = shortfall > 0
            ? Array(repeating: 3.0, count: shortfall)
            : []

        return prefix + buildSlice + taperLongRuns
    }

    // MARK: - Cutback Detection
    //
    // Canonical cutback weeks: 4, 8, 11.
    // Guard: taper weeks are NEVER marked as cutbacks.
    // Guard: canonical week 0 or below (before plan starts) is ignored.

    static func isCutback(week: Int, total: Int, taperWeeks: Int) -> Bool {
        guard week <= total - taperWeeks else { return false }
        let canonical = week + (16 - total)
        guard canonical > 0 else { return false }
        return [4, 8, 11].contains(canonical)
    }

    // MARK: - Phase Info

    static func phaseInfo(week: Int,
                           total: Int,
                           taperWeeks: Int) -> (TrainingPhase, String) {
        let isTap  = week > total - taperWeeks
        let c      = week + (16 - total)

        if isTap   { return (.taper, "Taper — You've Done the Work") }
        if c <= 4  { return (.base,  "Getting Started")              }
        if c <= 11 { return (.base,  "Building Week by Week")        }
        return             (.build,  "Race Preparation")
    }

    // MARK: - Week Builder
    //
    // 3 genuine running days:
    //   lrDay   → Long Run
    //   runDay1 → Easy Run
    //   runDay2 → Easy Run (early weeks) or Easy + Strides (canonical week 11+)
    //
    // Remaining miles split evenly between the 2 mid-week running days.
    // Any day not in rests and not explicitly assigned → rest.

    static func buildWeek(
        weekNumber : Int,
        phase      : TrainingPhase,
        phaseLabel : String,
        total      : Double,
        longMiles  : Double,
        schedule   : UserSchedule,
        isCutback  : Bool,
        isTaper    : Bool,
        useStrides : Bool,
        totalWeeks : Int
    ) -> TrainingWeek {
        let lrDay   = schedule.longRunDay
        let runDay1 = schedule.workoutDay1
        let runDay2 = schedule.workoutDay2
        let rests   = schedule.restDays

        let runningDays: Set<Weekday> = [lrDay, runDay1, runDay2]

        let longM       = min(max(longMiles, 3), peakLong)
        let cappedTotal = min(total, peakWeekly)
        let remain      = max(0, cappedTotal - longM)

        // Split remaining miles between 2 mid-week runs.
        // At peak (22 mpw, 10-mile LR): remain=12, each run ~6 miles.
        let halfRemain = (remain / 2.0).rounded(toPlaces: 1)
        let restRemain = max(0, remain - halfRemain).rounded(toPlaces: 1)

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
            } else if day == runDay1 {
                td = makeEasyRun(day, miles: halfRemain,
                                 weekNumber: weekNumber,
                                 isCutback:  isCutback,
                                 isTaper:    isTaper,
                                 slot:       .first)
            } else if day == runDay2 {
                td = useStrides
                    ? makeStridesRun(day, miles: restRemain,
                                     weekNumber: weekNumber)
                    : makeEasyRun(day, miles: restRemain,
                                  weekNumber: weekNumber,
                                  isCutback:  isCutback,
                                  isTaper:    isTaper,
                                  slot:       .second)
            } else if runningDays.contains(day) {
                // Defensive — should not be reached
                td = makeEasyRun(day, miles: halfRemain,
                                 weekNumber: weekNumber,
                                 isCutback:  isCutback,
                                 isTaper:    isTaper,
                                 slot:       .first)
            } else {
                td = makeRest(day, isTaper: isTaper)
            }

            days.append(td)
        }

        return TrainingWeek(
            weekNumber: weekNumber,
            phase:      phase,
            phaseLabel: phaseLabel,
            days:       days
        )
    }

    // MARK: - Easy Run Slot
    // Two description pools so the two mid-week runs feel distinct.
    enum EasySlot { case first, second }

    // MARK: - Day Makers

    static func makeRest(_ day: Weekday,
                         isTaper: Bool) -> TrainingDay {
        let desc = isTaper
            ? "Rest day. This is the plan working, not the plan stopping. Your body is quietly building race-day readiness. Stay off your feet and trust the process."
            : "Rest day. This is where your body actually gets fitter — adaptation happens during recovery, not during the run. Enjoy it."
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
        case (true, _, 1):
            desc = "Your final run before the race. Keep it easy and short. You are not building fitness today — you are arriving healthy and confident. Run somewhere you enjoy."
        case (true, _, _):
            desc = "Taper long run. Shorter than what you have been doing, and that is exactly right. Your fitness is built. This run keeps your legs fresh and your rhythm intact."
        case (false, true, _):
            desc = "A lighter long run this week by design — a recovery week. Your body is absorbing everything from the previous weeks. Run easy and appreciate the shorter distance. This is not a step backward."
        case (false, false, _) where miles <= 5:
            desc = "Your long run for the week. At this stage, time on your feet matters far more than pace. Run at a pace where you could chat with a friend the entire way."
        case (false, false, _) where miles <= 7:
            desc = "Long run day. The most important run of your week. Start slower than feels natural — your body needs 10–15 minutes to settle in. Run the whole thing comfortably."
        case (false, false, _) where miles <= 9:
            desc = "Your longest run yet. This distance would have seemed impossible when you started. Take it easy for the first half, stay steady through the second. You are building the exact confidence race day requires."
        default:
            desc = "Your peak long run — the furthest you will run before race day. Run the first mile deliberately easy. This is not about proving fitness. It is about arriving at the finish knowing you have covered real distance on training legs."
        }

        let paceNote = miles <= 6
            ? "Fully conversational — no pace goal today"
            : "Easy and relaxed throughout — if you can't talk, slow down"

        return TrainingDay(weekday:     day,
                           workoutType: .longRun,
                           miles:       miles,
                           description: desc,
                           paceNote:    paceNote)
    }

    static func makeEasyRun(_ day       : Weekday,
                             miles      : Double,
                             weekNumber : Int,
                             isCutback  : Bool,
                             isTaper    : Bool,
                             slot       : EasySlot) -> TrainingDay {
        let descs: [String]
        switch slot {
        case .first:
            descs = [
                "Easy run. The definition of easy: you can speak in full sentences without pausing to breathe. If you're breathing hard, slow down. This pace is not too slow.",
                "Easy run today. Your body is still absorbing the weekend long run. The goal is gentle movement that keeps the habit going — not adding new stress.",
                "Easy run. Go out, run comfortably, come home feeling better than when you left. That is the entire job.",
                "Easy run. Pace is irrelevant today. Showing up and moving for the full distance is the only goal. These runs are quietly making you fitter.",
                "Easy run. The fitness you are building with these relaxed mid-week runs is real, even when it doesn't feel like much. Consistency is the training.",
                "Easy run. Think of this as active recovery — movement that helps your body bounce back without adding new fatigue."
            ]
        case .second:
            descs = [
                "Easy run. A second mid-week run to build your weekly foundation. Same effort as your first run this week — comfortable from start to finish.",
                "Easy run. Your second run this week. These mid-week miles are what separates someone who finishes a half marathon from someone who struggles. Keep it easy.",
                "Easy run. Two easy runs during the week plus a long run on the weekend — that rhythm is becoming your training routine. Keep it comfortable.",
                "Easy aerobic run. Run the full distance at a pace that feels effortless. These runs support your long run without replacing it.",
                "Easy run. Your legs will remember every easy mile you have banked. They don't need hard effort — they need consistency.",
                "Easy run. Comfortable from start to finish. Walk any hills if needed. Today is about time on feet, not effort."
            ]
        }

        let desc = descs[weekNumber % descs.count]
        let note: String
        if isTaper       { note = "Easy — keep it light, no need to push" }
        else if isCutback { note = "Easy effort — lighter week by design" }
        else              { note = "Conversational pace — you should be able to talk" }

        return TrainingDay(weekday:     day,
                           workoutType: .easy,
                           miles:       miles,
                           description: desc,
                           paceNote:    note)
    }

    // MARK: - Strides Run
    //
    // Introduced only at canonical week 11+ (late build phase).
    // Brief accelerations improve leg turnover without adding training stress.
    // Written in plain language — no jargon.

    static func makeStridesRun(_ day       : Weekday,
                                miles      : Double,
                                weekNumber : Int) -> TrainingDay {
        let descs: [String] = [
            "Easy run with strides. Run the main distance easy, then add 4 short pickups at the end: each about 20 seconds of running faster and lighter than your normal pace. Walk back to the start between each one. These are not sprints — think of them as running the way you will want to feel on race day.",
            "Easy run with strides. After your easy miles, add 4 short accelerations of 20 seconds each. Run them at a pace that feels quick but controlled — you should still be breathing smoothly. Full walk recovery between each one. These teach your legs to move efficiently.",
            "Easy run with optional strides. Run easy for the full distance. If your legs feel good at the end, add 4 × 20-second quick accelerations with full walk recovery. If you're tired, skip the strides and just run easy — the run itself is the priority.",
            "Easy run with strides. Main run easy, then 4 strides: 20 seconds of lighter, quicker running, walk back, repeat. These help your body remember what it feels like to run with good form and some rhythm. Don't force the pace — let the speed come naturally."
        ]
        let desc = descs[weekNumber % descs.count]

        return TrainingDay(weekday:     day,
                           workoutType: .strides,
                           miles:       miles,
                           description: desc,
                           paceNote:    "Easy run + 4 × 20-sec light accelerations — full walk recovery between each")
    }

    // MARK: - Validation (DEBUG only)

    #if DEBUG
    static func validate(weeks: [TrainingWeek],
                          planLength: Int,
                          taperWeeks: Int) {
        assert(weeks.count == planLength,
               "FirstHalf: week count \(weeks.count) ≠ planLength \(planLength)")

        let taperWeeksList = weeks.filter { $0.phase == .taper }
        assert(taperWeeksList.count == taperWeeks,
               "FirstHalf: expected \(taperWeeks) taper weeks, got \(taperWeeksList.count)")

        for week in weeks {
            let runDays = week.days.filter {
                $0.workoutType != .rest && $0.workoutType != .raceDay
            }
            assert(runDays.count >= 2 && runDays.count <= 4,
                   "FirstHalf week \(week.weekNumber): unexpected run day count \(runDays.count)")

            let longMiles = week.days
                .filter { $0.workoutType == .longRun }
                .map { $0.miles }.max() ?? 0
            assert(longMiles <= peakLong + 0.1,
                   "FirstHalf week \(week.weekNumber): long run \(longMiles) exceeds cap \(peakLong)")

            if week.phase != .race {
                assert(week.totalMiles <= peakWeekly + 1.0,
                       "FirstHalf week \(week.weekNumber): total \(week.totalMiles) exceeds peak \(peakWeekly)")
            }
        }

        // Verify no mileage spike > 15% between consecutive build weeks
        let buildWeeks = weeks.filter { $0.phase != .taper && $0.phase != .race }
        for i in 1..<buildWeeks.count {
            let prev = buildWeeks[i-1].totalMiles
            let curr = buildWeeks[i].totalMiles
            if curr > prev {
                assert(curr <= prev * 1.15 + 1.0,
                       "FirstHalf weeks \(buildWeeks[i-1].weekNumber)→\(buildWeeks[i].weekNumber): spike \(prev)→\(curr) mpw")
            }
        }
    }
    #endif
}
