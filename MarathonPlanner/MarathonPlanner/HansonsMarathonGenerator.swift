import Foundation

// MARK: - Runner Readiness Tier
//
// Categorizes the runner's incoming base mileage.
// Drives structural decisions in both Hansons and Pfitz generators:
// quality introduction timing, long-run starting point, early pacing.

enum RunnerReadinessTier {
    case rebuilding  // < 25 mpw
    case developing  // 25–35 mpw
    case prepared    // 35–46 mpw
    case advanced    // 46+ mpw

    static func from(base: Double) -> RunnerReadinessTier {
        switch base {
        case ..<25:   return .rebuilding
        case 25..<36: return .developing
        case 36..<46: return .prepared
        default:      return .advanced
        }
    }

    // Canonical week at which full quality sessions begin.
    // Before this: onboarding sessions (strides, fartlek, reduced quality).
    var qualityIntroCanonical: Int {
        switch self {
        case .rebuilding: return 4  // 3 weeks establishing rhythm first
        case .developing: return 3  // 2 weeks
        case .prepared:   return 2  // 1 week
        case .advanced:   return 1  // immediate
        }
    }

    // Canonical week at which Pfitz LT sessions begin.
    var ltIntroCanonical: Int {
        switch self {
        case .rebuilding: return 4
        case .developing: return 3
        case .prepared:   return 2
        case .advanced:   return 1
        }
    }

    // Pfitz adaptive long run start as fraction of base mileage.
    var longRunStartFraction: Double {
        switch self {
        case .rebuilding: return 0.30
        case .developing: return 0.32
        case .prepared:   return 0.34
        case .advanced:   return 0.36
        }
    }
}

// MARK: - Hansons Marathon Generator

struct HansonsMarathonGenerator {

    // MARK: - Constants

    private static let peakWeekly    : Double = 55
    private static let longRunCap    : Double = 16
    private static let strengthStart : Int    = 9
    private static let cutbackWeeks  : Set<Int> = [7, 10]   // canonical Hansons cutbacks
    private static let cutbackCount  : Int    = 2           // used in achievablePeak math

    // MARK: - Base Mileage Recommendation
    //
    // Returns nil when the runner's base is sufficient for the plan.
    // Returns a coaching recommendation string when the runner is below the
    // recommended minimum — surfaces in UI before plan confirmation.
    // Not a gate: the plan still generates and adapts to any base.

    static func baseRecommendation(for base: Double) -> String? {
        switch base {
        case ..<20:
            return "Hansons is built for runners with an established aerobic foundation. Entering from \(Int(base)) mpw, your first 5–6 weeks will be an intentional adaptation phase before the full methodology rhythm takes over. If you have 8+ weeks before starting, building to 25 mpw first will help you get more from the plan."
        case 20..<28:
            return "Your base is developing. The opening 3 weeks focus on establishing the six-day rhythm and durability — full Hansons quality structure begins around week 4. This is a legitimate way to enter the methodology."
        default:
            return nil  // sufficient base — no recommendation needed
        }
    }

    // MARK: - Quality Phase

    enum QualityPhase { case speed, strength }

    // MARK: - Session Libraries

    struct SpeedSession {
        let reps      : Int
        let repDist   : String
        let recovDist : String
        let baseMiles : Double
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

    struct StrengthSession {
        let reps        : Int
        let milesPerRep : Double
        let baseMiles   : Double
    }

    private static let strengthSessions: [StrengthSession] = [
        StrengthSession(reps: 6, milesPerRep: 1.0, baseMiles:  9.0),
        StrengthSession(reps: 2, milesPerRep: 3.0, baseMiles: 10.0),
        StrengthSession(reps: 4, milesPerRep: 1.5, baseMiles:  9.5),
        StrengthSession(reps: 3, milesPerRep: 2.0, baseMiles: 10.0),
        StrengthSession(reps: 1, milesPerRep: 6.0, baseMiles: 10.0),
        StrengthSession(reps: 4, milesPerRep: 2.0, baseMiles: 12.0),
        StrengthSession(reps: 2, milesPerRep: 4.0, baseMiles: 12.0),
        StrengthSession(reps: 3, milesPerRep: 2.0, baseMiles: 10.0),
        StrengthSession(reps: 2, milesPerRep: 3.0, baseMiles: 10.0),
        StrengthSession(reps: 4, milesPerRep: 1.0, baseMiles:  7.0),
    ]

    // Scale sessions proportionally to actual weekly mileage.
    // Scale BOTH rep count AND rep distance to avoid inversion on single-rep sessions.
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
                baseMileage:  settings.baseMileage,
                paces:        paces
            ))
        }

        return PlanGenerator.injectRaceDay(into: weeks, schedule: schedule,
                                            raceType: .marathon)
    }

    // MARK: - Weekly Mileage Schedule (FIXED)
    //
    // THE CORE BUG THAT WAS FIXED:
    //   Previous: taper % applied to peakWeekly (55).
    //   A 10 mpw runner building to 30 mpw got a 43 mpw "taper week."
    //   This is physiologically indefensible and breaks trust immediately.
    //
    // THE FIX:
    //   1. Compute achievablePeak — what this runner can realistically reach
    //      from their base in the available build weeks, using 10% ramp math.
    //   2. Target the smooth progression toward achievablePeak, not peakWeekly.
    //   3. Apply taper percentages to achievedPeak (actual max in build schedule),
    //      not to the methodology's nominal ceiling.
    //
    // OUTCOME:
    //   10 mpw runner on 16-week plan: builds from 12 to ~34 mpw,
    //   tapers at 27 → 15. No spike. Steady progression throughout.
    //   25 mpw runner: builds to 55 mpw, tapers normally.
    //   48 mpw runner: starts close to peak, reaches 55 quickly.

    static func weeklyMileageSchedule(n: Int, base: Double,
                                       taperWeeks: Int) -> [Double] {
        let peak       = peakWeekly
        let buildWeeks = n - taperWeeks

        // Adaptive start: first week should be a believable step above current base.
        // No artificial 70% ceiling that steps high-base runners backward.
        let adaptiveStart = min(base * 1.08 + 1.0, peak * 0.95)
            .rounded(toPlaces: 0)

        // Achievable peak: ceiling this runner can realistically reach.
        // Uses effective build weeks (total minus cutback weeks where progress resets).
        // This prevents the smooth curve from targeting an impossible 55 mpw
        // and causing late-cycle spikes when the runner inevitably falls short.
        let effectiveBuildWeeks = Double(buildWeeks - cutbackCount)
        let rawAchievable = adaptiveStart * pow(1.10, effectiveBuildWeeks)
        let achievablePeak = min(peak, rawAchievable).rounded(toPlaces: 0)

        var result  : [Double] = []
        var current             = adaptiveStart

        for i in 0..<buildWeeks {
            let wk        = i + 1
            let canonical = wk + (18 - n)

            // Smooth linear progression from adaptiveStart to achievablePeak.
            // Because achievablePeak is computed from 10% ramp math, this curve
            // is inherently safe — no week will require an unsafe single-week jump.
            let progress     = buildWeeks > 1
                ? Double(i) / Double(buildWeeks - 1)
                : 1.0
            let smoothTarget = adaptiveStart + (achievablePeak - adaptiveStart) * progress

            if cutbackWeeks.contains(canonical) {
                // Cutback: step back from pre-cutback level (not from smooth target).
                // This gives a true recovery week, not just a slower build.
                let val = max(adaptiveStart, (current * 0.82).rounded(toPlaces: 0))
                result.append(val)
                // current does NOT update on cutback weeks.
                // The following week targets the smooth curve from pre-cutback level.
            } else {
                // Build toward smooth target, respect 10% weekly ceiling.
                let capped = min(smoothTarget, current * 1.10)
                let val    = min(max(capped.rounded(toPlaces: 0), adaptiveStart),
                                 achievablePeak)
                result.append(val)
                current = val
            }
        }

        // TAPER FROM ACHIEVED PEAK — not from methodology peak.
        // achievedPeak is what the runner actually ran at peak,
        // not the methodology's 55 mpw ceiling.
        let achievedPeak = result.max() ?? achievablePeak
        let taperPcts: [Double] = taperWeeks == 3
            ? [0.85, 0.72, 0.45]
            : [0.78, 0.45]
        for pct in taperPcts {
            result.append(max(adaptiveStart, (achievedPeak * pct).rounded(toPlaces: 0)))
        }

        return result
    }

    // MARK: - Long Run Schedule

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
        baseMileage  : Double,
        paces        : PaceEngine
    ) -> TrainingWeek {
        let tier         = RunnerReadinessTier.from(base: baseMileage)
        let inOnboarding = canonical < tier.qualityIntroCanonical && !isTaper
        let scale        = qualityScale(weekMiles: totalMiles)
        let trainingDepth = Double(weekNumber) / Double(totalWeeks)

        let restSet = Set(schedule.restDays)
        let lrDay   = schedule.longRunDay
        let q1Day   = schedule.workoutDay1
        let q2Day   = schedule.workoutDay2

        let longM          = min(max(longMiles, 6), longRunCap)
        let budgetAfterLong = max(0, totalMiles - longM)
        let rawQ1  = inOnboarding
            ? onboardingRunMiles(weekMiles: totalMiles)
            : q1Miles(canonical: canonical, phase: qualityPhase, scale: scale, isTaper: isTaper)
        let rawQ2  = tempoMiles(canonical: canonical, weekMiles: totalMiles, isTaper: isTaper)
        let safeQ1 = min(rawQ1, budgetAfterLong * 0.45)
        let safeQ2 = min(rawQ2, max(0, budgetAfterLong - safeQ1) * 0.55)

        let easyTotal  = max(0, totalMiles - longM - safeQ1 - safeQ2)
        let easyPerDay = easyTotal > 0
            ? max(3.0, (easyTotal / 3.0).rounded(toPlaces: 1))
            : 3.0

        let earlyEasyType: WorkoutType = (inOnboarding && tier == .rebuilding)
            ? .recovery : .easy

        var days: [TrainingDay] = []

        for day in Weekday.allCases {
            let td: TrainingDay

            if restSet.contains(day) {
                td = makeRest(day, isTaper: isTaper)
            } else if day == lrDay {
                td = makeLongRun(day, miles: longM, canonical: canonical,
                                 weekNumber: weekNumber, totalWeeks: totalWeeks,
                                 isTaper: isTaper, trainingDepth: trainingDepth,
                                 paces: paces)
            } else if day == q1Day {
                if inOnboarding {
                    td = makeOnboardingRun(day, miles: safeQ1, canonical: canonical,
                                           tier: tier, weekNumber: weekNumber,
                                           paces: paces)
                } else {
                    switch qualityPhase {
                    case .speed:
                        td = makeSpeedWorkout(day, canonical: canonical, miles: safeQ1,
                                              isTaper: isTaper, scale: scale,
                                              trainingDepth: trainingDepth, paces: paces)
                    case .strength:
                        td = makeStrengthWorkout(day, canonical: canonical, miles: safeQ1,
                                                  isTaper: isTaper, scale: scale,
                                                  trainingDepth: trainingDepth, paces: paces)
                    }
                }
            } else if day == q2Day {
                td = makeTempoRun(day, canonical: canonical, miles: safeQ2,
                                   isTaper: isTaper, trainingDepth: trainingDepth,
                                   paces: paces)
            } else {
                td = makeEasyRun(day, miles: easyPerDay, weekNumber: weekNumber,
                                  isTaper: isTaper, workoutType: earlyEasyType,
                                  inOnboarding: inOnboarding, paces: paces)
            }

            days.append(td)
        }

        return TrainingWeek(weekNumber: weekNumber, phase: phase,
                            phaseLabel: phaseLabel, days: days)
    }

    // MARK: - Session Mile Calculations

    private static func onboardingRunMiles(weekMiles: Double) -> Double {
        return max(5.0, weekMiles * 0.18).rounded(toPlaces: 1)
    }

    private static func q1Miles(canonical: Int, phase: QualityPhase,
                                  scale: Double, isTaper: Bool) -> Double {
        let base: Double
        switch phase {
        case .speed:
            let idx = max(0, canonical - 1) % speedSessions.count
            base = speedSessions[idx].baseMiles
        case .strength:
            let idx = max(0, canonical - strengthStart) % strengthSessions.count
            base = strengthSessions[idx].baseMiles
        }
        let factor: Double = isTaper ? scale * 0.75 : scale
        return (base * factor).rounded(toPlaces: 1)
    }

    private static func tempoMiles(canonical: Int, weekMiles: Double,
                                    isTaper: Bool) -> Double {
        if isTaper { return max(5.0, weekMiles * 0.14).rounded(toPlaces: 1) }
        let byCanonical: Double
        switch canonical {
        case ..<6:    byCanonical = 7.0
        case 6...8:   byCanonical = 8.0
        case 9...12:  byCanonical = 9.0
        case 13...15: byCanonical = 10.0
        default:      byCanonical = 8.0
        }
        return min(byCanonical, max(weekMiles * 0.17, 5.0)).rounded(toPlaces: 1)
    }

    // MARK: - Day Makers

    static func makeRest(_ day: Weekday, isTaper: Bool) -> TrainingDay {
        let desc = isTaper
            ? "Rest day. Your one day off. The taper is working even when it does not feel like it."
            : "Rest day. One day off in a six-day week is Hansons' design. The cumulative fatigue that builds across the other six days is the mechanism. This rest allows adaptation without undercutting the load."
        return TrainingDay(weekday: day, workoutType: .rest, miles: 0,
                           description: desc, paceNote: "—")
    }

    static func makeOnboardingRun(_ day      : Weekday,
                                   miles     : Double,
                                   canonical : Int,
                                   tier      : RunnerReadinessTier,
                                   weekNumber: Int,
                                   paces     : PaceEngine) -> TrainingDay {
        let easyRange = paces.rangeString(paces.easy)

        switch tier {
        case .rebuilding:
            if canonical <= 2 {
                let desc = """
Easy run with strides: \(String(format: "%.0f", miles)) miles easy, then 4 × 20-second light accelerations.

Run the main distance at a genuinely comfortable effort. At the end, add 4 strides: 20 seconds \
of running lighter and quicker than normal pace, with full walk recovery between each.

You are building the six-day habit before harder sessions begin. The frequency is the training \
right now — not the effort. These strides introduce leg turnover without adding meaningful fatigue.
"""
                return TrainingDay(weekday: day, workoutType: .strides, miles: miles,
                                   description: desc,
                                   paceNote: "Easy + 4 × 20-sec strides — full walk recovery")
            } else {
                let desc = """
Fartlek run: \(String(format: "%.0f", miles)) miles with unstructured pickups.

Run easy throughout. Every 5–7 minutes, pick up the pace for 30–60 seconds — noticeably \
quicker, not hard. Return to easy. No structure, no targets.

This introduces effort variation before structured speed sessions begin. You are learning \
what it means to push a little on tired legs — the Hansons mechanism in its earliest form.
"""
                return TrainingDay(weekday: day, workoutType: .easy, miles: miles,
                                   description: desc,
                                   paceNote: "Easy with occasional 30–60 sec pickups")
            }

        case .developing:
            let desc = """
Fartlek run: \(String(format: "%.0f", miles)) miles with 4–6 unstructured surges.

Run easy for the main distance. Insert 4–6 surges of 45–90 seconds at comfortably quick effort \
— faster than easy, well below all-out. Full easy running recovery between each.

Next week, these surges become structured speed intervals. This fartlek bridges your current \
base to the Hansons quality work ahead.
"""
            return TrainingDay(weekday: day, workoutType: .easy, miles: miles,
                               description: desc,
                               paceNote: "Easy with 4–6 × 45–90-sec surges")

        case .prepared:
            let desc = """
Introductory speed session: \(String(format: "%.0f", miles)) miles — warmup, abbreviated intervals, cooldown.

Shortened version of the speed work beginning next week. Warmup 1.5 miles easy, then \
4 × 600m at 10K effort with 300m jog recovery, cooldown 1.5 miles easy.

Your base is solid. This session establishes the rhythm before full volume begins.
"""
            return TrainingDay(weekday: day, workoutType: .speedWork, miles: miles,
                               description: desc,
                               paceNote: "10K effort for intervals — abbreviated session")

        case .advanced:
            return makeEasyRun(day, miles: miles, weekNumber: weekNumber,
                                isTaper: false, workoutType: .easy,
                                inOnboarding: false, paces: paces)
        }
    }

    static func makeSpeedWorkout(_ day          : Weekday,
                                  canonical     : Int,
                                  miles         : Double,
                                  isTaper       : Bool,
                                  scale         : Double,
                                  trainingDepth : Double,
                                  paces         : PaceEngine) -> TrainingDay {
        let idx       = max(0, canonical - 1) % speedSessions.count
        let session   = speedSessions[idx]
        let speedPace = PaceEngine.format(paces.hansonsSpeed)
        let scaledReps = max(1, Int((Double(session.reps) * scale).rounded()))
        let tapNote   = isTaper ? " Taper week — shorten if legs feel heavy." : ""

        let depthNote: String
        switch trainingDepth {
        case ..<0.30:
            depthNote = "Speed phase. These sessions develop running economy — efficiency at paces faster than marathon pace. This directly lowers the energy cost of MP in the strength phase ahead."
        case 0.30..<0.65:
            depthNote = "Mid-speed phase. The intervals should feel familiar now. Economy is developing. In a few weeks this transitions to marathon-pace strength sessions."
        default:
            depthNote = "Final speed weeks. These sessions have built your economy. The methodology moves to MP specificity soon."
        }

        let desc = """
Speed workout: \(scaledReps)×\(session.repDist) at 10K effort, \(session.recovDist) recovery.\(tapNote)

Warmup 1.5–2 miles easy. Consistent splits — not all-out. If positive-splitting, you started too fast. \
Full recovery between reps. Cooldown 1.5 miles easy.

\(depthNote)
"""
        return TrainingDay(weekday: day, workoutType: .speedWork, miles: miles,
                           description: desc,
                           paceNote: "~\(speedPace)/mi — 10K effort, consistent reps")
    }

    static func makeStrengthWorkout(_ day          : Weekday,
                                     canonical     : Int,
                                     miles         : Double,
                                     isTaper       : Bool,
                                     scale         : Double,
                                     trainingDepth : Double,
                                     paces         : PaceEngine) -> TrainingDay {
        let idx        = max(0, canonical - strengthStart) % strengthSessions.count
        let session    = strengthSessions[idx]
        let mpRange    = paces.rangeString(paces.hansonsStrength)
        // Scale BOTH count and distance — max(1,...) prevents single-rep sessions doubling
        let scaledReps = max(1, Int((Double(session.reps) * scale).rounded()))
        let scaledDist = max(1.0, (session.milesPerRep * scale).rounded(toPlaces: 1))
        let scaledLabel = "\(scaledReps)×\(String(format: "%.1g", scaledDist))mi"

        let tapNote: String
        if isTaper {
            let taperReps = max(1, scaledReps - 1)
            tapNote = " Taper week — reduce to \(taperReps)×\(String(format: "%.1g", scaledDist))mi. Preserve the pace. Only volume reduces."
        } else { tapNote = "" }

        let depthNote: String
        switch trainingDepth {
        case ..<0.45:
            depthNote = "You have just transitioned from speed to strength work. The goal shifts from economy to marathon-pace specificity. These MP repeats are race simulation on tired legs."
        case 0.45..<0.70:
            depthNote = "You are carrying weeks of accumulated fatigue into this session. That is the point. Marathon pace on tired legs is becoming familiar. Race day will feel controlled because of this."
        default:
            depthNote = "Late in the block, this session is the most race-specific work you will do. Your body knows this pace. The accumulated fatigue you are running through is exactly what the second half of a marathon requires."
        }

        let desc = """
Strength workout: \(scaledLabel) at marathon pace, recovery jog between reps.\(tapNote)

Warmup 1 mile easy. Run each rep at exactly your goal marathon pace — not faster. \
Recovery jog 1–2 minutes between reps. Cooldown 1 mile easy.

Resist the urge to go faster. Pace discipline here matters more than training effect. \
You are making marathon pace familiar under accumulated fatigue.

\(depthNote)
"""
        return TrainingDay(weekday: day, workoutType: .strengthMP, miles: miles,
                           description: desc,
                           paceNote: "\(mpRange) — exact marathon goal pace, every rep")
    }

    static func makeTempoRun(_ day          : Weekday,
                               canonical     : Int,
                               miles         : Double,
                               isTaper       : Bool,
                               trainingDepth : Double,
                               paces         : PaceEngine) -> TrainingDay {
        let tempoPace    = PaceEngine.format(paces.pfitzLT)
        let tempoSegment = String(format: "%.0f", max(0, miles - 3.0))
        let tapNote      = isTaper ? "Taper week — run the tempo segment at effort, slightly shorter. Pace matters; duration reduces." : ""

        let depthNote: String
        switch trainingDepth {
        case ..<0.33:
            depthNote = "These tempo sessions build the aerobic ceiling that marathon pace sits beneath. Among the most important sessions in the plan."
        case 0.33..<0.67:
            depthNote = "Threshold pace on a week's accumulated fatigue. You are developing the ability to sustain quality effort while tired."
        default:
            depthNote = "Late-block tempo sessions maintain aerobic sharpness. They prevent you from becoming purely a slow, long-distance specialist heading into race day."
        }

        let desc = """
Tempo run: \(String(format: "%.0f", miles)) miles — warmup, \(tempoSegment) miles at threshold, cooldown.

\(tapNote.isEmpty ? "" : tapNote + "\n\n")Threshold pace is breathing rapidly and deliberately — hard, not all-out. \
Run the warmup easy, lock in at threshold, hold it.

\(depthNote)
"""
        return TrainingDay(weekday: day, workoutType: .tempoRun, miles: miles,
                           description: desc,
                           paceNote: "~\(tempoPace)/mi — threshold effort, sustained")
    }

    static func makeEasyRun(_ day         : Weekday,
                              miles        : Double,
                              weekNumber   : Int,
                              isTaper      : Bool,
                              workoutType  : WorkoutType,
                              inOnboarding : Bool,
                              paces        : PaceEngine) -> TrainingDay {
        let easyRange    = paces.rangeString(paces.easy)
        let recoveryPace = paces.singleString(paces.recovery)

        let descs: [String]
        if inOnboarding {
            descs = [
                "Easy run. You are building the six-day habit before harder sessions begin. The frequency is the training right now — not the effort.",
                "Easy run. Six days per week is the Hansons structure. You are establishing that structure. Run relaxed and protect it.",
                "Easy run. Consistency of showing up every day matters more than any single session at this stage.",
                "Easy run. Your body is adapting to six-day frequency. This run contributes to that without adding hard stimulus."
            ]
        } else if workoutType == .recovery {
            descs = [
                "Recovery run. Slower than your easy pace — deliberately. These early weeks protect you from hidden fatigue while the six-day rhythm establishes.",
                "Recovery run. Genuinely slow. Six days per week means some days must be true recovery.",
                "Recovery run. Slower than feels necessary. The easy days are what make the hard days possible."
            ]
        } else {
            descs = [
                "Easy run. These connect the quality sessions. Not filler — what makes six days per week sustainable without breakdown.",
                "Easy run. Genuinely easy. The quality sessions are where you push. Here, you recover and accumulate aerobic volume.",
                "Easy run. Six days per week is the strategy. This is one of three connective days — simple, consistent, and necessary.",
                "Easy run. Run at a pace where you could hold a full conversation without effort. If breathing hard, too fast.",
                "Easy run. In cumulative fatigue training, easy days matter as much as hard days. Running too fast here compromises the sessions that count."
            ]
        }

        let desc    = descs[weekNumber % descs.count]
        let notePace = workoutType == .recovery ? recoveryPace : easyRange
        let note    = isTaper ? "Easy — taper week, truly relaxed" : notePace

        return TrainingDay(weekday: day, workoutType: workoutType, miles: miles,
                           description: desc, paceNote: note)
    }

    static func makeLongRun(_ day          : Weekday,
                              miles         : Double,
                              canonical     : Int,
                              weekNumber    : Int,
                              totalWeeks    : Int,
                              isTaper       : Bool,
                              trainingDepth : Double,
                              paces         : PaceEngine) -> TrainingDay {
        let easyRange   = paces.rangeString(paces.longRun)
        let weeksToRace = totalWeeks - weekNumber

        let desc: String
        switch (isTaper, weeksToRace) {
        case (true, 1):
            desc = "Final long run before the race. Run easy and enjoy it. Your fitness is built — this run maintains rhythm, not fitness."
        case (true, _):
            desc = "Taper long run. Shorter than recent runs — correct. Rhythm stays. Volume reduces. Fitness is built."
        case (false, _) where miles >= 16:
            desc = """
Long run: \(Int(miles)) miles at easy effort.

Run at controlled, conversational pace. The long run in Hansons is deliberately restrained — \
not because long runs are unimportant, but because you are running six days per week. \
Arriving at this run on accumulated fatigue is the point. Sixteen miles on tired legs \
prepares your body for the final miles of a marathon.

Do not race this run. The quality sessions did the hard work. This run completes the picture.
"""
        case (false, _) where miles >= 13:
            desc = """
Long run: \(Int(miles)) miles easy.

Start conservatively — your legs carry the week's accumulated fatigue. That is intentional. \
Run in control from start to finish. This develops the fatigue resistance your marathon will demand.
"""
        default:
            desc = """
Long run: \(Int(miles)) miles easy.

Run at genuinely comfortable effort. In Hansons, the long run is one of six runs, not the \
centerpiece. The training effect comes from the combination of all six sessions.
"""
        }

        return TrainingDay(weekday: day, workoutType: .longRun, miles: miles,
                           description: desc,
                           paceNote: "\(easyRange) — easy, controlled, consistent")
    }
}
