import Foundation

// MARK: - Runner Readiness Tier

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

    var qualityIntroCanonical: Int {
        switch self {
        case .rebuilding: return 4
        case .developing: return 3
        case .prepared:   return 2
        case .advanced:   return 1
        }
    }

    var ltIntroCanonical: Int {
        switch self {
        case .rebuilding: return 4
        case .developing: return 3
        case .prepared:   return 2
        case .advanced:   return 1
        }
    }

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
    // NOTE: Hansons has NO planned cutback weeks.
    // Recovery is structural — built into each week via easy days and the
    // single Friday rest day. Periodic volume drops are Higdon/Pfitz thinking.

    // MARK: - Base Mileage Recommendation

    static func baseRecommendation(for base: Double) -> String? {
        switch base {
        case ..<20:
            return "Hansons is built for runners with an established aerobic foundation. Entering from \(Int(base)) mpw, your first 5–6 weeks will be an intentional adaptation phase before the full methodology rhythm takes over. If you have 8+ weeks before starting, building to 25 mpw first will help you get more from the plan."
        case 20..<28:
            return "Your base is developing. The opening 3 weeks focus on establishing the six-day rhythm and durability — full Hansons quality structure begins around week 4. This is a legitimate way to enter the methodology."
        default:
            return nil
        }
    }

    // MARK: - Quality Phase

    enum QualityPhase { case speed, strength }

    // MARK: - Speed Session
    //
    // ARCHITECTURE NOTE: baseMiles is intentionally absent.
    // Total session mileage is always computed from actual workout
    // components: warmup + (reps × repDist) + (reps-1 × recovDist) + cooldown.
    // This ensures description and TrainingDay.miles are always identical.

    struct SpeedSession {
        let reps      : Int
        let repDist   : String
        let recovDist : String

        // Distance in miles for each rep interval
        var repDistMiles: Double {
            switch repDist {
            case "400m":   return 0.25
            case "600m":   return 0.375
            case "800m":   return 0.5
            case "1000m":  return 0.625
            case "1200m":  return 0.75
            case "1 mile": return 1.0
            default:       return 0.5
            }
        }

        // Distance in miles for each recovery jog
        var recovDistMiles: Double {
            switch recovDist {
            case "200m jog": return 0.125
            case "300m jog": return 0.1875
            case "400m jog": return 0.25
            default:          return 0.25
            }
        }

        // Warmup and cooldown are fixed for speed sessions
        static let warmup   : Double = 1.5
        static let cooldown : Double = 1.5

        /// Compute scaled rep count and precise session total from the same scale.
        /// This is the single source of truth — called by BOTH q1Miles() and makeSpeedWorkout().
        func scaled(by scale: Double) -> (reps: Int, totalMiles: Double) {
            let r         = max(1, Int((Double(reps) * scale).rounded()))
            let repMiles  = Double(r) * repDistMiles
            // Recovery between reps: (reps - 1) intervals, none after the final rep
            let recovMiles = Double(max(0, r - 1)) * recovDistMiles
            let total = Self.warmup + repMiles + recovMiles + Self.cooldown
            return (reps: r, totalMiles: total.rounded(toPlaces: 1))
        }
    }

    // MARK: - Strength Session
    //
    // ARCHITECTURE NOTE: baseMiles is intentionally absent.
    // Total = warmup(1mi) + (reps × milesPerRep) + (reps-1 × 0.5mi recovery jog) + cooldown(1mi)
    // The 0.5-mile recovery jog between MP reps reflects authentic Hansons pacing.
    // Single-rep sessions (1×4mi, 1×6mi) have ZERO recovery jogs — correctly yields 6 and 8 miles.

    struct StrengthSession {
        let reps        : Int
        let milesPerRep : Double

        // Hansons strength recovery jog: ~0.5 miles (≈2-3 min easy between MP reps)
        private static let recovJog : Double = 0.5
        static let warmup   : Double = 1.0
        static let cooldown : Double = 1.0

        /// Compute scaled rep count, rep distance, label, and precise session total.
        /// Called by BOTH q1Miles() and makeStrengthWorkout() — same source of truth.
        func scaled(by scale: Double) -> (reps: Int, dist: Double, label: String, totalMiles: Double) {
            let r = max(1, Int((Double(reps) * scale).rounded()))
            let d = max(1.0, (milesPerRep * scale).rounded(toPlaces: 1))
            let repMiles   = Double(r) * d
            let recovMiles = Double(max(0, r - 1)) * Self.recovJog
            let total = Self.warmup + repMiles + recovMiles + Self.cooldown
            let label = "\(r)×\(String(format: "%.1g", d))mi"
            return (reps: r, dist: d, label: label, totalMiles: total.rounded(toPlaces: 1))
        }
    }

    // MARK: - Session Libraries
    //
    // SPEED PHASE: directional progression 400m → 600m → 800m → 1000m → 1200m → mile → sharpen
    // STRENGTH PHASE: directional progression short MP → long MP → taper approach
    //
    // FIX 1 — Speed session indexing:
    // Sessions are now indexed by (canonical - tier.qualityIntroCanonical), NOT (canonical - 1).
    // This ensures every runner tier begins at index 0 (12×400m) on their first real speed session,
    // regardless of how many onboarding weeks preceded it.
    //
    // Old bug: canonical - 1 caused a rebuilding runner (qualityIntroCanonical=4) to land at
    // index 3 (6×1000m) on their very first track session, skipping 400m, 600m, and 800m entirely.
    // Advanced runners were unaffected (qualityIntroCanonical=1 → same as canonical - 1).

    private static let speedSessions: [SpeedSession] = [
        SpeedSession(reps: 12, repDist: "400m",   recovDist: "200m jog"),  // relative index 0
        SpeedSession(reps: 10, repDist: "600m",   recovDist: "200m jog"),  // relative index 1
        SpeedSession(reps: 8,  repDist: "800m",   recovDist: "400m jog"),  // relative index 2
        SpeedSession(reps: 6,  repDist: "1000m",  recovDist: "400m jog"),  // relative index 3
        SpeedSession(reps: 5,  repDist: "1200m",  recovDist: "400m jog"),  // relative index 4
        SpeedSession(reps: 4,  repDist: "1 mile", recovDist: "400m jog"),  // relative index 5
        SpeedSession(reps: 8,  repDist: "600m",   recovDist: "200m jog"),  // relative index 6 (sharpen — advanced only)
        SpeedSession(reps: 10, repDist: "400m",   recovDist: "200m jog"),  // relative index 7 (sharpen — advanced only)
    ]

    private static let strengthSessions: [StrengthSession] = [
        StrengthSession(reps: 6, milesPerRep: 1.0),  // canonical  9: 6×1mi   = 10.5mi total
        StrengthSession(reps: 4, milesPerRep: 1.5),  // canonical 10: 4×1.5mi =  9.5mi total
        StrengthSession(reps: 3, milesPerRep: 2.0),  // canonical 11: 3×2mi   =  9.0mi total
        StrengthSession(reps: 2, milesPerRep: 3.0),  // canonical 12: 2×3mi   =  8.5mi total
        StrengthSession(reps: 1, milesPerRep: 4.0),  // canonical 13: 1×4mi   =  6.0mi total
        StrengthSession(reps: 2, milesPerRep: 3.5),  // canonical 14: 2×3.5mi =  9.5mi total
        StrengthSession(reps: 2, milesPerRep: 4.0),  // canonical 15: 2×4mi   = 10.5mi total
        StrengthSession(reps: 1, milesPerRep: 6.0),  // canonical 16: 1×6mi   =  8.0mi total
        StrengthSession(reps: 3, milesPerRep: 2.0),  // taper ramp-down:       =  9.0mi
        StrengthSession(reps: 4, milesPerRep: 1.0),  // taper short:           = 10.5mi (taper scale reduces this)
    ]

    // MARK: - Quality Scale

    private static func qualityScale(weekMiles: Double) -> Double {
        return min(1.0, max(0.60, weekMiles / (peakWeekly * 0.85)))
    }

    // MARK: - Entry Point

    static func generate(settings: UserSettings) -> [TrainingWeek] {
        let n        = settings.planLength.rawValue
        let taperWks = settings.planType.canonicalTaperWeeks
        let schedule = settings.schedule.validated(for: .hansons)
        let paces    = PaceEngine(goalMinutes: settings.goalTimeMinutes)
        let mileage  = weeklyMileageSchedule(n: n, base: settings.baseMileage,
                                              taperWeeks: taperWks)
        let longRuns = longRunScheduleAdapted(n: n, taperWeeks: taperWks,
                                               weeklyMiles: mileage)

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

    // MARK: - Weekly Mileage Schedule

    static func weeklyMileageSchedule(n: Int, base: Double,
                                       taperWeeks: Int) -> [Double] {
        let peak       = peakWeekly
        let buildWeeks = n - taperWeeks
        let adaptiveStart = min(base * 1.08 + 1.0, peak * 0.95).rounded(toPlaces: 0)
        // No cutback week deduction — Hansons builds steadily, all weeks are effective
        let rawAchievable = adaptiveStart * pow(1.10, Double(buildWeeks))
        let achievablePeak = min(peak, rawAchievable).rounded(toPlaces: 0)

        var result  : [Double] = []
        var current             = adaptiveStart

        for i in 0..<buildWeeks {
            // Steady linear progression — no cutback branches
            let progress     = buildWeeks > 1
                ? Double(i) / Double(buildWeeks - 1) : 1.0
            let smoothTarget = adaptiveStart + (achievablePeak - adaptiveStart) * progress
            let capped = min(smoothTarget, current * 1.10)
            let val    = min(max(capped.rounded(toPlaces: 0), adaptiveStart), achievablePeak)
            result.append(val)
            current = val
        }

        let achievedPeak = result.max() ?? achievablePeak
        let taperPcts: [Double] = taperWeeks == 3
            ? [0.85, 0.72, 0.45] : [0.85, 0.45]
        for pct in taperPcts {
            result.append(max(adaptiveStart, (achievedPeak * pct).rounded(toPlaces: 0)))
        }
        return result
    }

    // MARK: - Long Run Schedule

    static func longRunSchedule(n: Int, taperWeeks: Int) -> [Double] {
        let buildCanonical: [Double] = [
             8,  9, 10, 11, 12, 13, 13, 14,  // wks 1–8:  speed phase
            15, 14, 16, 14, 16, 14, 16, 14   // wks 9–16: strength phase, 3× 16mi peak
        ]
        let buildWeeks = n - taperWeeks
        let offset     = buildCanonical.count - buildWeeks
        let buildSlice = Array(buildCanonical[max(0, offset)...])
            .prefix(buildWeeks)
            .map { min($0, longRunCap) }

        let achievedPeak = buildSlice.max() ?? longRunCap

        let taperLRs: [Double] = taperWeeks == 3
            ? [(achievedPeak * 0.65).rounded(toPlaces: 0),
               (achievedPeak * 0.50).rounded(toPlaces: 0), 0]
            : [(achievedPeak * 0.625).rounded(toPlaces: 0), 0]

        return Array(buildSlice) + taperLRs
    }

    // FIX 3 — Long run phase cap differentiation:
    // Old: flat 35% cap across all build weeks.
    // Problem: Hansons book data shows long runs at ~25% of weekly volume during the speed phase
    //          (weeks 1–8). The 35% cap was too permissive for low-base runners mid-plan,
    //          allowing the long run to consume 40–50% of weekly volume in speed-phase weeks
    //          where cumulative fatigue structure hasn't fully developed yet.
    // Fix: tighter 28% cap during the speed phase (canonical < strengthStart = 9),
    //      relaxed to 35% in the strength phase to allow authentic 16-mile peaks.
    // Note: canonical week number is derived from the array index and plan length:
    //       canonicalWeekNum = i + (19 - n), which equals week + (18 - n) + 1 = 1-indexed.

    static func longRunScheduleAdapted(n: Int, taperWeeks: Int,
                                        weeklyMiles: [Double]) -> [Double] {
        let canonical  = longRunSchedule(n: n, taperWeeks: taperWeeks)
        let buildWeeks = n - taperWeeks

        return canonical.indices.map { i in
            guard i < weeklyMiles.count else { return canonical[i] }
            let lr    = canonical[i]
            let total = weeklyMiles[i]
            guard total > 0 else { return 0.0 }

            // Canonical week number (1-indexed) derived from plan length and array index.
            // For an 18-week plan: i=0 → canonical 1, i=7 → canonical 8, i=8 → canonical 9.
            // For a 16-week plan: i=0 → canonical 3, i=5 → canonical 8, i=6 → canonical 9.
            let canonicalWeekNum = i + (19 - n)
            let isInBuildPhase   = i < buildWeeks
            let isSpeedPhase     = isInBuildPhase && canonicalWeekNum < strengthStart
            let capPct           = isSpeedPhase ? 0.28 : 0.35
            let cap              = max(6.0, (total * capPct).rounded(toPlaces: 0))
            return min(lr, cap)
        }
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

    // MARK: - Session Mileage (single source of truth)
    //
    // q1Miles() uses the SAME scaled() method as the day makers.
    // Budget allocation and displayed mileage are always synchronized.
    //
    // FIX 1 (continued) — speedRelativeIdx parameter:
    // q1Miles now receives the pre-computed session index so budget estimation
    // uses the same session the day maker will actually produce.

    private static func q1Miles(canonical      : Int,
                                  speedRelativeIdx: Int,
                                  phase          : QualityPhase,
                                  scale          : Double,
                                  isTaper        : Bool) -> Double {
        let effectiveScale = isTaper ? scale * 0.75 : scale
        switch phase {
        case .speed:
            let idx = max(0, min(speedRelativeIdx, speedSessions.count - 1))
            return speedSessions[idx].scaled(by: effectiveScale).totalMiles
        case .strength:
            let idx = max(0, min(canonical - strengthStart, strengthSessions.count - 1))
            return strengthSessions[idx].scaled(by: effectiveScale).totalMiles
        }
    }

    // Returns the prescribed MP *segment* miles only.
    // Warmup (1.5 mi) and cooldown (1.5 mi) are always additive — never carved
    // from the quality segment. Total workout = segment + 3.0 mi.
    //
    // ARCHITECTURE: Canonical week number is the PRIMARY driver — matching the
    // fixed weekly progression in Luke Humphrey's Hansons Marathon Method (Advanced).
    // Volume acts only as a SAFETY CAP for runners below full Hansons load.
    // The old weekMiles * 0.14 formula was wrong: at 55 mpw peak, 55 × 0.14 = 7.7 mi —
    // the runner never reaches 10 miles because the cap was below the ceiling.
    //
    // Hansons Thursday MP progression (canonical week → prescribed miles):
    //   1–3 → 3 mi,  4–5 → 4 mi,  6–7 → 5 mi,  8 → 6 mi
    //   9–10 → 7 mi, 11–12 → 8 mi, 13 → 9 mi, 14+ → 10 mi
    //
    // Volume safety cap at 20 % of weekly volume:
    //   At 55 mpw (Hansons peak), 10/55 = 18.2 % → full prescription reached.
    //   At 40 mpw, cap = 8 mi; at 30 mpw, cap = 6 mi.
    private static func tempoSegmentMiles(canonical: Int, weekMiles: Double,
                                           isTaper: Bool) -> Double {
        // Taper: scale with volume (0.175 factor) so the session naturally tapers
        // with the rest of the week. Floor at 3 mi, ceiling at 8 mi.
        //   First taper  (~85 % peak = 46.75 mi): 46.75 × 0.175 = 8.2 → 8 mi ✓
        //   Second taper (~72 % peak = 39.6 mi):  39.6  × 0.175 = 6.9 mi ✓
        //   Third taper  (~45 % peak = 24.75 mi): 24.75 × 0.175 = 4.3 mi ✓
        if isTaper {
            return min(8.0, max(3.0, (weekMiles * 0.175).rounded(toPlaces: 1)))
        }

        // Canonical Hansons prescription — fixed per-week distances from the book.
        let prescribed: Double
        switch canonical {
        case ..<4:    prescribed = 3.0   // Canonical 1–3 (early speed): establish MP rhythm
        case 4...5:   prescribed = 4.0   // Canonical 4–5 (speed): build confidence at pace
        case 6...7:   prescribed = 5.0   // Canonical 6–7 (late speed): 5 solid miles at MP
        case 8:       prescribed = 6.0   // Canonical 8 (speed → strength bridge)
        case 9...10:  prescribed = 7.0   // Canonical 9–10 (early strength)
        case 11...12: prescribed = 8.0   // Canonical 11–12 (mid strength)
        case 13:      prescribed = 9.0   // Canonical 13 (late strength)
        default:      prescribed = 10.0  // Canonical 14+ (peak strength): full Hansons 10-mi MP
        }

        // Volume safety cap: max 20 % of weekly volume.
        // Ensures low-volume runners are not overloaded; full-volume runners always
        // reach the canonical prescription (10 / 55 = 18.2 %).
        let volumeCap = max(3.0, weekMiles * 0.20)
        return min(prescribed, volumeCap).rounded(toPlaces: 1)
    }

    private static func onboardingRunMiles(weekMiles: Double) -> Double {
        return max(5.0, weekMiles * 0.18).rounded(toPlaces: 1)
    }

    // MARK: - Week Builder
    //
    // FIX 1 (continued) — speedRelativeIdx computation:
    // Computed here where tier is available, then threaded through to q1Miles()
    // and makeSpeedWorkout(). This is the only place the index needs to be derived.

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
        let tier          = RunnerReadinessTier.from(base: baseMileage)
        let inOnboarding  = canonical < tier.qualityIntroCanonical && !isTaper
        let scale         = qualityScale(weekMiles: totalMiles)
        let trainingDepth = Double(weekNumber) / Double(totalWeeks)

        // FIX 1 — Speed session relative index.
        // speedRelativeIdx counts from 0 at the runner's first real speed session,
        // regardless of their tier's onboarding period. Every tier starts at 12×400m.
        // Advanced (qualityIntroCanonical=1): canonical 1 → idx 0, canonical 8 → idx 7 (full sharpen).
        // Rebuilding (qualityIntroCanonical=4): canonical 4 → idx 0, canonical 8 → idx 4 (5×1200m peak).
        let speedPhaseEntryCanonical = tier.qualityIntroCanonical
        let speedRelativeIdx         = max(0, canonical - speedPhaseEntryCanonical)

        let restSet = Set(schedule.restDays)
        let lrDay   = schedule.longRunDay
        let q1Day   = schedule.workoutDay1
        let q2Day   = schedule.workoutDay2

        let isRaceWeek = isTaper && longMiles <= 0
        if isRaceWeek {
            let specialDays: Set<Weekday> = restSet.union([lrDay, q1Day, q2Day])
            let days = Weekday.allCases.map { day -> TrainingDay in
                if specialDays.contains(day) {
                    return makeRest(day, isTaper: true)
                } else {
                    return makeEasyRun(day, miles: 3.0, weekNumber: weekNumber,
                                       isTaper: true, workoutType: .easy,
                                       inOnboarding: false, paces: paces)
                }
            }
            return TrainingWeek(weekNumber: weekNumber, phase: phase,
                                phaseLabel: phaseLabel, days: days)
        }

        let longM = min(longMiles, longRunCap)

        let rawQ1  = inOnboarding
            ? onboardingRunMiles(weekMiles: totalMiles)
            : q1Miles(canonical: canonical, speedRelativeIdx: speedRelativeIdx,
                      phase: qualityPhase, scale: scale, isTaper: isTaper)

        // Q2: prescribed MP segment. Warmup/cooldown are additive — not subtracted
        // from the quality miles. Total Q2 workout = segment + 1.5 warmup + 1.5 cooldown.
        let q2Seg    = tempoSegmentMiles(canonical: canonical, weekMiles: totalMiles, isTaper: isTaper)
        let q2Total  = (q2Seg + 3.0).rounded(toPlaces: 1)

        // In Hansons, quality sessions are non-negotiable. Easy days flex to fit.
        // Cap Q1 only enough to keep easy days at a minimum of 3 miles each.
        let minEasyTotal = 3.0 * 3.0
        let safeQ1   = min(rawQ1, max(0, totalMiles - longM - q2Total - minEasyTotal))
        let easyBudget   = max(minEasyTotal, totalMiles - longM - safeQ1 - q2Total)
        let easyPerDay   = (easyBudget / 3.0).rounded(toPlaces: 1)

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
                                 isTaper: isTaper, trainingDepth: trainingDepth, paces: paces)
            } else if day == q1Day {
                if inOnboarding {
                    td = makeOnboardingRun(day, miles: safeQ1, canonical: canonical,
                                           tier: tier, weekNumber: weekNumber, paces: paces)
                } else {
                    switch qualityPhase {
                    case .speed:
                        td = makeSpeedWorkout(day,
                                              canonical:        canonical,
                                              speedRelativeIdx: speedRelativeIdx,
                                              scale:            scale,
                                              isTaper:          isTaper,
                                              trainingDepth:    trainingDepth,
                                              paces:            paces)
                    case .strength:
                        td = makeStrengthWorkout(day, canonical: canonical, scale: scale,
                                                  isTaper: isTaper, trainingDepth: trainingDepth,
                                                  paces: paces)
                    }
                }
            } else if day == q2Day {
                td = makeTempoRun(day, canonical: canonical, mpSegment: q2Seg,
                                   isTaper: isTaper, trainingDepth: trainingDepth, paces: paces)
            } else {
                td = easyPerDay > 0
                    ? makeEasyRun(day, miles: easyPerDay, weekNumber: weekNumber,
                                   isTaper: isTaper, workoutType: earlyEasyType,
                                   inOnboarding: inOnboarding, paces: paces)
                    : makeRest(day, isTaper: isTaper)
            }

            days.append(td)
        }

        return TrainingWeek(weekNumber: weekNumber, phase: phase,
                            phaseLabel: phaseLabel, days: days)
    }

    // MARK: - Day Makers

    static func makeRest(_ day: Weekday, isTaper: Bool) -> TrainingDay {
        let desc = isTaper
            ? "Rest day. Your one day off. The taper is working even when it does not feel like it."
            : "Rest day. One day off in a six-day week is Hansons' design. The cumulative fatigue that builds across the other six days is the mechanism. This rest allows adaptation without undercutting the load."
        return TrainingDay(weekday: day, workoutType: .rest, miles: 0,
                           description: desc, paceNote: "—")
    }

    // MARK: - Speed Workout
    //
    // FIX 1 (continued) — speedRelativeIdx replaces (canonical - 1) as the session index.
    // Description and TrainingDay.miles are derived from the same scaled() call.

    static func makeSpeedWorkout(_ day          : Weekday,
                                  canonical     : Int,
                                  speedRelativeIdx: Int,
                                  scale         : Double,
                                  isTaper       : Bool,
                                  trainingDepth : Double,
                                  paces         : PaceEngine) -> TrainingDay {
        let effectiveScale = isTaper ? scale * 0.75 : scale
        let idx            = max(0, min(speedRelativeIdx, speedSessions.count - 1))
        let session        = speedSessions[idx]
        let (scaledReps, totalMiles) = session.scaled(by: effectiveScale)
        let speedPace = PaceEngine.format(paces.hansonsSpeed)
        let tapNote   = isTaper ? "\n\nTaper week — session is already shortened. Preserve pace." : ""

        let depthNote: String
        switch trainingDepth {
        case ..<0.30:
            depthNote = "Speed phase. These sessions develop running economy — the efficiency at faster paces that directly lowers the energy cost of marathon pace in the strength phase ahead."
        case 0.30..<0.65:
            depthNote = "Mid-speed phase. Economy is developing. The interval distances are increasing — that is intentional. You are bridging from raw speed toward aerobic power."
        default:
            depthNote = "Final speed weeks. Returning to shorter intervals to sharpen leg turnover before the methodology transitions to marathon-pace strength work."
        }

        let warmup   = Int(SpeedSession.warmup)
        let cooldown = Int(SpeedSession.cooldown)

        let desc = """
Speed workout: \(scaledReps)×\(session.repDist) at 5K pace, \(session.recovDist) recovery.

\(warmup) mile warmup (easy) · \(scaledReps)×\(session.repDist) at 5K pace (\(speedPace)/mi) · \
\(session.recovDist) between reps · \(cooldown) mile cooldown (easy) · \
Total: \(String(format: "%.1f", totalMiles)) miles\(tapNote)

Consistent splits — not a time trial. If you are positive-splitting, you went out too fast. \
The goal is repeatable, controlled 5K effort across every rep.

\(depthNote)
"""
        // qualityMiles = interval miles only (reps × rep distance, no warmup/cooldown/recovery)
        let intervalMiles = (Double(scaledReps) * session.repDistMiles).rounded(toPlaces: 1)
        return TrainingDay(weekday: day, workoutType: .speedWork,
                           miles: totalMiles,
                           description: desc,
                           paceNote: "~\(speedPace)/mi — 5K pace, controlled and repeatable",
                           qualityMiles: intervalMiles)
    }

    // MARK: - Strength Workout
    //
    // Unchanged — strength session math was correct in the prior version.
    // The 0.5-mile recovery jog between reps is explicit in both calculation and description.
    // Single-rep sessions (1×4mi, 1×6mi) correctly show 0 recovery jogs.

    static func makeStrengthWorkout(_ day          : Weekday,
                                     canonical     : Int,
                                     scale         : Double,
                                     isTaper       : Bool,
                                     trainingDepth : Double,
                                     paces         : PaceEngine) -> TrainingDay {
        let effectiveScale  = isTaper ? scale * 0.75 : scale
        let idx             = max(0, min(canonical - strengthStart, strengthSessions.count - 1))
        let session         = strengthSessions[idx]
        let (scaledReps, scaledDist, scaledLabel, totalMiles) = session.scaled(by: effectiveScale)

        let targetPace     = PaceEngine.format(paces.hansonsStrengthPace)
        let paceRange      = paces.rangeString(paces.hansonsStrength)
        let goalMP         = PaceEngine.format(paces.MP)

        let warmup   = Int(StrengthSession.warmup)
        let cooldown = Int(StrengthSession.cooldown)
        let breakdownParts: [String] = [
            "\(warmup) mi warmup (easy)",
            scaledReps == 1
                ? "\(String(format: "%.1g", scaledDist)) mi at \(targetPace)/mi"
                : "\(scaledLabel) at \(targetPace)/mi — 0.5 mi easy jog between reps",
            "\(cooldown) mi cooldown (easy)",
        ]
        let breakdown = breakdownParts.joined(separator: " · ")

        let tapNote = isTaper
            ? "\n\nTaper week — volume reduced, pace unchanged. Run every rep at the same \(targetPace)/mi target."
            : ""

        let depthNote: String
        switch trainingDepth {
        case ..<0.45:
            depthNote = "You have entered the strength phase. The methodology shifts from building economy (speed work) to developing marathon-pace specificity. Running 10 seconds per mile faster than your goal pace on accumulated weekly fatigue is the mechanism — it trains your body to hold goal pace when it counts."
        case 0.45..<0.70:
            depthNote = "Cumulative fatigue is accumulating across your weeks of training. Running at \(targetPace)/mi on tired legs is building the pace familiarity that makes race day feel controlled. Your goal marathon pace (\(goalMP)/mi) will feel slower than this — that is the point."
        default:
            depthNote = "Late-block strength sessions are your most race-specific work. Your body recognizes \(targetPace)/mi now. The accumulated fatigue you carry into this session is exactly what the second half of a marathon requires you to manage."
        }

        let desc = """
Strength workout: \(scaledLabel) at \(targetPace)/mi.

\(breakdown) · Total: \(String(format: "%.1f", totalMiles)) miles\(tapNote)

Target: \(targetPace)/mi — 10 seconds per mile faster than your goal marathon pace (\(goalMP)/mi). \
This is not marathon pace. It is slightly quicker, which trains your aerobic system to make \
true marathon pace feel sustainable under fatigue.

Run each rep at the target pace. Recovery jog should be genuinely easy — \
the effort of the rep comes from the pace, not from grinding through exhaustion.

\(depthNote)
"""
        // qualityMiles = MP rep miles only (reps × scaledDist, no warmup/cooldown/recovery jogs)
        let repMiles = (Double(scaledReps) * scaledDist).rounded(toPlaces: 1)
        return TrainingDay(weekday: day, workoutType: .strengthMP,
                           miles: totalMiles,
                           description: desc,
                           paceNote: "\(targetPace)/mi — 10 sec/mi faster than MP (\(paceRange) acceptable)",
                           qualityMiles: repMiles)
    }

    // MARK: - Tempo Run
    //
    // Architecture: mpSegment is the prescribed quality miles at marathon pace.
    // Warmup (1.5 mi) and cooldown (1.5 mi) are always additive.
    // TrainingDay.miles = mpSegment + 3.0 — the runner's total workout distance.
    //
    // Verification (55-mile peak week, canonical 14):
    //   mpSegment = 10.0 mi → total = 10.0 + 1.5 + 1.5 = 13.0 mi ✓
    // Verification (early speed week, canonical 5):
    //   mpSegment = 4.0 mi → total = 4.0 + 1.5 + 1.5 = 7.0 mi ✓

    // mpSegment: the prescribed quality distance at marathon pace.
    // Warmup (1.5 mi) and cooldown (1.5 mi) are additive — total stored = mpSegment + 3.0.
    static func makeTempoRun(_ day          : Weekday,
                               canonical     : Int,
                               mpSegment     : Double,
                               isTaper       : Bool,
                               trainingDepth : Double,
                               paces         : PaceEngine) -> TrainingDay {
        let tempoPace   = PaceEngine.format(paces.hansonsTempo)
        let warmup      : Double = 1.5
        let cooldown    : Double = 1.5
        let actualTotal : Double = (warmup + mpSegment + cooldown).rounded(toPlaces: 1)

        let tapNote = isTaper
            ? "Taper week — \(String(format: "%.0f", mpSegment)) miles at marathon pace. Duration reduces, pace does not."
            : ""

        let phaseContext: String
        switch canonical {
        case ..<strengthStart:
            phaseContext = "Speed phase tempo. Q1 (Tuesday) builds running economy at 5K pace. This session develops marathon-pace fluency — learning to hold goal pace on accumulated weekly fatigue before the distance reaches its peak."
        case strengthStart..<13:
            phaseContext = "Strength phase tempo. On Tuesday you ran 10 seconds per mile faster than MP (\(PaceEngine.format(paces.hansonsStrengthPace))/mi). Today locks in true marathon pace. The distance will increase each week until you are sustaining 10 miles at race pace — the closest simulation to the second half of a marathon the plan provides."
        default:
            // canonical 13 = 9 mi; 14+ = 10 mi — the full Hansons peak prescription
            phaseContext = "Peak Hansons tempo. This is the full prescription — \(String(format: "%.0f", mpSegment)) miles at marathon pace on accumulated training fatigue. There is no closer simulation of the second half of your race. Hold pace from mile one. If you go out under control, you finish under control."
        }

        let desc = """
Hansons Tempo: \(String(format: "%.1f", mpSegment)) mi at marathon pace · \(String(format: "%.1f", actualTotal)) mi total with warmup/cooldown.

1.5 mi easy warmup · \(String(format: "%.1f", mpSegment)) mi at \(tempoPace)/mi · \
1.5 mi easy cooldown · Total: \(String(format: "%.1f", actualTotal)) miles

\(tapNote.isEmpty ? "" : tapNote + "\n\n")Target: \(tempoPace)/mi — your goal marathon pace. \
Sustained and controlled. Not a race, not a time trial. \
You should be able to hold this pace without forcing it. \
Breathing is deliberate but not desperate.

\(phaseContext)
"""
        return TrainingDay(weekday: day, workoutType: .tempoRun, miles: actualTotal,
                           description: desc,
                           paceNote: "\(tempoPace)/mi — marathon pace, \(String(format: "%.0f", mpSegment)) mi sustained",
                           qualityMiles: mpSegment)
    }

    // MARK: - Onboarding Run

    static func makeOnboardingRun(_ day      : Weekday,
                                   miles     : Double,
                                   canonical : Int,
                                   tier      : RunnerReadinessTier,
                                   weekNumber: Int,
                                   paces     : PaceEngine) -> TrainingDay {
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

This introduces effort variation before structured speed sessions begin.
"""
                return TrainingDay(weekday: day, workoutType: .easy, miles: miles,
                                   description: desc,
                                   paceNote: "Easy with occasional 30–60 sec pickups")
            }

        case .developing:
            let desc = """
Fartlek run: \(String(format: "%.0f", miles)) miles with 4–6 unstructured surges.

Run easy for the main distance. Insert 4–6 surges of 45–90 seconds at comfortably quick effort. \
Full easy running recovery between each.

Next week, these surges become structured speed intervals.
"""
            return TrainingDay(weekday: day, workoutType: .easy, miles: miles,
                               description: desc,
                               paceNote: "Easy with 4–6 × 45–90-sec surges")

        case .prepared:
            let desc = """
Introductory speed session: \(String(format: "%.0f", miles)) miles — warmup, abbreviated intervals, cooldown.

Warmup 1.5 miles easy, then 4 × 600m at 5K pace with 300m jog recovery, cooldown 1.5 miles easy.

Your base is solid. This session establishes the rhythm before full volume begins.
"""
            return TrainingDay(weekday: day, workoutType: .speedWork, miles: miles,
                               description: desc,
                               paceNote: "5K pace for intervals — abbreviated opening session")

        case .advanced:
            return makeEasyRun(day, miles: miles, weekNumber: weekNumber,
                                isTaper: false, workoutType: .easy,
                                inOnboarding: false, paces: paces)
        }
    }

    // MARK: - Easy Run

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

    // MARK: - Long Run

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
