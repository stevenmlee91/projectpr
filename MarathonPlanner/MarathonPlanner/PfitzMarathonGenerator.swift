import Foundation

// MARK: - Pfitz Marathon Generator
//
// Pete Pfitzinger's Advanced Marathoning — 18/55 — with adaptive onboarding.
//
// COACHING PRINCIPLE:
//   A 25 mpw runner does not open week 1 of a Pfitz plan and see 40 miles.
//   The aerobic density that defines Pfitz is built progressively.
//   The philosophy is preserved. The entry into the philosophy is personalized.
//
// ADAPTATION SYSTEM:
//   adaptiveStart = base + small first-week bump, capped at 68% of peak.
//   MLR volume scales with actual weekly mileage, not canonical week alone.
//   LT segment length scales with weekly mileage.
//   As mileage builds, sessions grow — the runner earns the full structure.
//
// THE DEFINING FEATURE — MEDIUM-LONG RUN:
//   Present EVERY week without exception. Never removed, only scaled.
//   At 28 mpw: MLR might be 9-10 miles. At 50 mpw: 15-16 miles.
//   The habit and intent are always there — the volume is proportional.

struct PfitzMarathonGenerator {

    // MARK: - Constants

    private static let peakWeekly       : Double = 55
    private static let longRunPeak      : Double = 22
    private static let raceSpecificStart: Int    = 13
    private static let ltPhaseStart     : Int    = 7

    // MARK: - Adaptive LT Workout
    //
    // LT miles at pace scale with actual weekly mileage.
    // A runner at 30 mpw gets 4 miles at LT. At 50 mpw: 7 miles.
    // This prevents a low-volume runner from attempting a 7-mile LT block
    // that represents 25% of their weekly total.

    private static func ltWorkout(canonical: Int, weekMiles: Double,
                                   isTaper: Bool) -> (total: Double, ltMiles: Double) {
        if isTaper {
            let ltM = max(3.0, weekMiles * 0.09)
            return (total: ltM + 4.0, ltMiles: ltM)
        }

        // Canonical progression — maximum LT miles at full methodology volume
        let canonicalLT: Double
        switch canonical {
        case ..<5:    canonicalLT = 4.0
        case 5...6:   canonicalLT = 5.0
        case 7...9:   canonicalLT = 5.0
        case 10...12: canonicalLT = 6.0
        case 13...15: canonicalLT = 7.0
        default:      canonicalLT = 5.0
        }

        // Scale by actual weekly mileage — LT should be ~11-13% of weekly total
        let volumeBasedLT = weekMiles * 0.12
        let ltM = min(canonicalLT, max(volumeBasedLT, 3.0)).rounded(toPlaces: 1)
        return (total: ltM + 4.0, ltMiles: ltM)
    }

    // MARK: - Adaptive Medium-Long Run
    //
    // Present EVERY week — this is the Pfitz non-negotiable.
    // But volume scales with actual weekly mileage.
    // At 28 mpw: MLR ≈ 9 miles (32% of weekly). At 50 mpw: 15 miles.
    // The runner always has the MLR habit. The distance is proportional.

    private static func mlrMiles(canonical: Int, weekMiles: Double,
                                  isTaper: Bool, taperWeeks: Int,
                                  taperPos: Int) -> Double {
        if isTaper {
            switch taperPos {
            case 1: return max(9.0, weekMiles * 0.28)
            case 2: return max(8.0, weekMiles * 0.24)
            default: return max(7.0, weekMiles * 0.20)
            }
        }

        // Canonical ceiling — what a full-mileage runner gets
        let canonicalMLR: Double
        switch canonical {
        case ..<5:    canonicalMLR = 11.0
        case 5...6:   canonicalMLR = 12.0
        case 7...9:   canonicalMLR = 13.0
        case 10...12: canonicalMLR = 15.0
        case 13...15: canonicalMLR = 16.0
        default:      canonicalMLR = 13.0
        }

        // Scale by actual weekly mileage — MLR ≈ 27-30% of weekly total
        let volumeMLR = weekMiles * 0.28
        return min(canonicalMLR, max(volumeMLR, 9.0)).rounded(toPlaces: 0)
    }

    // MARK: - MP Finish Sections (Phase 3 only)

    private static func mpFinishMiles(canonical: Int,
                                       weekMiles: Double) -> Int? {
        switch canonical {
        case 13:    return nil
        case 14:    return max(4, Int(weekMiles * 0.11))   // scales with volume
        case 15:    return max(5, Int(weekMiles * 0.14))
        case 16:    return max(6, Int(weekMiles * 0.17))
        case 17:    return nil
        default:    return nil
        }
    }

    // MARK: - Entry Point

    static func generate(settings: UserSettings) -> [TrainingWeek] {
        let n        = settings.planLength.rawValue
        let taperWks = settings.taperDuration.rawValue
        let schedule = settings.schedule.validated(for: .pfitz)
        let paces    = PaceEngine(goalMinutes: settings.goalTimeMinutes)
        let mileage  = weeklyMileageSchedule(n: n, base: settings.baseMileage,
                                              taperWeeks: taperWks)
        let longRuns = longRunSchedule(n: n, taperWeeks: taperWks)

        var weeks: [TrainingWeek] = []
        for i in 0..<n {
            let wk        = i + 1
            let canonical = wk + (18 - n)
            let isTap     = wk > n - taperWks
            let taperPos  = wk - (n - taperWks)
            let (tPhase, phaseLabel) = phaseInfo(week: wk, total: n,
                                                  taperWeeks: taperWks)

            weeks.append(buildWeek(
                weekNumber: wk,
                canonical:  canonical,
                phase:      tPhase,
                phaseLabel: phaseLabel,
                totalMiles: mileage[i],
                longMiles:  longRuns[i],
                schedule:   schedule,
                isTaper:    isTap,
                taperPos:   taperPos,
                taperWeeks: taperWks,
                totalWeeks: n,
                paces:      paces
            ))
        }

        return PlanGenerator.injectRaceDay(into: weeks, schedule: schedule,
                                            raceType: .marathon)
    }

    // MARK: - Weekly Mileage Schedule
    //
    // ADAPTIVE ONBOARDING:
    //   adaptiveStart derived from base, not from a 40-mile methodology floor.
    //   A 25 mpw runner enters at ~27 mpw. A 48 mpw runner at ~51 mpw.
    //   Cap: 68% of peak (37 mpw on a 55-peak plan).
    //   Ramp: 9% max per week (Pfitz is dense — conservative ramp protects).

    static func weeklyMileageSchedule(n: Int, base: Double,
                                       taperWeeks: Int) -> [Double] {
        let peak = peakWeekly

        // Adaptive start — from where the runner actually is
        let adaptiveStart = min(
            max(base + 2.0, base * 1.08),
            peak * 0.68
        ).rounded(toPlaces: 0)

        let taperPcts: [Double] = taperWeeks == 3
            ? [0.85, 0.70, 0.45]
            : [0.78, 0.45]

        var result : [Double] = []
        var current             = adaptiveStart

        for i in 0..<n {
            let wk        = i + 1
            let taperPos  = wk - (n - taperWeeks)
            let canonical = wk + (18 - n)

            if taperPos > 0 {
                let pct = taperPcts[min(taperPos - 1, taperPcts.count - 1)]
                result.append((peak * pct).rounded(toPlaces: 0))
                continue
            }

            if [6, 11].contains(canonical) {
                let cutback = max((current * 0.85).rounded(toPlaces: 0),
                                  adaptiveStart)
                result.append(cutback)
            } else {
                let buildWks = max(1, n - taperWeeks - 1)
                let progress = Double(i) / Double(buildWks)
                let target   = adaptiveStart + (peak - adaptiveStart) * progress
                let capped   = min(target, current * 1.09)   // 9% max ramp
                let val      = min(max(capped.rounded(toPlaces: 0), adaptiveStart), peak)
                current = val
                result.append(val)
            }
        }
        return result
    }

    // MARK: - Long Run Schedule

    static func longRunSchedule(n: Int, taperWeeks: Int) -> [Double] {
        let canonical18: [Double] = [
            16, 17, 17, 18,
            18, 15,
            18, 19, 20, 20,
            17,
            20, 22, 22,
            22, 18,
            15, 0
        ]
        let offset = 18 - n
        if offset > 0 {
            let trimmed = Array(canonical18.dropFirst(min(offset, canonical18.count)))
            return trimmed.prefix(n).map { min($0, longRunPeak) }
        }
        return canonical18.prefix(n).map { min($0, longRunPeak) }
    }

    // MARK: - Phase Info

    static func phaseInfo(week: Int, total: Int,
                           taperWeeks: Int) -> (TrainingPhase, String) {
        let isTap     = week > total - taperWeeks
        let canonical = week + (18 - total)

        if isTap                         { return (.taper, "Taper")                   }
        if canonical < ltPhaseStart      { return (.base,  "Endurance Phase")         }
        if canonical < raceSpecificStart { return (.build, "Lactate Threshold Phase") }
        return                             (.build, "Race-Specific Phase")
    }

    // MARK: - Week Builder

    static func buildWeek(
        weekNumber : Int,
        canonical  : Int,
        phase      : TrainingPhase,
        phaseLabel : String,
        totalMiles : Double,
        longMiles  : Double,
        schedule   : UserSchedule,
        isTaper    : Bool,
        taperPos   : Int,
        taperWeeks : Int,
        totalWeeks : Int,
        paces      : PaceEngine
    ) -> TrainingWeek {
        let restSet  = Set(schedule.restDays)
        let lrDay    = schedule.longRunDay
        let ltDay    = schedule.workoutDay1
        let mlrDay   = schedule.midweekLongDay

        let longM = min(max(longMiles, 10), longRunPeak)
        let (ltTotal, ltMilesAtPace) = ltWorkout(canonical: canonical,
                                                   weekMiles: totalMiles,
                                                   isTaper: isTaper)
        let mlrM = mlrMiles(canonical: canonical, weekMiles: totalMiles,
                             isTaper: isTaper, taperWeeks: taperWeeks,
                             taperPos: taperPos)
        let mpSection = isTaper ? nil : mpFinishMiles(canonical: canonical,
                                                       weekMiles: totalMiles)

        let structured  = longM + ltTotal + mlrM
        let recovTotal  = max(0, totalMiles - structured)
        let recovPerDay = max(5.0, (recovTotal / 2.0).rounded(toPlaces: 1))

        var days: [TrainingDay] = []

        for day in Weekday.allCases {
            let td: TrainingDay

            if restSet.contains(day) {
                td = makeRest(day, isTaper: isTaper)
            } else if day == lrDay {
                if let mpMiles = mpSection {
                    td = makeLongRunWithMP(day, longMiles: longM, mpMiles: mpMiles,
                                           weekNumber: weekNumber,
                                           totalWeeks: totalWeeks, paces: paces)
                } else {
                    td = makeLongRun(day, miles: longM, canonical: canonical,
                                     weekNumber: weekNumber, totalWeeks: totalWeeks,
                                     isTaper: isTaper, paces: paces)
                }
            } else if day == ltDay {
                td = makeLTRun(day, totalMiles: ltTotal, ltMiles: ltMilesAtPace,
                                canonical: canonical, weekMiles: totalMiles,
                                isTaper: isTaper, paces: paces)
            } else if day == mlrDay {
                td = makeMediumLongRun(day, miles: mlrM, canonical: canonical,
                                        weekNumber: weekNumber, weekMiles: totalMiles,
                                        isTaper: isTaper, paces: paces)
            } else {
                td = makeRecoveryRun(day, miles: recovPerDay, weekNumber: weekNumber,
                                     isTaper: isTaper, paces: paces)
            }

            days.append(td)
        }

        return TrainingWeek(weekNumber: weekNumber, phase: phase,
                            phaseLabel: phaseLabel, days: days)
    }

    // MARK: - Day Makers

    static func makeRest(_ day: Weekday, isTaper: Bool) -> TrainingDay {
        let desc = isTaper
            ? "Rest day. You are in the taper. The adaptations from months of training are consolidating. This rest is part of the preparation, not a pause in it."
            : "Rest day. After the aerobic load of the LT session, medium-long run, and long run, this rest allows genuine recovery. Your body synthesizes the adaptations here."
        return TrainingDay(weekday: day, workoutType: .rest, miles: 0,
                           description: desc, paceNote: "—")
    }

    static func makeLTRun(_ day       : Weekday,
                           totalMiles : Double,
                           ltMiles    : Double,
                           canonical  : Int,
                           weekMiles  : Double,
                           isTaper    : Bool,
                           paces      : PaceEngine) -> TrainingDay {
        let ltPace = PaceEngine.format(paces.pfitzLT)
        let ltHigh = PaceEngine.format(paces.pfitzLT - 10)
        let ltLow  = PaceEngine.format(paces.pfitzLT + 10)

        let tapNote = isTaper ? "\n\nTaper week — run the LT section at effort, not a specific pace. Your freshening legs may want to go faster. Resist." : ""

        let volumeNote: String
        if weekMiles < peakWeekly * 0.70 {
            volumeNote = "\n\nLT session length is calibrated to your current weekly volume. As your mileage builds, the LT segment will progressively lengthen."
        } else {
            volumeNote = ""
        }

        let phaseContext: String
        switch canonical {
        case ..<7:
            phaseContext = "In the endurance phase, LT work establishes the aerobic ceiling your marathon pace will sit beneath. These sessions are foundational — not your hardest workouts yet."
        case 7...12:
            phaseContext = "LT development is the primary physiological focus of this phase. Each session raises the pace you can sustain for extended periods — which directly translates to what you can hold for 26.2 miles."
        default:
            phaseContext = "In the race-specific phase, LT work maintains aerobic sharpness alongside the marathon-pace long runs."
        }

        let desc = """
Lactate threshold run: \(String(format: "%.0f", totalMiles)) miles with \(String(format: "%.0f", ltMiles)) miles at LT pace.

Warmup ~2 miles easy. LT section: \(String(format: "%.0f", ltMiles)) miles at \(ltHigh)–\(ltLow)/mi. \
Cooldown ~2 miles easy.\(tapNote)

LT pace sits at the boundary of your aerobic and anaerobic systems — roughly your 25K to 30K \
race pace. Sustaining this pace trains your body to clear lactate more effectively, raising the \
pace you can hold aerobically.

\(phaseContext)

The effort should feel controlled and hard — breathing is purposeful and rapid, but you are not \
at the edge of your capacity.\(volumeNote)
"""
        return TrainingDay(weekday: day, workoutType: .lactateThreshold,
                           miles: totalMiles, description: desc,
                           paceNote: "~\(ltPace)/mi for the LT section — 25K–30K race effort")
    }

    static func makeMediumLongRun(_ day       : Weekday,
                                   miles      : Double,
                                   canonical  : Int,
                                   weekNumber : Int,
                                   weekMiles  : Double,
                                   isTaper    : Bool,
                                   paces      : PaceEngine) -> TrainingDay {
        let gaRange = paces.rangeString(paces.generalAero)

        let volumeNote: String
        if weekMiles < peakWeekly * 0.70 {
            volumeNote = "\n\nThe medium-long run is scaled to your current weekly volume — it will grow as your training base develops. The habit and intent are always present. The distance is proportional to where you are."
        } else {
            volumeNote = ""
        }

        let descs: [String] = [
            """
Medium-long run: \(Int(miles)) miles at general aerobic effort.

The medium-long run is the defining feature of Pfitz training — a second major aerobic stimulus \
every single week without exception. Combined with your long run, it creates aerobic density that \
plans at similar mileage on fewer days cannot replicate.

Run at \(gaRange). Comfortably aerobic throughout — not easy, not hard.\(volumeNote)
""",
            """
Medium-long run: \(Int(miles)) miles general aerobic.

Every Pfitz week contains this run. Not most weeks — every week. The LT session builds your \
aerobic ceiling. The long run builds outer-edge endurance. The medium-long run fills the space \
between them, creating depth that makes the difference in the final 10K.

Run at \(gaRange). Comfortably aerobic.\(volumeNote)
""",
            """
Medium-long run: \(Int(miles)) miles.

The second major aerobic stimulus of your week. Your long run will be run on legs that have \
already done this. That combination across a short window is the Pfitz mechanism.

General aerobic effort — \(gaRange). Not a recovery jog. Not a workout. Sustained aerobic \
development at medium intensity.\(volumeNote)
""",
            """
Medium-long run: \(Int(miles)) miles at general aerobic effort.

Most plans have one major aerobic event per week: the long run. Pfitz has two. This is why \
Pfitz runners at 55 miles per week often outperform runners at 60 miles on other plans — the \
aerobic density matters as much as the total volume.

Effort: \(gaRange). Honest work — not a struggle, not a stroll.\(volumeNote)
"""
        ]

        let desc = isTaper
            ? "Medium-long run: \(Int(miles)) miles during taper. Shorter than your recent MLRs — but still present. The medium-long run never disappears in Pfitz, it reduces. Run at general aerobic effort, controlled and steady."
            : descs[weekNumber % descs.count]

        return TrainingDay(weekday: day, workoutType: .mediumLong,
                           miles: miles, description: desc,
                           paceNote: "\(gaRange) — general aerobic, comfortably sustained")
    }

    static func makeLongRun(_ day       : Weekday,
                             miles      : Double,
                             canonical  : Int,
                             weekNumber : Int,
                             totalWeeks : Int,
                             isTaper    : Bool,
                             paces      : PaceEngine) -> TrainingDay {
        let lrRange     = paces.rangeString(paces.longRun)
        let weeksToRace = totalWeeks - weekNumber

        let desc: String
        switch (isTaper, weeksToRace) {
        case (true, 1):
            desc = "Final long run before the race. Run easy and enjoy it. Your fitness is built. This run maintains rhythm and neuromuscular freshness."
        case (true, _):
            desc = "Taper long run. Shorter, easier, and that is correct. The aerobic work is done. These taper runs maintain rhythm while your body consolidates months of adaptation."
        case (false, _) where canonical == 11:
            desc = """
Long run: \(Int(miles)) miles — recovery week.

A planned reduction in the long run. You have been building consistently — this lighter long run \
allows adaptation to catch up. Run easy at \(lrRange). Do not treat this as an opportunity to \
push. The following weeks will be your longest of the cycle.
"""
        case (false, _) where miles >= 20:
            desc = """
Long run: \(Int(miles)) miles at easy aerobic effort.

Start conservatively — the first 8 miles should feel almost too easy. As the run progresses, \
your pace may naturally drift slightly. Let it, as long as you remain aerobic.

The medium-long run earlier this week means you are running this on legs that have already done \
meaningful aerobic work. That combination is the Pfitz engine.

Run at \(lrRange).
"""
        default:
            desc = """
Long run: \(Int(miles)) miles easy.

Run at \(lrRange) — genuinely aerobic throughout. This run and the medium-long run are Pfitz's \
dual-aerobic framework: two major stimuli per week developing the endurance to sustain effort \
late in a race.
"""
        }

        return TrainingDay(weekday: day, workoutType: .longRun,
                           miles: miles, description: desc,
                           paceNote: "\(lrRange) — easy aerobic throughout")
    }

    static func makeLongRunWithMP(_ day       : Weekday,
                                   longMiles  : Double,
                                   mpMiles    : Int,
                                   weekNumber : Int,
                                   totalWeeks : Int,
                                   paces      : PaceEngine) -> TrainingDay {
        let mpPace    = PaceEngine.format(paces.MP)
        let lrRange   = paces.rangeString(paces.longRun)
        let easyMiles = Int(longMiles) - mpMiles

        let desc = """
Long run with marathon pace finish: \(Int(longMiles)) miles — first \(easyMiles) miles easy, \
final \(mpMiles) miles at marathon pace.

First \(easyMiles) miles: \(lrRange). Deliberately easy. Build aerobic momentum without \
accumulating fatigue.

Final \(mpMiles) miles: \(mpPace)/mi — your goal marathon pace. Not faster, not slower. This \
section teaches your body what marathon effort feels like when you are genuinely tired, which \
is exactly what the second half of the race will demand.

If the marathon pace section feels very hard today, that is valuable information. If it feels \
controlled, your fitness is where it needs to be.
"""
        return TrainingDay(weekday: day, workoutType: .longRunWithMP,
                           miles: longMiles, description: desc,
                           paceNote: "Easy \(easyMiles) mi → \(mpPace)/mi final \(mpMiles) mi")
    }

    static func makeRecoveryRun(_ day       : Weekday,
                                 miles      : Double,
                                 weekNumber : Int,
                                 isTaper    : Bool,
                                 paces      : PaceEngine) -> TrainingDay {
        let recovPace = PaceEngine.format(paces.recovery)
        let descs: [String] = [
            "Recovery run. Genuinely easy — slower than your easy pace. After the aerobic load of this week's LT session, medium-long run, and long run, your job today is active recovery. Move the blood, flush the legs, add nothing new to your fatigue account.",
            "Recovery run. The cardiovascular system recovers faster than the muscles and connective tissue. Your perceived effort will underestimate how much recovery your legs still need. Run slower than feels necessary.",
            "Recovery run. These slow miles serve a specific purpose: enhanced blood flow and glycogen replenishment without triggering a new training stimulus. Run easy enough that your heart rate stays genuinely low.",
            "Recovery run. In Pfitz training, recovery runs are not easy runs — they are specifically slow to serve the physiological purpose of accelerating recovery without adding training stress."
        ]
        let desc = descs[weekNumber % descs.count]
        let note = isTaper ? "Taper recovery — extra easy, just keep the legs moving"
                           : "~\(recovPace)/mi — recovery effort, genuinely slow"

        return TrainingDay(weekday: day, workoutType: .recovery,
                           miles: miles, description: desc, paceNote: note)
    }
}
