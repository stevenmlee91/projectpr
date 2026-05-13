import Foundation

// MARK: - Hansons Half Marathon Generator
//
// This is NOT Hansons Marathon scaled down.
//
// The half marathon is run at or near lactate threshold for most recreational
// runners. Training emphasis shifts toward threshold development and aerobic
// power. The cumulative fatigue mechanism is preserved, but workouts target
// faster aerobic paces and HMP specificity rather than marathon durability.
//
// KEY DIFFERENCES FROM HANSONS MARATHON:
//   Long run cap: 10 miles (vs 16)
//   Strength sessions: target HMP (vs MP)
//   Strength reps: shorter (HMP is faster — reps are more demanding)
//   Recovery between strength reps: 400m jog (0.25 mi — authentic Hansons)
//   Tempo: more central — closer to actual race effort for half marathoners
//   Peak mileage: ~45 mpw (vs 55)
//   Coaching: threshold/aerobic power emphasis over marathon durability
//
// PACEENGINE NOTE:
//   distance: 13.1 ensures paces.MP = HMP throughout.
//   paces.hansonsStrength = (HMP-5, HMP+5) — correct for half strength sessions.
//   paces.hansonsSpeed = HMP-55 — approximately 5K-10K effort. Correct.

struct HansonsHalfGenerator {

    private static let peakWeekly    : Double = 45
    private static let longRunCap    : Double = 10
    private static let strengthStart : Int    = 9

    // MARK: - Base Mileage Recommendation

    static func baseRecommendation(for base: Double) -> String? {
        switch base {
        case ..<20:
            return "Hansons Half works best from an established running base. From \(Int(base)) mpw, the opening 3–4 weeks establish the six-day frequency before full quality sessions begin."
        case 20..<28:
            return "Your base supports Hansons Half with a brief onboarding phase. The first 2 weeks establish six-day rhythm before full quality sessions begin."
        default:
            return nil
        }
    }

    // MARK: - Session Structs
    //
    // mileage computed from components — single source of truth.
    // Strength recovery: 400m (0.25 mi) — authentic Hansons distance.

    struct SpeedSession {
        let reps: Int; let repDist: String; let recovDist: String

        var repDistMiles: Double {
            switch repDist {
            case "400m": return 0.25; case "600m": return 0.375
            case "800m": return 0.5;  case "1000m": return 0.625
            case "1200m": return 0.75; case "1 mile": return 1.0
            default: return 0.5
            }
        }
        var recovDistMiles: Double {
            switch recovDist {
            case "200m jog": return 0.125; default: return 0.25
            }
        }
        static let warmup: Double = 1.5; static let cooldown: Double = 1.5

        func scaled(by s: Double) -> (reps: Int, totalMiles: Double) {
            let r = max(1, Int((Double(reps) * s).rounded()))
            let total = Self.warmup + Double(r) * repDistMiles
                      + Double(max(0, r-1)) * recovDistMiles + Self.cooldown
            return (r, total.rounded(toPlaces: 1))
        }
    }

    struct StrengthSession {
        let reps: Int; let milesPerRep: Double
        private static let recovJog: Double = 0.25  // 400m — authentic Hansons
        static let warmup: Double = 1.0; static let cooldown: Double = 1.0

        func scaled(by s: Double) -> (reps: Int, dist: Double, label: String, totalMiles: Double) {
            let r = max(1, Int((Double(reps) * s).rounded()))
            let d = max(0.75, (milesPerRep * s).rounded(toPlaces: 1))
            let total = Self.warmup + Double(r)*d + Double(max(0,r-1))*Self.recovJog + Self.cooldown
            return (r, d, "\(r)×\(String(format: "%.1g", d))mi", total.rounded(toPlaces: 1))
        }
    }

    enum QualityPhase { case speed, strength }

    // Speed: same directional progression as Hansons Marathon
    private static let speedSessions: [SpeedSession] = [
        SpeedSession(reps: 12, repDist: "400m",   recovDist: "200m jog"),
        SpeedSession(reps: 10, repDist: "600m",   recovDist: "200m jog"),
        SpeedSession(reps: 8,  repDist: "800m",   recovDist: "400m jog"),
        SpeedSession(reps: 6,  repDist: "1000m",  recovDist: "400m jog"),
        SpeedSession(reps: 5,  repDist: "1200m",  recovDist: "400m jog"),
        SpeedSession(reps: 4,  repDist: "1 mile", recovDist: "400m jog"),
        SpeedSession(reps: 8,  repDist: "600m",   recovDist: "200m jog"),
        SpeedSession(reps: 10, repDist: "400m",   recovDist: "200m jog"),
    ]

    // Strength: targets HMP — shorter reps than marathon (HMP is faster)
    // Directional: short HMP reps → longer sustained → taper approach
    private static let strengthSessions: [StrengthSession] = [
        StrengthSession(reps: 6, milesPerRep: 0.75),  // canonical  9
        StrengthSession(reps: 4, milesPerRep: 1.0),   // canonical 10
        StrengthSession(reps: 3, milesPerRep: 1.5),   // canonical 11
        StrengthSession(reps: 2, milesPerRep: 2.0),   // canonical 12
        StrengthSession(reps: 1, milesPerRep: 3.0),   // canonical 13
        StrengthSession(reps: 2, milesPerRep: 2.5),   // canonical 14
        StrengthSession(reps: 2, milesPerRep: 3.0),   // canonical 15
        StrengthSession(reps: 1, milesPerRep: 4.0),   // canonical 16 (peak)
        StrengthSession(reps: 3, milesPerRep: 1.5),   // taper ramp-down
        StrengthSession(reps: 4, milesPerRep: 0.75),  // taper
    ]

    private static func qualityScale(weekMiles: Double) -> Double {
        min(1.0, max(0.60, weekMiles / (peakWeekly * 0.85)))
    }

    // MARK: - Entry Point

    static func generate(settings: UserSettings) -> [TrainingWeek] {
        let n        = settings.planLength.rawValue
        let taperWks = settings.taperDuration.rawValue
        let schedule = settings.schedule.validated(for: .hansonsHalf)
        let paces    = PaceEngine(goalMinutes: settings.goalTimeMinutes, distance: 13.1)
        let mileage  = weeklyMileageSchedule(n: n, base: settings.baseMileage, taperWeeks: taperWks)
        let longRuns = longRunSchedule(n: n, taperWeeks: taperWks,
                                        base: settings.baseMileage)

        var weeks: [TrainingWeek] = []
        for i in 0..<n {
            let wk        = i + 1
            let canonical = wk + (18 - n)
            let isTap     = wk > n - taperWks
            let qPhase: QualityPhase = canonical >= strengthStart ? .strength : .speed
            let (tPhase, phaseLabel) = phaseInfo(week: wk, total: n, taperWeeks: taperWks)
            weeks.append(buildWeek(weekNumber: wk, canonical: canonical, phase: tPhase,
                                    phaseLabel: phaseLabel, totalMiles: mileage[i],
                                    longMiles: longRuns[i], qualityPhase: qPhase,
                                    schedule: schedule, isTaper: isTap, totalWeeks: n,
                                    baseMileage: settings.baseMileage, paces: paces))
        }
        return PlanGenerator.injectRaceDay(into: weeks, schedule: schedule, raceType: .halfMarathon)
    }

    // MARK: - Mileage / Long Run / Phase

    static func weeklyMileageSchedule(n: Int, base: Double, taperWeeks: Int) -> [Double] {
        let buildWeeks  = n - taperWeeks
        let adaptStart  = min(base * 1.08 + 1.0, peakWeekly * 0.95).rounded(toPlaces: 0)
        let achievable  = min(peakWeekly, adaptStart * pow(1.10, Double(buildWeeks))).rounded(toPlaces: 0)
        var result: [Double] = []; var current = adaptStart
        for i in 0..<buildWeeks {
            let p = buildWeeks > 1 ? Double(i) / Double(buildWeeks-1) : 1.0
            let val = min(max((min(adaptStart+(achievable-adaptStart)*p, current*1.10))
                              .rounded(toPlaces: 0), adaptStart), achievable)
            result.append(val); current = val
        }
        let peak = result.max() ?? achievable
        for pct in (taperWeeks == 3 ? [0.85, 0.70, 0.40] : [0.75, 0.40]) {
            result.append(max(adaptStart, (peak * pct).rounded(toPlaces: 0)))
        }
        return result
    }

    static func longRunSchedule(n: Int, taperWeeks: Int, base: Double) -> [Double] {
        // ROOT CAUSE OF PREVIOUS BUG:
        //   canonical18 had the 18-week plan's taper weeks (8, 6, 4, 0) embedded
        //   at positions 14-17. For n=12, offset=6, the slice was:
        //   [8, 9, 9, 10, 10, 10, 10, 10, 8, 6, 4, 0]
        //   The 18-week plan's taper weeks landed in build weeks 9-12 of a 12-week
        //   plan — dropping long runs before the actual taper should start.
        //
        // FIX: Dynamic computation. Build from a base-appropriate start to
        //   longRunCap, sustain at cap, then taper from the actual taper weeks.
        //   No canonical array means no taper leak regardless of plan length.
        let buildWeeks = n - taperWeeks

        // Starting long run: scaled from base, conservative
        let longStart = max(5.0, min(base * 0.35, longRunCap * 0.6))
            .rounded(toPlaces: 0)

        // Build: linear ramp from longStart to longRunCap, at most +1 mile/week
        var buildLRs : [Double] = []
        var current   = longStart

        for i in 0..<buildWeeks {
            let progress = buildWeeks > 1
                ? Double(i) / Double(buildWeeks - 1) : 1.0
            let target   = longStart + (longRunCap - longStart) * progress
            let next     = min(target.rounded(toPlaces: 0),
                               current + 1.0, longRunCap)
            buildLRs.append(next)
            current = next
        }

        // Taper: reduce from achieved peak, not from longRunCap
        let achievedPeak = buildLRs.max() ?? longRunCap
        let taperLRs: [Double] = taperWeeks == 3
            ? [(achievedPeak * 0.70).rounded(toPlaces: 0),
               (achievedPeak * 0.50).rounded(toPlaces: 0), 0]
            : [(achievedPeak * 0.65).rounded(toPlaces: 0), 0]

        return buildLRs + taperLRs
    }

    static func phaseInfo(week: Int, total: Int, taperWeeks: Int) -> (TrainingPhase, String) {
        let isTap     = week > total - taperWeeks
        let canonical = week + (18 - total)
        if isTap                     { return (.taper, "Taper")       }
        if canonical < 4             { return (.base,  "Base Phase")  }
        if canonical < strengthStart { return (.build, "Speed Phase") }
        return                         (.build, "Strength Phase")
    }

    // MARK: - Session Mileage

    private static func q1Miles(canonical: Int, phase: QualityPhase,
                                  scale: Double, isTaper: Bool) -> Double {
        let s = isTaper ? scale * 0.75 : scale
        switch phase {
        case .speed:
            let idx = max(0, min(canonical-1, speedSessions.count-1))
            return speedSessions[idx].scaled(by: s).totalMiles
        case .strength:
            let idx = max(0, min(canonical-strengthStart, strengthSessions.count-1))
            return strengthSessions[idx].scaled(by: s).totalMiles
        }
    }

    private static func tempoMiles(canonical: Int, weekMiles: Double, isTaper: Bool) -> Double {
        if isTaper { return max(4.0, weekMiles * 0.13).rounded(toPlaces: 1) }
        let byC: Double
        switch canonical {
        case ..<5: byC=6.0; case 5...8: byC=7.0; case 9...12: byC=8.0
        case 13...15: byC=9.0; default: byC=7.0
        }
        return min(byC, max(weekMiles * 0.18, 5.0)).rounded(toPlaces: 1)
    }

    // MARK: - Week Builder

    static func buildWeek(weekNumber: Int, canonical: Int, phase: TrainingPhase,
                           phaseLabel: String, totalMiles: Double, longMiles: Double,
                           qualityPhase: QualityPhase, schedule: UserSchedule,
                           isTaper: Bool, totalWeeks: Int, baseMileage: Double,
                           paces: PaceEngine) -> TrainingWeek {
        let tier         = RunnerReadinessTier.from(base: baseMileage)
        let inOnboarding = canonical < tier.qualityIntroCanonical && !isTaper
        let scale        = qualityScale(weekMiles: totalMiles)
        let depth        = Double(weekNumber) / Double(totalWeeks)

        let restSet = Set(schedule.restDays)
        let lrDay   = schedule.longRunDay
        let q1Day   = schedule.workoutDay1
        let q2Day   = schedule.workoutDay2

        let longM  = min(max(longMiles, 5), longRunCap)
        let budget = max(0, totalMiles - longM)
        let rawQ1  = inOnboarding ? max(5.0, totalMiles*0.18).rounded(toPlaces:1)
                                  : q1Miles(canonical: canonical, phase: qualityPhase,
                                             scale: scale, isTaper: isTaper)
        let rawQ2  = tempoMiles(canonical: canonical, weekMiles: totalMiles, isTaper: isTaper)
        let safeQ1 = min(rawQ1, budget * 0.45)
        let safeQ2 = min(rawQ2, max(0, budget-safeQ1) * 0.55)
        let easyPerDay = max(0.0, (max(0, totalMiles-longM-safeQ1-safeQ2)/3.0).rounded(toPlaces:1))
        let easyType: WorkoutType = (inOnboarding && tier == .rebuilding) ? .recovery : .easy

        var days: [TrainingDay] = []
        for day in Weekday.allCases {
            let td: TrainingDay
            if restSet.contains(day) {
                td = makeRest(day, isTaper: isTaper)
            } else if day == lrDay {
                td = makeLongRun(day, miles: longM, weekNumber: weekNumber,
                                  totalWeeks: totalWeeks, isTaper: isTaper, paces: paces)
            } else if day == q1Day {
                td = inOnboarding
                    ? makeOnboardingRun(day, miles: safeQ1, canonical: canonical,
                                         tier: tier, weekNumber: weekNumber, paces: paces)
                    : (qualityPhase == .speed
                        ? makeSpeedWorkout(day, canonical: canonical, scale: scale,
                                            isTaper: isTaper, depth: depth, paces: paces)
                        : makeStrengthWorkout(day, canonical: canonical, scale: scale,
                                               isTaper: isTaper, depth: depth, paces: paces))
            } else if day == q2Day {
                td = makeTempoRun(day, canonical: canonical, miles: safeQ2,
                                   qPhase: qualityPhase, isTaper: isTaper, depth: depth, paces: paces)
            } else {
                td = makeEasyRun(day, miles: easyPerDay, weekNumber: weekNumber,
                                  isTaper: isTaper, workoutType: easyType,
                                  inOnboarding: inOnboarding, paces: paces)
            }
            days.append(td)
        }
        return TrainingWeek(weekNumber: weekNumber, phase: phase, phaseLabel: phaseLabel, days: days)
    }

    // MARK: - Day Makers

    static func makeRest(_ day: Weekday, isTaper: Bool) -> TrainingDay {
        TrainingDay(weekday: day, workoutType: .rest, miles: 0,
                    description: isTaper
                        ? "Rest day. One day off. Your legs are sharpening for race day — this rest is part of the preparation."
                        : "Rest day. One off-day in a six-day week. The cumulative fatigue across the other six days is the Hansons mechanism. This rest allows adaptation without undercutting the load.",
                    paceNote: "—")
    }

    static func makeOnboardingRun(_ day: Weekday, miles: Double, canonical: Int,
                                    tier: RunnerReadinessTier, weekNumber: Int,
                                    paces: PaceEngine) -> TrainingDay {
        switch tier {
        case .rebuilding:
            if canonical <= 2 {
                return TrainingDay(weekday: day, workoutType: .strides, miles: miles,
                    description: "Easy run with strides: \(Int(miles)) miles easy, then 4 × 20-second light accelerations with full walk recovery between each. Building the six-day habit before quality sessions begin.",
                    paceNote: "Easy + 4 × 20-sec strides")
            }
            return TrainingDay(weekday: day, workoutType: .easy, miles: miles,
                description: "Fartlek run: \(Int(miles)) miles with unstructured pickups. Every 6–8 minutes, pick up the pace for 30–45 seconds — quicker but not hard. Return to easy. Prepares your legs for next week's structured speed sessions.",
                paceNote: "Easy with occasional 30–45 sec pickups")
        case .developing:
            return TrainingDay(weekday: day, workoutType: .easy, miles: miles,
                description: "Fartlek run: \(Int(miles)) miles with 4–6 surges of 45–75 seconds at comfortably quick effort. Full easy recovery between each. Next week these become structured speed intervals.",
                paceNote: "Easy with 4–6 × 45–75-sec surges")
        case .prepared, .advanced:
            return makeEasyRun(day, miles: miles, weekNumber: weekNumber,
                                isTaper: false, workoutType: .easy, inOnboarding: false, paces: paces)
        }
    }

    static func makeSpeedWorkout(_ day: Weekday, canonical: Int, scale: Double,
                                   isTaper: Bool, depth: Double, paces: PaceEngine) -> TrainingDay {
        let s   = isTaper ? scale * 0.75 : scale
        let idx = max(0, min(canonical-1, speedSessions.count-1))
        let session = speedSessions[idx]
        let (reps, total) = session.scaled(by: s)
        let pace = PaceEngine.format(paces.hansonsSpeed)

        let depthNote: String
        switch depth {
        case ..<0.30: depthNote = "Speed phase. These sessions build running economy — the efficiency at faster paces that directly lowers the cost of running at your half marathon goal pace."
        case 0.30..<0.65: depthNote = "Mid-speed phase. Intervals are getting longer, bridging toward aerobic power. This aerobic power underpins half marathon performance more than any other quality."
        default: depthNote = "Final speed weeks — returning to shorter intervals to sharpen leg turnover before transitioning to half marathon pace specificity."
        }

        let w = Int(SpeedSession.warmup); let c = Int(SpeedSession.cooldown)
        return TrainingDay(weekday: day, workoutType: .speedWork, miles: total,
            description: """
Speed workout: \(reps)×\(session.repDist) at 10K effort, \(session.recovDist) recovery.

\(w) mi warmup · \(reps)×\(session.repDist) at 10K pace · \(session.recovDist) between reps · \(c) mi cooldown · Total: \(String(format: "%.1f", total)) miles\(isTaper ? "\n\nTaper week — session already shortened. Preserve pace." : "")

Consistent reps — not all-out. If you positive-split, you started too fast.

\(depthNote)
""",
            paceNote: "~\(pace)/mi — 10K effort, controlled and repeatable")
    }

    static func makeStrengthWorkout(_ day: Weekday, canonical: Int, scale: Double,
                                     isTaper: Bool, depth: Double, paces: PaceEngine) -> TrainingDay {
        let s   = isTaper ? scale * 0.75 : scale
        let idx = max(0, min(canonical-strengthStart, strengthSessions.count-1))
        let session = strengthSessions[idx]
        let (_, _, label, total) = session.scaled(by: s)
        let hmpRange = paces.rangeString(paces.hansonsStrength)

        let depthNote: String
        switch depth {
        case ..<0.50: depthNote = "You have entered the strength phase. The goal shifts from economy to half marathon pace specificity. Run exactly at goal HM pace — accumulated fatigue is the training stress."
        case 0.50..<0.75: depthNote = "Cumulative fatigue is accumulating across the week. Running HM pace on tired legs is becoming familiar. Race day will feel controlled because of this."
        default: depthNote = "Late in the block. These sessions are your most race-specific work. Your body knows this pace. The fatigue underneath it mirrors what you will carry in the second half of your race."
        }

        let recovNote = session.reps > 1 ? " with 400m jog (0.25 mi) recovery between reps" : ""
        let w = Int(StrengthSession.warmup); let c = Int(StrengthSession.cooldown)
        return TrainingDay(weekday: day, workoutType: .strengthMP, miles: total,
            description: """
Strength workout: \(label) at half marathon pace\(recovNote).

\(w) mi warmup · \(label) at HM goal pace · \(c) mi cooldown · Total: \(String(format: "%.1f", total)) miles\(isTaper ? "\n\nTaper week — already reduced. Same pace, less volume." : "")

Run each rep at exactly your goal half marathon pace — not faster. This pace discipline is the training effect. You are making HM pace familiar under accumulated weekly fatigue.

\(depthNote)
""",
            paceNote: "\(hmpRange) — exact half marathon goal pace, every rep")
    }

    static func makeTempoRun(_ day: Weekday, canonical: Int, miles: Double,
                               qPhase: QualityPhase, isTaper: Bool,
                               depth: Double, paces: PaceEngine) -> TrainingDay {
        let pace    = PaceEngine.format(paces.pfitzLT)  // threshold pace, ~HMP-20sec/mi
        let segment = max(3.0, miles - 3.0)
        let context = qPhase == .speed
            ? "During the speed phase, this session develops the aerobic ceiling that your half marathon effort sits beneath. For most runners, the half marathon is run very close to threshold — this session is directly race-specific."
            : "In the strength phase, Tuesday targets your half marathon pace while this session targets the aerobic threshold above it. Together they bracket your race effort from both sides."

        return TrainingDay(weekday: day, workoutType: .tempoRun, miles: miles,
            description: """
Hansons Tempo: \(Int(miles)) miles — warmup, \(Int(segment)) miles at tempo effort, cooldown.

\(isTaper ? "Taper week — 3 miles at tempo effort. Pace matters; duration reduces.\n\n" : "")Tempo effort: faster than half marathon pace, harder than easy, but not racing. Short phrases possible, not full sentences. Deliberate, audible breathing.

\(context)
""",
            paceNote: "~\(pace)/mi — Hansons Tempo, threshold effort sustained")
    }

    static func makeEasyRun(_ day: Weekday, miles: Double, weekNumber: Int,
                              isTaper: Bool, workoutType: WorkoutType,
                              inOnboarding: Bool, paces: PaceEngine) -> TrainingDay {
        let easyRange = paces.rangeString(paces.easy)
        let recovery  = paces.singleString(paces.recovery)
        let descs: [String] = inOnboarding ? [
            "Easy run. Building the six-day habit before quality sessions begin. Frequency is the Hansons mechanism — showing up every day is the training.",
            "Easy run. Six days per week. You are establishing that rhythm before harder sessions arrive.",
            "Easy run. Consistency of showing up matters more than any individual run at this stage.",
            "Easy run. Your body is adapting to daily running without added stress."
        ] : workoutType == .recovery ? [
            "Recovery run. Deliberately slower than easy. Protecting the quality days.",
            "Recovery run. Genuinely slow. Six days requires some days be true recovery.",
            "Recovery run. Slower than feels necessary. Easy days make hard days possible."
        ] : [
            "Easy run. Connects the quality sessions. Genuinely easy — if you can't hold a conversation, slow down.",
            "Easy run. These runs accumulate aerobic volume without recovery cost. They are quietly making you fitter.",
            "Easy run. Six days per week is the structure. This is one of three connective days — simple, consistent, necessary.",
            "Easy run. Quality sessions build specific fitness. Easy days build the aerobic foundation underneath them. Both matter.",
            "Easy run. In cumulative fatigue training, easy days matter as much as hard days. Running too fast here costs you the sessions that count."
        ]
        let pace = workoutType == .recovery ? recovery : easyRange
        return TrainingDay(weekday: day, workoutType: workoutType, miles: miles,
                           description: descs[weekNumber % descs.count],
                           paceNote: isTaper ? "Easy — taper week, relaxed" : pace)
    }

    static func makeLongRun(_ day: Weekday, miles: Double, weekNumber: Int,
                              totalWeeks: Int, isTaper: Bool, paces: PaceEngine) -> TrainingDay {
        let easyRange   = paces.rangeString(paces.longRun)
        let weeksToRace = totalWeeks - weekNumber
        let desc: String
        switch (isTaper, weeksToRace) {
        case (true, 1):
            desc = "Final long run. Run easy and enjoy it — your fitness is built. This is about rhythm, not fitness."
        case (true, _):
            desc = "Taper long run. Shorter than recent runs — correct. Rhythm stays. Volume reduces. Fitness is locked in."
        case (false, _) where miles >= 10:
            desc = "Long run: \(Int(miles)) miles easy.\n\nCapped at 10 miles — this is deliberate. You run six days per week. Arriving here on accumulated fatigue is the point. Ten miles on tired legs develops the endurance the half marathon demands without the recovery cost of longer efforts.\n\nRun easy throughout. Do not race this run."
        default:
            desc = "Long run: \(Int(miles)) miles easy.\n\nIn Hansons Half, the long run is one of six weekly runs — not the focal point. The quality sessions built your fitness. This run adds aerobic endurance as part of a system.\n\nRun at \(easyRange) throughout."
        }
        return TrainingDay(weekday: day, workoutType: .longRun, miles: miles,
                           description: desc, paceNote: "\(easyRange) — easy, conversational")
    }
}
