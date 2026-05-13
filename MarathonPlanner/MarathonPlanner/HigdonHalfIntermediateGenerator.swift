import Foundation

// MARK: - Higdon Half Marathon Intermediate Generator
//
// TARGET RUNNER: Has completed a half marathon or has a solid running base.
// Wants a more structured plan with intentional workouts.
// Ready for tempo work but not an advanced racer.
//
// PHILOSOPHY: Higdon Intermediate bridges approachability and structure.
// The plan introduces threshold development — the most important training
// stimulus for half marathon performance — while preserving the confidence-
// building progression that makes Higdon plans accessible.
//
// STRUCTURE:
//   4–5 running days per week
//   1 cross-training day
//   1–2 rest days
//   Tempo run from week 3+ (midweek, Tuesday or Thursday)
//   Midweek longer run (Wednesday)
//   Long run (Sunday)
//   Easy runs filling remaining days
//   Long run peaks at 12 miles
//   Cutback every 3rd week
//   2-week taper
//
// COACHING VOICE:
//   Encouraging but more technical than Novice.
//   Explains WHY tempo matters for half marathons.
//   Builds confidence through understanding.

struct HigdonHalfIntermediateGenerator {

    // MARK: - Constants

    private static let peakWeekly  : Double = 35
    private static let peakLong    : Double = 12
    // Canonical week at which tempo work begins
    private static let tempoStart  : Int    = 3

    // MARK: - Entry Point

    static func generate(settings: UserSettings) -> [TrainingWeek] {
        let n          = settings.planLength.rawValue
        let taperWeeks = settings.taperDuration.rawValue
        let schedule   = settings.schedule.validated(for: .higdonHalfIntermediate)
        let paces      = PaceEngine(goalMinutes: settings.goalTimeMinutes,
                                     distance: 13.1)
        let mileage    = weeklyMileageSchedule(n: n, base: settings.baseMileage,
                                               taperWeeks: taperWeeks)
        let longRuns   = longRunSchedule(n: n, taperWeeks: taperWeeks,
                                          base: settings.baseMileage)

        var weeks: [TrainingWeek] = []
        for i in 0..<n {
            let wk        = i + 1
            let canonical = wk + (12 - n)
            let isTap     = wk > n - taperWeeks
            let isCut     = isCutback(week: wk, total: n, taperWeeks: taperWeeks)
            let hasTempo  = canonical >= tempoStart && !isTap
            let (phase, phaseLabel) = phaseInfo(week: wk, total: n, taperWeeks: taperWeeks)

            weeks.append(buildWeek(
                weekNumber: wk,
                canonical:  canonical,
                phase:      phase,
                phaseLabel: phaseLabel,
                total:      mileage[i],
                longMiles:  longRuns[i],
                schedule:   schedule,
                isCutback:  isCut,
                isTaper:    isTap,
                hasTempo:   hasTempo,
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

        // FIXED: Adaptive start. Old: min(max(base, 15), 22) capped high-base
        // runners at 22 mpw even if they ran 30+ mpw (regression) and floored
        // 0-mpw runners at 15 (jump too large). New: start near actual base,
        // floor at 15 (minimum for Intermediate's 4-5 day structure), cap near peak.
        let start = min(max(base + 2.0, 15.0),
                        peakWeekly * 0.85).rounded(toPlaces: 0)

        var result : [Double] = []
        var current             = start

        for i in 0..<buildWeeks {
            let wk = i + 1
            if isCutback(week: wk, total: n, taperWeeks: taperWeeks) {
                result.append(max(start, (current * 0.80).rounded(toPlaces: 0)))
                // current does not update on cutback weeks
            } else {
                let progress = buildWeeks > 1
                    ? Double(i) / Double(buildWeeks - 1) : 1.0
                let target = start + (peak - start) * progress
                let capped = min(target, current * 1.10)
                let val    = min(max(capped.rounded(toPlaces: 0), start), peak)
                result.append(val)
                current = val
            }
        }

        let achievedPeak = result.max() ?? Double(peak)

        // FIXED: Race week appended as 0 so isRaceWeek detection in buildWeek
        // suppresses all running — injectRaceDay then adds only shakeout + race.
        // Prevents race week becoming the highest mileage bar for lower-base runners.
        var taperMiles: [Double]
        if taperWeeks == 3 {
            taperMiles = [(achievedPeak * 0.70).rounded(toPlaces: 0),
                          (achievedPeak * 0.50).rounded(toPlaces: 0),
                          0]   // race week placeholder
        } else {
            taperMiles = [(achievedPeak * 0.62).rounded(toPlaces: 0),
                          0]   // race week placeholder
        }
        return result + taperMiles
    }

    // MARK: - Long Run Schedule

    static func longRunSchedule(n: Int, taperWeeks: Int, base: Double) -> [Double] {
        // Same architecture as HigdonHalfNovice: base-adaptive start, +1/week
        // progression, max +2 at the final progressive week to reach longPeak.
        // No progressive-to-progressive jump exceeds +2.
        // Cutback floor: max(4.0, ...) — higher minimum than Novice's 3.0.
        let buildWeeks = n - taperWeeks
        let longStart  = max(base * 0.40, 4.0).rounded(toPlaces: 0)
        let longPeak   = peakLong  // 12 miles

        let progressiveWeeks = (0..<buildWeeks).filter { i in
            !isCutback(week: i + 1, total: n, taperWeeks: taperWeeks)
        }.count

        var buildLRs   : [Double] = []
        var current     = longStart
        var progressIdx = 0

        for i in 0..<buildWeeks {
            let wk    = i + 1
            let isCut = isCutback(week: wk, total: n, taperWeeks: taperWeeks)

            if isCut {
                let cutback = max(4.0, current - 2.0)
                buildLRs.append(cutback)
            } else {
                let val: Double
                if progressIdx == 0 {
                    val = longStart
                } else if progressIdx == progressiveWeeks - 1 {
                    val = min(longPeak, current + 2.0)  // final: climactic peak push
                } else {
                    val = min(current + 1.0, longPeak)
                }
                buildLRs.append(val)
                current     = val
                progressIdx += 1
            }
        }

        let achievedPeak = buildLRs.filter { $0 > 0 }.max() ?? longPeak
        let taperLR      = max(longStart, (achievedPeak * 0.65).rounded(toPlaces: 0))
        let taperLRs: [Double] = taperWeeks == 3
            ? [taperLR, (achievedPeak * 0.50).rounded(toPlaces: 0), 0]
            : [taperLR, 0]

        return buildLRs + taperLRs
    }

    // MARK: - Cutback Detection

    static func isCutback(week: Int, total: Int, taperWeeks: Int) -> Bool {
        guard week <= total - taperWeeks else { return false }
        let buildWeeks = total - taperWeeks
        let offset     = 11 - buildWeeks  // FIXED: was 12 — made week 1 a cutback for 12-wk plans
        let canonical  = week + offset
        return [3, 6, 9].contains(canonical)
    }

    // MARK: - Phase Info

    static func phaseInfo(week: Int, total: Int,
                           taperWeeks: Int) -> (TrainingPhase, String) {
        let isTap      = week > total - taperWeeks
        let buildWeeks = total - taperWeeks
        let midPoint   = buildWeeks * 2 / 3

        if isTap            { return (.taper, "Taper")              }
        if week <= 2        { return (.base,  "Foundation")          }
        if week <= midPoint { return (.build, "Building Fitness")    }
        return                      (.build, "Race Preparation")
    }

    // MARK: - Week Builder

    static func buildWeek(
        weekNumber : Int,
        canonical  : Int,
        phase      : TrainingPhase,
        phaseLabel : String,
        total      : Double,
        longMiles  : Double,
        schedule   : UserSchedule,
        isCutback  : Bool,
        isTaper    : Bool,
        hasTempo   : Bool,
        totalWeeks : Int,
        paces      : PaceEngine
    ) -> TrainingWeek {
        let lrDay    = schedule.longRunDay
        let tempoDay = schedule.workoutDay1    // Tuesday — tempo when active, easy otherwise
        let mwDay    = schedule.midweekLongDay // Wednesday — midweek longer run
        let easyDay  = schedule.workoutDay2    // Thursday — easy
        let rests    = Set(schedule.restDays)
        let ctDay    = schedule.crossTrainDay

        // RACE WEEK DETECTION: same pattern as HigdonHalfNovice.
        // When longMiles=0 and in taper, suppress all running. injectRaceDay
        // contributes only shakeout (2 mi) + race (13.1 mi).
        let isRaceWeek = isTaper && longMiles <= 0
        if isRaceWeek {
            let days = Weekday.allCases.map { day in makeRest(day, isTaper: true) }
            return TrainingWeek(weekNumber: weekNumber, phase: phase,
                                phaseLabel: phaseLabel, days: days)
        }

        let longM       = min(max(longMiles, 4), peakLong)
        let cappedTotal = min(total, peakWeekly)

        // Allocate tempo/midweek miles within budget
        let tempoM  = hasTempo ? tempoMiles(canonical: canonical, weekMiles: cappedTotal,
                                             isTaper: isTaper) : 0.0
        let midLongM = midweekMiles(longMiles: longM, weekTotal: cappedTotal,
                                     isTaper: isTaper)
        let structured = longM + tempoM + midLongM
        let easyTotal  = max(0, cappedTotal - structured)
        // FIXED: Removed max(3.0) floor. Budget math is the source of truth.
        // Old floor caused actual weekly mileage to exceed scheduled targets in
        // peak weeks — destroying chart accuracy and overstressing runners.
        let easyPerDay: Double = easyTotal > 0
            ? (easyTotal / 2.0).rounded(toPlaces: 1) : 0.0

        var days: [TrainingDay] = []

        for day in Weekday.allCases {
            let td: TrainingDay
            if rests.contains(day) {
                td = makeRest(day, isTaper: isTaper)
            } else if let ct = ctDay, day == ct {
                td = makeCrossTrain(day, isTaper: isTaper)
            } else if day == lrDay {
                td = makeLongRun(day, miles: longM, weekNumber: weekNumber,
                                  totalWeeks: totalWeeks, isTaper: isTaper,
                                  isCutback: isCutback, paces: paces)
            } else if day == tempoDay {
                if hasTempo {
                    td = makeTempoRun(day, miles: tempoM, canonical: canonical,
                                       isTaper: isTaper, paces: paces)
                } else {
                    td = makeEasyRun(day, miles: easyPerDay, weekNumber: weekNumber,
                                      isTaper: isTaper, isCutback: isCutback, paces: paces)
                }
            } else if day == mwDay {
                td = makeMidweekRun(day, miles: midLongM, weekNumber: weekNumber,
                                     isTaper: isTaper, paces: paces)
            } else if day == easyDay {
                td = makeEasyRun(day, miles: easyPerDay, weekNumber: weekNumber,
                                  isTaper: isTaper, isCutback: isCutback, paces: paces)
            } else {
                td = makeRest(day, isTaper: isTaper)
            }
            days.append(td)
        }

        return TrainingWeek(weekNumber: weekNumber, phase: phase,
                            phaseLabel: phaseLabel, days: days)
    }

    // MARK: - Session Mileage

    private static func tempoMiles(canonical: Int, weekMiles: Double,
                                    isTaper: Bool) -> Double {
        // Taper: scale with week volume, no artificial floor.
        // Old: max(4.0, weekMiles*0.13) forced 4-mile tempo in light taper weeks.
        if isTaper { return (weekMiles * 0.15).rounded(toPlaces: 1) }
        let byCanonical: Double
        switch canonical {
        case 3...5:  byCanonical = 5.0
        case 6...8:  byCanonical = 6.0
        case 9...11: byCanonical = 7.0
        default:     byCanonical = 6.0
        }
        return min(byCanonical, weekMiles * 0.20).rounded(toPlaces: 1)
    }

    private static func midweekMiles(longMiles: Double, weekTotal: Double,
                                      isTaper: Bool) -> Double {
        // FIXED: Removed max(4.0) floor that caused mileage overshoot in early weeks.
        // Old: max(4.0, ...) forced 4+ miles even when the budget didn't support it.
        if isTaper { return max(3.0, (longMiles * 0.50).rounded(toPlaces: 1)) }
        return max(3.0, min(longMiles * 0.65, weekTotal * 0.25)).rounded(toPlaces: 1)
    }

    // MARK: - Day Makers

    static func makeRest(_ day: Weekday, isTaper: Bool) -> TrainingDay {
        let desc = isTaper
            ? "Rest day. Your body is converting training into race-day fitness. Stay off your feet and trust the process."
            : "Rest day. Recovery is when your body absorbs training. Rest days are not passive — they are when adaptation happens."
        return TrainingDay(weekday: day, workoutType: .rest, miles: 0,
                           description: desc, paceNote: "—")
    }

    static func makeCrossTrain(_ day: Weekday, isTaper: Bool) -> TrainingDay {
        let desc = isTaper
            ? "Cross-training — light and brief. 20 minutes of easy movement is enough. Stay loose and save energy for race day."
            : "Cross-training. 40–50 minutes of low-impact aerobic activity. Cycling, swimming, and elliptical are ideal — they build your cardiovascular fitness with less joint stress than running. This makes your running days more effective."
        return TrainingDay(weekday: day, workoutType: .crossTrain, miles: 0,
                           description: desc,
                           paceNote: "Comfortable aerobic effort — 40–50 min")
    }

    static func makeTempoRun(_ day      : Weekday,
                               miles    : Double,
                               canonical: Int,
                               isTaper  : Bool,
                               paces    : PaceEngine) -> TrainingDay {
        let tempoPace    = PaceEngine.format(paces.higdonTempo)
        let tempoSegment = max(2.0, miles - 2.5)
        let tapNote      = isTaper
            ? "Taper week — shorten the tempo to 2–3 miles at effort. Pace matters; duration reduces."
            : ""

        let phaseNote: String
        switch canonical {
        case 3...5:
            phaseNote = "You are in the early tempo phase. These sessions are developing the aerobic ceiling that will make half marathon pace feel more sustainable. Start conservatively — tempo running takes weeks to adapt to."
        case 6...9:
            phaseNote = "Mid-plan tempo work. This effort is close to what your half marathon will demand. The more comfortable this pace becomes in training, the more controlled you will feel on race day."
        default:
            phaseNote = "Late-plan tempo. This is the most race-specific work in your training. The effort you are building here is exactly what you will draw on in miles 8–13."
        }

        let desc = """
Tempo run: \(String(format: "%.0f", miles)) miles total.

Warmup 1 mile easy · \(String(format: "%.0f", tempoSegment)) miles at tempo effort · 1.5 miles cooldown easy.

\(tapNote.isEmpty ? "" : tapNote + "\n\n")Tempo effort means: noticeably harder than easy, but not racing. \
You can speak in short phrases but not full sentences. \
Breathing is deliberate and audible. This is the most important training pace for half marathon runners — \
the half marathon itself is run very close to this effort for many runners.

\(phaseNote)
"""
        return TrainingDay(weekday: day, workoutType: .tempoRun, miles: miles,
                           description: desc,
                           paceNote: "~\(tempoPace)/mi — comfortably hard, not racing")
    }

    static func makeMidweekRun(_ day       : Weekday,
                                miles      : Double,
                                weekNumber : Int,
                                isTaper    : Bool,
                                paces      : PaceEngine) -> TrainingDay {
        let easyRange = paces.rangeString(paces.easy)
        let descs: [String] = [
            "Midweek longer run. This run extends your aerobic endurance beyond your standard easy days. Keep the effort easy throughout — the purpose is aerobic volume, not speed. It should feel like an extended easy run.",
            "Midweek longer run. Running a moderate-length run mid-week builds the aerobic durability that makes your long run feel easier. Run at full conversation pace. If your legs feel tired from Tuesday, slow down.",
            "Midweek run — slightly longer than your other easy days. This is Higdon's way of increasing your weekly volume with low injury risk. Keep it fully comfortable and conversational.",
            "Midweek longer run. Think of this as a medium-effort aerobic day — longer than an easy run, shorter than the long run. It quietly builds fitness that will show up in your race."
        ]
        let tapDesc = "Midweek run during taper. Keep it easy and brief — 3–4 miles at comfortable effort. You are staying loose, not building fitness."

        return TrainingDay(weekday: day, workoutType: .midweekLong, miles: miles,
                           description: isTaper ? tapDesc : descs[weekNumber % descs.count],
                           paceNote: "\(easyRange) — easy aerobic, comfortable throughout")
    }

    static func makeEasyRun(_ day       : Weekday,
                              miles      : Double,
                              weekNumber : Int,
                              isTaper    : Bool,
                              isCutback  : Bool,
                              paces      : PaceEngine) -> TrainingDay {
        let easyRange = paces.rangeString(paces.easy)
        let m         = max(0.0, miles)  // FIXED: was max(3.0) — caused mileage overshoot in peak weeks
        let descs: [String] = [
            "Easy run. Fully conversational pace throughout. Easy running builds your aerobic base — the foundation everything else sits on. If your easy days feel too slow, they are probably at the right effort.",
            "Easy run. Keep it comfortable and steady. These runs connect the harder efforts and accumulate aerobic volume without costing you recovery.",
            "Easy run. The purpose of this run is habit and aerobic development, not speed. Run by feel and keep the effort where you could chat comfortably.",
            "Easy run. No pressure today. Just an easy, consistent effort that builds fitness week by week. The training adds up gradually — these runs are part of that.",
            "Easy run. Comfortable from start to finish. If you feel tempted to push, remind yourself the tempo run is what taxes you — this run is recovery and volume."
        ]
        let note = isTaper ? "Easy — relaxed taper pace" :
                   isCutback ? "Easy — lighter week" : easyRange

        return TrainingDay(weekday: day, workoutType: .easy, miles: m,
                           description: descs[weekNumber % descs.count], paceNote: note)
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
            desc = "Your last long run before race day. Run easy and enjoy every mile of it. Your fitness is already built. This run is about arriving at the start line with confidence and healthy legs."
        case (true, _, _):
            desc = "Taper long run. Intentionally shorter — that is the plan working correctly. Your peak fitness is already locked in. These final long runs maintain your aerobic rhythm without adding fatigue."
        case (false, true, _):
            desc = "Recovery week long run. The shorter distance is deliberate — your body is consolidating the training from recent weeks. Run easy and appreciate the lighter load. The longer runs return next week."
        case (false, false, _) where miles <= 7:
            desc = "Long run day. The cornerstone of your week. Run at a pace where you could hold a full conversation from start to finish. If you cannot, slow down. Time on your feet matters more than pace right now."
        case (false, false, _) where miles <= 10:
            desc = "Long run. Start conservatively — the first mile should feel almost too easy. Hold that same effort throughout. The goal is to finish feeling like you could have run a little more."
        default:
            desc = """
Your peak long run: \(Int(miles)) miles.

This is the most important run of your training. Start easy and stay easy. \
At this distance, the second half will ask more of you than the first — \
that aerobic demand is exactly what the half marathon will require, \
and handling it here builds the confidence you need on race day.

Run at \(easyRange) throughout. If you need walk breaks on hills, take them — \
finishing the distance matters more than running every step.
"""
        }

        return TrainingDay(weekday: day, workoutType: .longRun, miles: miles,
                           description: desc,
                           paceNote: "\(easyRange) — easy aerobic, fully conversational")
    }
}
