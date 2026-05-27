import Foundation

// MARK: - Higdon Intermediate Marathon Generator
//
// Authentic Hal Higdon Intermediate philosophy:
// - 5 runs per week (Monday easy added vs. Novice's 4) + cross-training
// - Tempo runs introduced at canonical week 3, progressive canonical table
// - Mid-week medium long run (longer than Novice's)
// - Cutback every 3 weeks
// - 3-week taper
// - Peak ~48 mpw, long run peaks at 22 miles
// - Tone: structured but still approachable
//
// Key differentiators from Novice:
//   1. Monday easy run (5th running day — was rest in Novice)
//   2. Canonical tempo progression (3 → 8 miles) with warmup/cooldown
//   3. 22-mile long run peak (vs. 20)
//   4. Higher weekly totals (48 vs 40 mpw)

struct HigdonIntermediateGenerator {

    // MARK: - Hard Caps
    private static let peakWeekly : Double = 48
    private static let peakLong   : Double = 22

    // MARK: - Canonical Tempo Table
    //
    // FIX 1: Replaces the broken `weekNumber / 3` integer formula.
    //
    // Old code: `let tempoMiles = max(2, min(6, canonical / 3))`
    //   - Used weekNumber as "canonical" (wrong for shorter plans)
    //   - Used integer division (3/3=1, 4/3=1, 5/3=1 — all equal)
    //   - Ignored the `miles` parameter passed from buildWeek entirely
    //   - `TrainingDay.miles` was disconnected from budget allocation
    //
    // New: direct canonical week → segment distance lookup, matching Higdon
    // Intermediate 1 book structure. warmup(1mi) + segment + cooldown(1mi) is
    // the stored mileage. Same source of truth for budget and day maker.
    //
    // Only non-cutback, non-taper canonical weeks are included because
    // useTempo = canonical >= 3 && !isCutback && !isTaper.
    // Canonical 4, 8, 12 are cutbacks — not in this table. Taper weeks never use tempo.

    private static let tempoWarmup  : Double = 1.0
    private static let tempoCooldown: Double = 1.0

    private static let tempoSegByCanonical: [Int: Double] = [
        3: 3.0,   // week 3:  3mi tempo
        5: 4.0,   // week 5:  4mi tempo
        6: 5.0,   // week 6:  5mi
        7: 5.0,   // week 7:  5mi
        9: 5.0,   // week 9:  5mi
        10: 6.0,  // week 10: 6mi
        11: 6.0,  // week 11: 6mi
        13: 6.0,  // week 13: 6mi
        14: 7.0,  // week 14: 7mi
        15: 8.0,  // week 15: 8mi (peak)
    ]

    /// Total miles for a tempo session at a given canonical week.
    /// This is the single source of truth — called by both budget allocation
    /// in buildWeek and mileage storage in makeTempo.
    private static func canonicalTempoMiles(canonical: Int) -> Double {
        let seg = tempoSegByCanonical[canonical] ?? 3.0
        return (tempoWarmup + seg + tempoCooldown).rounded(toPlaces: 1)
    }

    // MARK: - Entry Point

    static func generate(settings: UserSettings) -> [TrainingWeek] {
        let n        = settings.planLength.rawValue
        let schedule = settings.schedule.validated(for: .higdonIntermediate)
        let mileage  = weeklyMileageSchedule(n: n, base: settings.baseMileage)
        // FIX 2: Adaptive long run cap — same principle as Novice.
        // Shorter plans start the canonical LR schedule mid-sequence.
        // A 12-week plan begins at canonical week 7 (LR=15mi) against a base
        // runner's week 1 total of ~20mi (75% long run). The 50% cap prevents this.
        let longRuns = longRunScheduleAdapted(n: n, weeklyMiles: mileage)

        var weeks: [TrainingWeek] = []
        for i in 0..<n {
            let wk        = i + 1
            let total     = mileage[i]
            let lr        = longRuns[i]
            let (phase, phaseLabel) = phaseInfo(week: wk, total: n)
            let isCut     = isCutback(week: wk, total: n)
            let isTap     = wk > n - 3
            let offset    = 18 - n
            let canonical = wk + offset
            let useTempo  = canonical >= 3 && !isTap && !isCut

            weeks.append(buildWeek(
                weekNumber: wk,
                canonical:  canonical,
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

    static func weeklyMileageSchedule(n: Int, base: Double) -> [Double] {
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

    // MARK: - Long Run Progression (canonical)

    static func longRunSchedule(n: Int) -> [Double] {
        let canonical18: [Double] = [
            8,  10, 12, 10,
            12, 13, 15, 12,
            15, 17, 18, 14,
            20, 16, 22,
            14,
            8,
            0   // race week sentinel
        ]

        let clamped = canonical18.map { min($0, peakLong) }

        if n == 18 { return clamped }
        if n < 18  { return Array(clamped.dropFirst(18 - n)) }
        let extra = Array(repeating: 8.0, count: n - 18)
        return extra + clamped
    }

    // MARK: - Long Run Progression (adapted)
    //
    // FIX 2: Caps canonical LR at 50% of the corresponding weekly total.
    // Race week (LR=0) is preserved by guarding lr > 0.
    // See HigdonNoviceGenerator.longRunScheduleAdapted for full rationale.

    static func longRunScheduleAdapted(n: Int, weeklyMiles: [Double]) -> [Double] {
        let canonical = longRunSchedule(n: n)
        return zip(canonical, weeklyMiles).map { (lr, total) in
            guard lr > 0, total > 0 else { return 0.0 }
            let cap = max(8.0, (total * 0.50).rounded(toPlaces: 0))
            return min(lr, cap)
        }
    }

    // MARK: - Cutback Detection

    static func isCutback(week: Int, total: Int) -> Bool {
        let offset    = 18 - total
        let canonical = week + offset
        return [4, 8, 12].contains(canonical)
    }

    // MARK: - Phase Info

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
    //
    // FIX 3: Race week detection and correct easy day budget allocation.
    //
    // Old race week bug: `max(longMiles, 8) = max(0, 8) = 8` — race week built an
    // 8-mile long run before injectRaceDay added 26.2 miles on top.
    //
    // Old easy day bug: `easyM = remain - tempo - midM` was computed as a total but
    // applied as a per-day value. With two "else" days (Mon and Thu), both received
    // the full easyM, doubling the actual mileage. Example: week 11 budget=41mi
    // would silently produce 50+ actual miles.
    //
    // Fix: pre-count easy days from schedule, then compute easyPerDay = easyTotal / count.
    // Easy days = all Weekday values NOT in {rests, lrDay, mwDay, q1Day, ctDay}.
    // When useTempo=false, q1Day is also an easy day — included in the count.
    //
    // FIX 1 (continued): canonical is passed into this function and threaded to
    // makeTempo and the tempo budget calculation.

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
        useTempo   : Bool,
        totalWeeks : Int
    ) -> TrainingWeek {
        let lrDay = schedule.longRunDay
        let q1Day = schedule.workoutDay1
        let mwDay = schedule.midweekLongDay
        let ctDay = schedule.crossTrainDay
        let rests = schedule.restDays

        // FIX 3a: Race week detection.
        // longMiles=0 is the race week sentinel. All days become rest;
        // injectRaceDay handles shakeout and marathon injection.
        let isRaceWeek = isTaper && longMiles <= 0
        if isRaceWeek {
            let days = Weekday.allCases.map { day -> TrainingDay in
                makeRest(day, isTaper: true)
            }
            return TrainingWeek(weekNumber: weekNumber, phase: phase,
                                phaseLabel: phaseLabel, days: days)
        }

        let longM = min(max(longMiles, 8), peakLong)
        let remain = max(0, min(total, peakWeekly) - longM)

        // FIX 1: Canonical tempo miles — same value used for budget AND day maker.
        // Old: tempoM from % formula → passed to makeTempo as `miles` → ignored.
        // New: tempoTotal from canonical table → passed to makeTempo as `canonical`.
        let tempoTotal = useTempo ? canonicalTempoMiles(canonical: canonical) : 0.0

        // Mid-week long run: 35% of remain.
        // As remain grows with plan progression, midM grows proportionally —
        // creating the visible mid-week anchor that distinguishes Intermediate from Novice.
        let midM = (remain * 0.35).rounded(toPlaces: 1)

        // FIX 3b: Count easy days from schedule to compute per-day mileage.
        // "Easy days" are all days not already claimed by a specific role.
        // When useTempo=false, q1Day reverts to easy — included in the count.
        var specialDays: Set<Weekday> = Set(rests).union([lrDay, mwDay])
        if let ct = ctDay { specialDays.insert(ct) }
        // q1Day is "special" only when useTempo is true (it gets the tempo session).
        // When useTempo=false, q1Day falls through to easy — do NOT add to specialDays.
        if useTempo { specialDays.insert(q1Day) }

        let easyDays    = Weekday.allCases.filter { !specialDays.contains($0) }
        let easyTotal   = max(0, remain - tempoTotal - midM)
        let easyPerDay  = easyDays.isEmpty
            ? 0.0
            : max(3.0, (easyTotal / Double(easyDays.count)).rounded(toPlaces: 1))

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
            } else if day == q1Day && useTempo {
                td = makeTempo(day, canonical: canonical, weekNumber: weekNumber)
            } else {
                // All remaining days (Monday, Thursday, and q1Day when !useTempo)
                // are easy runs, each receiving easyPerDay miles.
                td = makeEasyRun(day, miles: easyPerDay,
                                 weekNumber: weekNumber,
                                 isCutback: isCutback)
            }

            days.append(td)
        }

        return TrainingWeek(weekNumber: weekNumber, phase: phase,
                            phaseLabel: phaseLabel, days: days)
    }

    // MARK: - Day Makers

    static func makeRest(_ day: Weekday, isTaper: Bool) -> TrainingDay {
        let desc = isTaper
            ? "Rest day. The taper is doing its job. Your muscles are rebuilding and your glycogen is loading. Trust the process."
            : "Rest day. Recovery is when your body adapts to the training. This day is not wasted — it is essential."
        return TrainingDay(weekday: day, workoutType: .rest, miles: 0,
                           description: desc, paceNote: "—")
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

        return TrainingDay(weekday: day, workoutType: .longRun, miles: miles,
                           description: desc, paceNote: paceNote)
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
        return TrainingDay(weekday: day, workoutType: .midweekLong, miles: miles,
                           description: descs[weekNumber % descs.count],
                           paceNote: "Comfortable aerobic effort — not a recovery shuffle")
    }

    static func makeCrossTrain(_ day: Weekday, isTaper: Bool) -> TrainingDay {
        let desc = isTaper
            ? "Cross-training during taper. 30–40 minutes of easy cycling, swimming, or elliptical. Keep the heart rate low and the effort relaxed."
            : "Cross-training day. 45–60 minutes of low-impact aerobic work — cycling, swimming, or elliptical. This maintains fitness while giving your joints a break from running impact."
        return TrainingDay(weekday: day, workoutType: .crossTrain, miles: 0,
                           description: desc, paceNote: "Low-impact aerobic effort")
    }

    // MARK: - Tempo Run
    //
    // FIX 1 (day maker): Replaced weekNumber-based integer math with canonical lookup.
    //
    // Old: `tempoMiles = max(2, min(6, weekNumber / 3))`
    //   - Ignored the `miles` parameter
    //   - Integer division produced wrong values (week 3: 3/3=1 → floored to 2)
    //   - Did not correct for plan length (12-week week 11 ≠ canonical week 11)
    //   - TrainingDay.miles was disconnected from buildWeek's budget estimate
    //
    // New: `tempoSegByCanonical[canonical]` → deterministic, plan-length-aware.
    // Total = warmup(1mi) + segment + cooldown(1mi).
    // This matches canonicalTempoMiles() exactly — budget and stored miles are identical.

    static func makeTempo(_ day       : Weekday,
                           canonical  : Int,
                           weekNumber : Int) -> TrainingDay {
        let seg   = tempoSegByCanonical[canonical] ?? 3.0
        let total = (tempoWarmup + seg + tempoCooldown).rounded(toPlaces: 1)

        let descs: [String] = [
            "Tempo run: 1 mi easy warm-up · \(String(format: "%.0f", seg)) mi at comfortably hard effort · 1 mi easy cool-down · Total: \(String(format: "%.1f", total)) miles.\n\nComfortably hard means working but controlled — a pace you could hold for about an hour, not an all-out effort. You should be able to speak a short sentence but not hold a conversation.",
            "Tempo run: \(String(format: "%.0f", seg)) miles at a firm sustainable effort, bookended by a 1-mile warm-up and 1-mile cool-down.\n\nThis is the pace at the upper edge of your aerobic system. Breathing is deliberate and rhythmic. You are working — but in control.",
            "Tempo run: 1 mi warm-up · \(String(format: "%.0f", seg)) mi tempo · 1 mi cool-down · Total: \(String(format: "%.1f", total)) miles.\n\nThis session develops your lactate threshold — the pace your aerobic system can sustain before fatigue accumulates. Every tempo run raises that ceiling. Run by feel, not by a pace target.",
            "Tempo run: \(String(format: "%.0f", seg)) miles comfortably hard, between a 1-mile warm-up and cool-down.\n\nThis is harder than your easy runs but nowhere near a race effort. Think: the fastest pace you could sustain for a full hour. Controlled from start to finish.",
            "Tempo run: 1 mi easy · \(String(format: "%.0f", seg)) mi at tempo effort · 1 mi easy · Total: \(String(format: "%.1f", total)) miles.\n\nThe tempo segment should feel challenging but not desperate. If you are gasping, you went out too hard. Steady, rhythmic breathing throughout."
        ]

        return TrainingDay(weekday:     day,
                           workoutType: .tempoRun,
                           miles:       total,
                           description: descs[weekNumber % descs.count],
                           paceNote:    "Comfortably hard — about half marathon effort, sustained and controlled")
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

        return TrainingDay(weekday: day, workoutType: .easy, miles: miles,
                           description: descs[weekNumber % descs.count],
                           paceNote: note)
    }
}
