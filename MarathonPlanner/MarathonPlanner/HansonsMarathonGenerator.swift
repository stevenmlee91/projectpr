import Foundation

// MARK: - Hansons Marathon Generator
//
// Authentic Hansons Marathon Method — with intelligent adaptive onboarding.
//
// COACHING PRINCIPLE:
//   Real coaching starts from where the runner IS, not where the methodology
//   eventually wants them to be. A 25 mpw runner does not open week 1 and
//   see 40 miles. They see a believable, challenging next step.
//
// ADAPTATION SYSTEM:
//   adaptiveStart = where the runner actually enters the plan
//   Derived from baseMileage, not from a methodology floor.
//   Quality session volumes scale with actual weekly mileage, not week number alone.
//   The Hansons philosophy (cumulative fatigue, 6 days, speed→strength) is preserved.
//   The entry point into that philosophy is personalized.
//
// WEEKLY STRUCTURE (always 6 running days):
//   Rest (Monday default) → Q1 Speed/Strength → Easy → Tempo → Easy → Long → Easy
//
// SPEED PHASE (canonical weeks 1-8): 400m–1200m intervals at 10K effort
// STRENGTH PHASE (canonical weeks 9+): 1–4 mile repeats at marathon pace

struct HansonsMarathonGenerator {

    // MARK: - Constants

    private static let peakWeekly    : Double = 55
    private static let longRunCap    : Double = 16
    private static let strengthStart : Int    = 9

    // MARK: - Quality Phase

    enum QualityPhase { case speed, strength }

    // MARK: - Speed Session Library

    struct SpeedSession {
        let reps      : Int
        let repDist   : String
        let recovDist : String
        let baseMiles : Double   // at full methodology volume
    }

    private static let speedSessions: [SpeedSession] = [
        SpeedSession(reps: 6,  repDist: "800m",  recovDist: "400m jog", baseMiles: 7.0),
        SpeedSession(reps: 10, repDist: "400m",  recovDist: "200m jog", baseMiles: 6.0),
        SpeedSession(reps: 5,  repDist: "1000m", recovDist: "400m jog", baseMiles: 7.5),
        SpeedSession(reps: 8,  repDist: "600m",  recovDist: "300m jog", baseMiles: 7.0),
        SpeedSession(reps: 6,  repDist: "1000m", recovDist: "400m jog", baseMiles: 8.0),
        SpeedSession(reps: 5,  repDist: "1200m", recovDist: "400m jog", baseMiles: 8.5),
        SpeedSession(reps: 8,  repDist: "800m",  recovDist: "400m jog", baseMiles: 9.0),
        SpeedSession(reps: 6,  repDist: "1000m", recovDist: "400m jog", baseMiles: 8.5),
    ]

    // MARK: - Strength Session Library

    struct StrengthSession {
        let reps        : Int
        let milesPerRep : Double
        let label       : String
        let baseMiles   : Double   // at full methodology volume
    }

    private static let strengthSessions: [StrengthSession] = [
        StrengthSession(reps: 6, milesPerRep: 1.0, label: "6×1mi",   baseMiles:  9.0),
        StrengthSession(reps: 2, milesPerRep: 3.0, label: "2×3mi",   baseMiles: 10.0),
        StrengthSession(reps: 4, milesPerRep: 1.5, label: "4×1.5mi", baseMiles:  9.5),
        StrengthSession(reps: 3, milesPerRep: 2.0, label: "3×2mi",   baseMiles: 10.0),
        StrengthSession(reps: 1, milesPerRep: 6.0, label: "1×6mi",   baseMiles: 10.0),
        StrengthSession(reps: 4, milesPerRep: 2.0, label: "4×2mi",   baseMiles: 12.0),
        StrengthSession(reps: 2, milesPerRep: 4.0, label: "2×4mi",   baseMiles: 12.0),
        StrengthSession(reps: 3, milesPerRep: 2.0, label: "3×2mi",   baseMiles: 10.0),
        StrengthSession(reps: 2, milesPerRep: 3.0, label: "2×3mi",   baseMiles: 10.0),
        StrengthSession(reps: 4, milesPerRep: 1.0, label: "4×1mi",   baseMiles:  7.0),
    ]

    // MARK: - Adaptive Quality Scale Factor
    //
    // Sessions scale with actual weekly mileage, not week number alone.
    // A runner at 28mpw gets a session appropriate for 28mpw.
    // A runner at 50mpw gets the full methodology session.
    // Floor of 0.60 ensures sessions remain meaningful even at low mileage.

    private static func qualityScale(weekMiles: Double) -> Double {
        return min(1.0, max(0.60, weekMiles / (peakWeekly * 0.85)))
    }

    // MARK: - Entry Point

    static func generate(settings: UserSettings) -> [TrainingWeek] {
        let n        = settings.planLength.rawValue
        let taperWks = settings.taperDuration.rawValue
        let schedule = settings.schedule.validated(for: .hansons)
        let paces    = PaceEngine(goalMinutes: settings.goalTimeMinutes)
        let mileage  = weeklyMileageSchedule(n: n, base: settings.baseMileage,
                                              taperWeeks: taperWks)
        let longRuns = longRunSchedule(n: n, taperWeeks: taperWks)

        var weeks: [TrainingWeek] = []
        for i in 0..<n {
            let wk        = i + 1
            let canonical = wk + (18 - n)
            let isTap     = wk > n - taperWks
            let qPhase: QualityPhase = canonical >= strengthStart ? .strength : .speed
            let (tPhase, phaseLabel) = phaseInfo(week: wk, total: n, taperWeeks: taperWks)

            weeks.append(buildWeek(
                weekNumber:   wk,
                canonical:    canonical,
                phase:        tPhase,
                phaseLabel:   phaseLabel,
                totalMiles:   mileage[i],
                longMiles:    longRuns[i],
                qualityPhase: qPhase,
                schedule:     schedule,
                isTaper:      isTap,
                totalWeeks:   n,
                paces:        paces
            ))
        }

        return PlanGenerator.injectRaceDay(into: weeks, schedule: schedule,
                                            raceType: .marathon)
    }

    // MARK: - Weekly Mileage Schedule
    //
    // ADAPTIVE ONBOARDING (the key fix):
    //   adaptiveStart = the runner's actual base + a small first-week bump.
    //   A 25 mpw runner starts at ~27 mpw, not at a 35 mpw methodology floor.
    //   A 45 mpw runner starts at ~47 mpw, close to peak territory.
    //
    //   Cap: never start above 70% of peak (40 mpw on a 55-peak plan).
    //   Floor: base + 2 miles (always a meaningful step forward).
    //
    // TAPER: Rhythm-preserving. Frequency stays high, volume reduces.
    //   2-week: 78% → 45%
    //   3-week: 85% → 72% → 45%

    static func weeklyMileageSchedule(n: Int, base: Double,
                                       taperWeeks: Int) -> [Double] {
        let peak = peakWeekly

        // Adaptive start — from where the runner is, not methodology minimum
        let adaptiveStart = min(
            max(base + 2.0, base * 1.08),   // small bump above current base
            peak * 0.70                      // never above 70% of peak in week 1
        ).rounded(toPlaces: 0)

        let taperPcts: [Double] = taperWeeks == 3
            ? [0.85, 0.72, 0.45]
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

            if [7, 10].contains(canonical) {
                // Cutback: 82% of current
                let cutback = max((current * 0.82).rounded(toPlaces: 0),
                                  adaptiveStart)
                result.append(cutback)
            } else {
                let buildWks = max(1, n - taperWeeks - 1)
                let progress = Double(i) / Double(buildWks)
                let target   = adaptiveStart + (peak - adaptiveStart) * progress
                let capped   = min(target, current * 1.08)   // 8% max ramp (conservative)
                let val      = min(max(capped.rounded(toPlaces: 0), adaptiveStart), peak)
                current = val
                result.append(val)
            }
        }
        return result
    }

    // MARK: - Long Run Schedule
    //
    // Three weeks at 16-mile peak — the Hansons cumulative fatigue signature.
    // Early long runs also scale gently from the runner's entry point.

    static func longRunSchedule(n: Int, taperWeeks: Int) -> [Double] {
        let canonical18: [Double] = [
            10, 11, 12, 10,
            12, 13, 11,
            14, 15, 12,
            16, 16, 16,
            16, 14, 12,
            10, 0
        ]
        let offset = 18 - n
        if offset > 0 {
            let trimmed = Array(canonical18.dropFirst(min(offset, canonical18.count)))
            return trimmed.prefix(n).map { min($0, longRunCap) }
        }
        return canonical18.prefix(n).map { min($0, longRunCap) }
    }

    // MARK: - Phase Info

    static func phaseInfo(week: Int, total: Int,
                           taperWeeks: Int) -> (TrainingPhase, String) {
        let isTap     = week > total - taperWeeks
        let canonical = week + (18 - total)

        if isTap                     { return (.taper, "Taper")          }
        if canonical < 4             { return (.base,  "Base Phase")     }
        if canonical < strengthStart { return (.build, "Speed Phase")    }
        return                         (.build, "Strength Phase")
    }

    // MARK: - Week Builder

    static func buildWeek(
        weekNumber   : Int,
        canonical    : Int,
        phase        : TrainingPhase,
        phaseLabel   : String,
        totalMiles   : Double,
        longMiles    : Double,
        qualityPhase : QualityPhase,
        schedule     : UserSchedule,
        isTaper      : Bool,
        totalWeeks   : Int,
        paces        : PaceEngine
    ) -> TrainingWeek {
        let restSet     = Set(schedule.restDays)
        let lrDay       = schedule.longRunDay
        let q1Day       = schedule.workoutDay1
        let q2Day       = schedule.workoutDay2
        let scale       = qualityScale(weekMiles: totalMiles)
        let taperFactor : Double = isTaper ? 0.75 : 1.0

        let longM   = min(max(longMiles, 6), longRunCap)
        let q1Total = q1Miles(canonical: canonical, phase: qualityPhase,
                               scale: scale * taperFactor)
        let q2Total = tempoMiles(canonical: canonical, weekMiles: totalMiles,
                                  isTaper: isTaper)
        let structured  = longM + q1Total + q2Total
        let easyTotal   = max(0, totalMiles - structured)
        let easyPerDay  = max(4.0, (easyTotal / 3.0).rounded(toPlaces: 1))

        var days: [TrainingDay] = []

        for day in Weekday.allCases {
            let td: TrainingDay

            if restSet.contains(day) {
                td = makeRest(day, isTaper: isTaper)
            } else if day == lrDay {
                td = makeLongRun(day, miles: longM, canonical: canonical,
                                 weekNumber: weekNumber, totalWeeks: totalWeeks,
                                 isTaper: isTaper, paces: paces)
            } else if day == q1Day {
                switch qualityPhase {
                case .speed:
                    td = makeSpeedWorkout(day, canonical: canonical,
                                          miles: q1Total, isTaper: isTaper,
                                          scale: scale, paces: paces)
                case .strength:
                    td = makeStrengthWorkout(day, canonical: canonical,
                                              miles: q1Total, isTaper: isTaper,
                                              scale: scale, paces: paces)
                }
            } else if day == q2Day {
                td = makeTempoRun(day, canonical: canonical, miles: q2Total,
                                   isTaper: isTaper, paces: paces)
            } else {
                td = makeEasyRun(day, miles: easyPerDay, weekNumber: weekNumber,
                                  isTaper: isTaper, paces: paces)
            }

            days.append(td)
        }

        return TrainingWeek(weekNumber: weekNumber, phase: phase,
                            phaseLabel: phaseLabel, days: days)
    }

    // MARK: - Session Mile Calculations (scale-aware)

    private static func q1Miles(canonical: Int, phase: QualityPhase,
                                  scale: Double) -> Double {
        let base: Double
        switch phase {
        case .speed:
            let idx = max(0, canonical - 1) % speedSessions.count
            base = speedSessions[idx].baseMiles
        case .strength:
            let idx = max(0, canonical - strengthStart) % strengthSessions.count
            base = strengthSessions[idx].baseMiles
        }
        return (base * scale).rounded(toPlaces: 1)
    }

    private static func tempoMiles(canonical: Int, weekMiles: Double,
                                    isTaper: Bool) -> Double {
        if isTaper { return max(5.0, weekMiles * 0.14) }
        // Tempo scales with both canonical progression AND actual weekly volume
        let byCanonical: Double
        switch canonical {
        case ..<6:    byCanonical = 7.0
        case 6...8:   byCanonical = 8.0
        case 9...12:  byCanonical = 9.0
        case 13...15: byCanonical = 10.0
        default:      byCanonical = 8.0
        }
        // Scale by weekly mileage — a runner at 28 mpw gets a smaller tempo
        // than one at 50 mpw, even in the same canonical week
        let byVolume = weekMiles * 0.17
        return min(byCanonical, max(byVolume, 5.0)).rounded(toPlaces: 1)
    }

    // MARK: - Day Makers

    static func makeRest(_ day: Weekday, isTaper: Bool) -> TrainingDay {
        let desc = isTaper
            ? "Rest day. Your one day off this week. Protect it — your legs need this before the final build to the start line."
            : "Rest day. One day off in a six-day week is Hansons' design. The cumulative fatigue that builds across the other six days is the training mechanism. This rest allows adaptation without undercutting the load."
        return TrainingDay(weekday: day, workoutType: .rest, miles: 0,
                           description: desc, paceNote: "—")
    }

    static func makeSpeedWorkout(_ day      : Weekday,
                                  canonical  : Int,
                                  miles      : Double,
                                  isTaper    : Bool,
                                  scale      : Double,
                                  paces      : PaceEngine) -> TrainingDay {
        let idx       = max(0, canonical - 1) % speedSessions.count
        let session   = speedSessions[idx]
        let speedPace = PaceEngine.format(paces.hansonsSpeed)

        // Scale the rep count for lower-volume runners
        let scaledReps = max(3, Int((Double(session.reps) * scale).rounded()))

        let onboardNote: String
        if scale < 0.80 {
            onboardNote = "\n\nNote: Session volume is adjusted for your current training base. As weekly mileage builds over the next few weeks, the sessions will progressively lengthen."
        } else {
            onboardNote = ""
        }

        let tapNote = isTaper ? " Taper week — shorten if legs feel heavy." : ""

        let desc = """
Speed workout: \(scaledReps)×\(session.repDist) at 10K effort, \(session.recovDist) recovery.

Warmup 1.5–2 miles easy. Run each rep at controlled speed — not a sprint, but genuinely fast. \
Splits should be even or slightly negative. If you are positive-splitting, you started too fast. \
Full recovery between reps. Cooldown 1.5 miles easy.\(tapNote)

You are developing running economy — the ability to run efficiently at paces faster than marathon \
pace. This transfers directly to a lower energy cost at race pace in the strength phase.\(onboardNote)
"""
        return TrainingDay(weekday: day, workoutType: .speedWork,
                           miles: miles,
                           description: desc,
                           paceNote: "~\(speedPace)/mi — 10K effort, consistent reps")
    }

    static func makeStrengthWorkout(_ day      : Weekday,
                                     canonical  : Int,
                                     miles      : Double,
                                     isTaper    : Bool,
                                     scale      : Double,
                                     paces      : PaceEngine) -> TrainingDay {
        let idx       = max(0, canonical - strengthStart) % strengthSessions.count
        let session   = strengthSessions[idx]
        let mpRange   = paces.rangeString(paces.hansonsStrength)

        // Scale rep count for lower-volume weeks
        let scaledReps = max(2, Int((Double(session.reps) * scale).rounded()))
        let scaledLabel = "\(scaledReps)×\(String(format: "%.1g", session.milesPerRep))mi"

        let onboardNote: String
        if scale < 0.80 {
            onboardNote = "\n\nNote: Session length is calibrated to your current training volume. The structure and intent are authentic Hansons — the volume grows with your weekly mileage."
        } else {
            onboardNote = ""
        }

        let tapNote = isTaper
            ? " Taper week — reduce to \(max(2, scaledReps - 1))×\(String(format: "%.1g", session.milesPerRep)) mile if legs feel heavy."
            : ""

        let desc = """
Strength workout: \(scaledLabel) at marathon pace, with recovery jog between reps.

Warmup 1 mile easy. Run each rep at exactly your goal marathon pace — not faster. \
Recovery jog 1–2 minutes between reps. Cooldown 1 mile easy.\(tapNote)

This is the defining Hansons workout. You are running race pace when you are not fully fresh — \
carrying this week's accumulated fatigue. That is intentional. Race day will be run on similar \
legs. Making marathon pace feel familiar under fatigue is the entire point. Resist the urge to \
go faster. Pace discipline here matters more than the training effect.\(onboardNote)
"""
        return TrainingDay(weekday: day, workoutType: .strengthMP,
                           miles: miles,
                           description: desc,
                           paceNote: "\(mpRange) — exact marathon goal pace")
    }

    static func makeTempoRun(_ day      : Weekday,
                               canonical  : Int,
                               miles      : Double,
                               isTaper    : Bool,
                               paces      : PaceEngine) -> TrainingDay {
        let tempoPace = PaceEngine.format(paces.pfitzLT)
        let tapNote   = isTaper ? "Taper tempo — run comfortably hard and keep the rest easy." : ""

        let desc = """
Tempo run: 1.5 mile warmup → \(String(format: "%.0f", max(0, miles - 3.0))) miles at threshold \
pace → 1.5 mile cooldown. Total approximately \(String(format: "%.0f", miles)) miles.

\(tapNote.isEmpty ? "" : tapNote + "\n\n")Threshold pace is faster than it sounds. This is not \
'comfortably hard' — it is sustained hard effort at a pace you could hold for roughly an hour. \
Breathing is deliberate. You can speak, but choose not to.

Run the warmup easy, lock in at threshold when the tempo section begins, and hold it through. \
Do not positive split. This workout builds the aerobic ceiling that marathon pace will sit beneath \
on race day.
"""
        return TrainingDay(weekday: day, workoutType: .tempoRun,
                           miles: miles,
                           description: desc,
                           paceNote: "~\(tempoPace)/mi — threshold effort, sustained")
    }

    static func makeEasyRun(_ day       : Weekday,
                              miles      : Double,
                              weekNumber : Int,
                              isTaper    : Bool,
                              paces      : PaceEngine) -> TrainingDay {
        let easyRange = paces.rangeString(paces.easy)
        let descs: [String] = [
            "Easy run. In Hansons training, these runs connect the quality sessions. They are not filler — they are what makes six days per week sustainable without breakdown.",
            "Easy run. Genuinely easy. If this pace feels embarrassingly slow, you are probably doing it correctly. The quality sessions are where you push. Here, you recover and accumulate aerobic volume.",
            "Easy run. The Hansons system derives its power from frequency, not heroic single sessions. This run is part of the daily accumulation that builds fatigue resistance over weeks.",
            "Easy run. Run this at a pace where you could hold a full conversation without effort. If you are breathing hard, you are running too fast. Save it for Tuesday and Thursday.",
            "Easy run. Six days per week is the strategy. This is one of three easy connective days — simple, consistent, and necessary.",
            "Easy run. In cumulative fatigue training, easy days matter as much as hard days. Running too fast here compromises the quality sessions."
        ]
        let desc = descs[weekNumber % descs.count]
        let note = isTaper ? "Easy — taper week, truly relaxed" : easyRange

        return TrainingDay(weekday: day, workoutType: .easy,
                           miles: miles, description: desc, paceNote: note)
    }

    static func makeLongRun(_ day        : Weekday,
                              miles       : Double,
                              canonical   : Int,
                              weekNumber  : Int,
                              totalWeeks  : Int,
                              isTaper     : Bool,
                              paces       : PaceEngine) -> TrainingDay {
        let easyRange   = paces.rangeString(paces.longRun)
        let weeksToRace = totalWeeks - weekNumber

        let desc: String
        switch (isTaper, weeksToRace) {
        case (true, 1):
            desc = "Final long run before the race. Run easy and enjoy it. Your fitness is built — this run maintains rhythm, not fitness."
        case (true, _):
            desc = "Taper long run. Shorter than your recent runs — that is by design. Your fitness is built and the taper is working even when it does not feel like it."
        case (false, _) where miles >= 16:
            desc = """
Long run: \(Int(miles)) miles at easy effort.

Run at a controlled, conversational pace throughout. The long run in Hansons is deliberately \
restrained — not because long runs are unimportant, but because you are running six days per \
week. Arriving at this run on accumulated fatigue is the point. Sixteen miles on tired legs \
prepares your body for the final miles of a marathon.

Do not race this run. The quality sessions earlier this week did the hard work. This run \
completes the weekly picture.
"""
        case (false, _) where miles >= 13:
            desc = """
Long run: \(Int(miles)) miles easy.

One of the longer runs in your Hansons cycle. Start conservatively — your legs carry the week's \
fatigue. That is intentional. Run in control from start to finish. This develops the fatigue \
resistance your marathon will demand.
"""
        default:
            desc = """
Long run: \(Int(miles)) miles easy.

Run at genuinely comfortable effort — well below your quality session intensity. In Hansons \
training, the long run is one of six runs, not the centerpiece. The training effect comes from \
the combination of all six sessions, not any single one.
"""
        }

        return TrainingDay(weekday: day, workoutType: .longRun,
                           miles: miles, description: desc,
                           paceNote: "\(easyRange) — easy, controlled, consistent")
    }
}
