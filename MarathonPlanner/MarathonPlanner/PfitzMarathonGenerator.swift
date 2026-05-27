import Foundation

// MARK: - Pfitz Marathon Generator
//
// Pete Pfitzinger's Advanced Marathoning — 18/55 — with corrected progression engine.
//
// THE CORE BUG THAT WAS FIXED (previous session):
//   Previous: taper % applied to peakWeekly (55).
//   A 25 mpw runner building to 40 mpw got a 43 mpw "taper week 1."
//   Fix: taper applies to achievedPeak (actual max in build schedule).
//
// BUGS FIXED THIS SESSION:
//
// FIX 1 — Recovery day count:
//   `recovPerDay = budgetAfterLT / 2.0` hardcoded denominator assumed 2 recovery days.
//   A standard Pfitz schedule (1 rest day) produces 3 recovery days: Sun, Mon, Wed.
//   3 × (budget/2) = 1.5 × budget — ~3-6 mile overflow at peak week.
//   Fix: count actual recovery days from schedule; divide by that count.
//
// FIX 2 — LT description arithmetic:
//   Description displayed "~2mi warmup · X mi LT · ~2mi cooldown = Y miles" but when
//   the budget cap compressed ltTotal, the breakdown summed to Y+1 or Y+2.
//   Fix: derive actual warmup/cooldown from (ltTotal - ltAtPace); display those values.
//
// FIX 3 — Adjacent day detection at week boundary:
//   abs(rawValue1 - rawValue2) == 1 failed for Saturday(7)/Sunday(1) adjacency (diff=6).
//   Fix: also check diff == 6 (circular week).
//
// THE DEFINING FEATURE — MEDIUM-LONG RUN:
//   Present EVERY week without exception. Volume scales with weekly mileage.
//   Never absent. The habit is non-negotiable. The distance is proportional.

struct PfitzMarathonGenerator {

    // MARK: - Constants

    private static let peakWeekly       : Double = 55
    private static let longRunPeak      : Double = 22
    private static let raceSpecificStart: Int    = 13
    private static let ltPhaseStart     : Int    = 7
    private static let cutbackWeeks     : Set<Int> = [6, 11]  // canonical Pfitz cutbacks
    private static let cutbackCount     : Int    = 2

    // MARK: - Base Mileage Recommendation

    static func baseRecommendation(for base: Double) -> String? {
        switch base {
        case ..<25:
            return "Pfitz 18/55 is built around aerobic density that requires a real foundation. Entering from \(Int(base)) mpw, your first 4–5 weeks are an intentional onboarding phase before the full medium-long run + LT + long run structure becomes viable. Consider whether the Higdon Intermediate plan — which builds that foundation — might be a better starting point."
        case 25..<35:
            return "Your base is developing. The first 2–3 weeks use general aerobic runs in place of LT sessions while your body adapts to the Pfitz weekly density. By week 4, the full structure begins. This is a legitimate way to enter — just be conservative with early pacing."
        case 35..<40:
            return "A solid base for Pfitz. The first week uses a slightly lighter LT session before canonical volume begins. You will feel the plan's full density within 2 weeks."
        default:
            return nil
        }
    }

    // MARK: - Entry Point

    static func generate(settings: UserSettings) -> [TrainingWeek] {
        let n        = settings.planLength.rawValue
        let taperWks = settings.planType.canonicalTaperWeeks
        let schedule = settings.schedule.validated(for: .pfitz)
        let paces    = PaceEngine(goalMinutes: settings.goalTimeMinutes)
        let mileage  = weeklyMileageSchedule(n: n, base: settings.baseMileage,
                                              taperWeeks: taperWks)
        let longRuns = longRunSchedule(n: n, taperWeeks: taperWks,
                                        base: settings.baseMileage)

        var weeks: [TrainingWeek] = []
        for i in 0..<n {
            let wk        = i + 1
            let canonical = wk + (18 - n)
            let isTap     = wk > n - taperWks
            let taperPos  = wk - (n - taperWks)
            let (tPhase, phaseLabel) = phaseInfo(week: wk, total: n,
                                                  taperWeeks: taperWks)

            weeks.append(buildWeek(
                weekNumber:  wk,
                canonical:   canonical,
                phase:       tPhase,
                phaseLabel:  phaseLabel,
                totalMiles:  mileage[i],
                longMiles:   longRuns[i],
                schedule:    schedule,
                isTaper:     isTap,
                taperPos:    taperPos,
                taperWeeks:  taperWks,
                totalWeeks:  n,
                baseMileage: settings.baseMileage,
                paces:       paces
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

        let adaptiveStart = min(base * 1.08 + 1.0, peak * 0.95)
            .rounded(toPlaces: 0)

        let effectiveBuildWeeks = Double(buildWeeks - cutbackCount)
        let rawAchievable = adaptiveStart * pow(1.10, effectiveBuildWeeks)
        let achievablePeak = min(peak, rawAchievable).rounded(toPlaces: 0)

        var result  : [Double] = []
        var current             = adaptiveStart

        for i in 0..<buildWeeks {
            let wk        = i + 1
            let canonical = wk + (18 - n)

            let progress     = buildWeeks > 1
                ? Double(i) / Double(buildWeeks - 1)
                : 1.0
            let smoothTarget = adaptiveStart + (achievablePeak - adaptiveStart) * progress

            if cutbackWeeks.contains(canonical) {
                let val = max(adaptiveStart, (current * 0.85).rounded(toPlaces: 0))
                result.append(val)
                // current does NOT update on cutbacks
            } else {
                let capped = min(smoothTarget, current * 1.09)
                let val    = min(max(capped.rounded(toPlaces: 0), adaptiveStart),
                                 achievablePeak)
                result.append(val)
                current = val
            }
        }

        let achievedPeak = result.max() ?? achievablePeak
        let taperPcts: [Double] = taperWeeks == 3
            ? [0.85, 0.70, 0.45]
            : [0.78, 0.45]
        for pct in taperPcts {
            result.append(max(adaptiveStart, (achievedPeak * pct).rounded(toPlaces: 0)))
        }

        return result
    }

    // MARK: - Adaptive Long Run Schedule

    static func longRunSchedule(n: Int, taperWeeks: Int, base: Double) -> [Double] {
        let tier   = RunnerReadinessTier.from(base: base)
        let offset = 18 - n

        if tier == .advanced {
            let canonical18: [Double] = [
                16, 17, 17, 18, 18, 15,
                18, 19, 20, 20, 17,
                20, 22, 22, 22, 18, 15, 0
            ]
            let adjusted = offset > 0
                ? Array(canonical18.dropFirst(min(offset, canonical18.count)))
                : canonical18
            let buildSlice = Array(adjusted.prefix(n - taperWeeks))
            let achievedPeak = buildSlice.max() ?? longRunPeak
            let taperLRs: [Double] = taperWeeks == 3
                ? [(achievedPeak * 0.72).rounded(toPlaces: 0),
                   (achievedPeak * 0.54).rounded(toPlaces: 0), 0]
                : [(achievedPeak * 0.68).rounded(toPlaces: 0), 0]
            return buildSlice + taperLRs
        }

        let longStart = max(base * tier.longRunStartFraction, 8.0).rounded(toPlaces: 0)
        let buildWeeks = n - taperWeeks

        var schedule: [Double] = []
        var current = longStart

        for i in 0..<buildWeeks {
            let wk        = i + 1
            let canonical = wk + offset
            let isCutback = cutbackWeeks.contains(canonical)

            if isCutback {
                let val = max(longStart, (current - 2.0)).rounded(toPlaces: 0)
                schedule.append(val)
            } else {
                let progress = Double(i) / Double(max(1, buildWeeks - 1))
                let target   = longStart + (longRunPeak - longStart) * progress
                let next     = min(target.rounded(toPlaces: 0),
                                   min(current + 2.0, longRunPeak))
                schedule.append(next)
                current = next
            }
        }

        let achievedLongPeak = schedule.max() ?? longStart
        let taperLRs: [Double] = taperWeeks == 3
            ? [(achievedLongPeak * 0.72).rounded(toPlaces: 0),
               (achievedLongPeak * 0.54).rounded(toPlaces: 0), 0]
            : [(achievedLongPeak * 0.68).rounded(toPlaces: 0), 0]

        return schedule + taperLRs
    }

    // MARK: - Phase Info

    static func phaseInfo(week: Int, total: Int,
                           taperWeeks: Int) -> (TrainingPhase, String) {
        let isTap     = week > total - taperWeeks
        let canonical = week + (18 - total)

        if isTap                         { return (.taper, "Taper")                   }
        if canonical < ltPhaseStart      { return (.base,  "Endurance Phase")         }
        if canonical < raceSpecificStart { return (.build, "Lactate Threshold Phase") }
        return                             (.build, "Marathon Specific")
    }

    // MARK: - Stress-Aware MLR Day
    //
    // FIX 3 — Adjacent day detection at week boundary.
    //
    // Old: abs(ltDay.rawValue - mwDay.rawValue) == 1
    //   Fails when days are at the week boundary (e.g., Saturday=7, Sunday=1).
    //   abs(7 - 1) = 6 — not detected as adjacent. Saturday LT + Sunday MLR got no correction.
    //
    // Fix: check diff == 1 OR diff == 6 (circular week with rawValues 1–7).

    private static func effectiveMlrDay(schedule: UserSchedule) -> Weekday {
        let ltDay    = schedule.workoutDay1
        let mwDay    = schedule.midweekLongDay
        let diff     = abs(ltDay.rawValue - mwDay.rawValue)
        let adjacent = diff == 1 || diff == 6   // FIX 3: handles week boundary wrap-around
        guard adjacent else { return mwDay }
        let shiftedRaw = (mwDay.rawValue % 7) + 1
        guard let shifted = Weekday(rawValue: shiftedRaw) else { return mwDay }
        let taken = Set([schedule.longRunDay, ltDay] + schedule.restDays)
        return taken.contains(shifted) ? mwDay : shifted
    }

    // MARK: - Budget-First Session Allocation
    //
    // FIX 1 — Recovery day count is now a parameter.
    //
    // Old: `recovPerDay = budgetAfterLT / 2.0` (hardcoded denominator).
    //   Assumed 2 recovery days. Standard Pfitz schedule (1 rest day) has
    //   3 recovery days (e.g., Sunday, Monday, Wednesday). Result: 3 × (budget/2)
    //   = 1.5 × budget → ~3-6 mile overflow at peak every week.
    //
    // Fix: recovDayCount is computed in buildWeek from the actual schedule
    //   (7 days − rest days − lrDay − ltDay − mlrDay), then passed here.
    //   budgetAfterLT / Double(recovDayCount) gives correct per-day allocation.

    private struct WeekAllocation {
        let longM      : Double
        let mlrM       : Double
        let ltTotal    : Double
        let ltAtPace   : Double
        let recovPerDay: Double
    }

    private static func allocate(totalMiles  : Double,
                                  longMiles   : Double,
                                  canonical   : Int,
                                  isTaper     : Bool,
                                  taperWeeks  : Int,
                                  taperPos    : Int,
                                  recovDayCount: Int) -> WeekAllocation {   // FIX 1: added param
        let longM = min(longMiles, longRunPeak)
        let budgetAfterLong = max(0, totalMiles - longM)

        let targetMLR = rawMlrMiles(canonical: canonical, weekMiles: totalMiles,
                                     isTaper: isTaper, taperWeeks: taperWeeks,
                                     taperPos: taperPos)
        let mlrM = min(targetMLR, budgetAfterLong * 0.45).rounded(toPlaces: 1)
        let budgetAfterMLR = max(0, budgetAfterLong - mlrM)

        let (targetLTTotal, targetLTAtPace) = rawLtWorkout(canonical: canonical,
                                                             weekMiles: totalMiles,
                                                             isTaper: isTaper)
        let ltTotal    = min(targetLTTotal, budgetAfterMLR * 0.60).rounded(toPlaces: 1)
        let ltFraction = targetLTTotal > 0 ? targetLTAtPace / targetLTTotal : 0.5
        let ltAtPace   = (ltTotal * ltFraction).rounded(toPlaces: 1)
        let budgetAfterLT = max(0, budgetAfterMLR - ltTotal)

        // FIX 1: use recovDayCount (from schedule) instead of hardcoded 2.
        let safeCount   = max(1, recovDayCount)
        let recovPerDay = budgetAfterLT > 0
            ? (budgetAfterLT / Double(safeCount)).rounded(toPlaces: 1)
            : 0.0

        return WeekAllocation(longM: longM, mlrM: mlrM, ltTotal: ltTotal,
                               ltAtPace: ltAtPace, recovPerDay: recovPerDay)
    }

    private static func rawMlrMiles(canonical: Int, weekMiles: Double,
                                     isTaper: Bool, taperWeeks: Int,
                                     taperPos: Int) -> Double {
        if isTaper {
            switch taperPos {
            case 1: return (weekMiles * 0.28).rounded(toPlaces: 0)
            case 2: return (weekMiles * 0.24).rounded(toPlaces: 0)
            default: return (weekMiles * 0.20).rounded(toPlaces: 0)
            }
        }
        let canonical_: Double
        switch canonical {
        case ..<5:    canonical_ = 11.0
        case 5...6:   canonical_ = 12.0
        case 7...9:   canonical_ = 13.0
        case 10...12: canonical_ = 15.0
        case 13...15: canonical_ = 16.0
        default:      canonical_ = 13.0
        }
        return min(canonical_, max(weekMiles * 0.28, 9.0)).rounded(toPlaces: 0)
    }

    private static func rawLtWorkout(canonical: Int,
                                      weekMiles: Double,
                                      isTaper: Bool) -> (total: Double, atPace: Double) {
        if isTaper {
            let lt = max(3.0, weekMiles * 0.09)
            return (total: lt + 4.0, atPace: lt)
        }
        let canonical_: Double
        switch canonical {
        case ..<5:    canonical_ = 4.0
        case 5...6:   canonical_ = 5.0
        case 7...9:   canonical_ = 5.0
        case 10...12: canonical_ = 6.0
        case 13...15: canonical_ = 7.0
        default:      canonical_ = 5.0
        }
        let lt = min(canonical_, max(weekMiles * 0.12, 3.0)).rounded(toPlaces: 1)
        return (total: lt + 4.0, atPace: lt)
    }

    private static func mpFinishMiles(canonical: Int, weekMiles: Double) -> Int? {
        switch canonical {
        case 14: return max(4, Int(weekMiles * 0.11))
        case 15: return max(5, Int(weekMiles * 0.14))
        case 16: return max(6, Int(weekMiles * 0.17))
        default: return nil
        }
    }

    // MARK: - Week Builder
    //
    // FIX 1 (continued): Compute recovDayCount before calling allocate.
    // specialDays = rest + lrDay + ltDay + mlrDay.
    // recoveryDays = all weekdays not in specialDays.
    // recovDayCount is passed to allocate so per-day recovery is always budget-accurate.

    static func buildWeek(
        weekNumber  : Int,
        canonical   : Int,
        phase       : TrainingPhase,
        phaseLabel  : String,
        totalMiles  : Double,
        longMiles   : Double,
        schedule    : UserSchedule,
        isTaper     : Bool,
        taperPos    : Int,
        taperWeeks  : Int,
        totalWeeks  : Int,
        baseMileage : Double,
        paces       : PaceEngine
    ) -> TrainingWeek {
        let tier            = RunnerReadinessTier.from(base: baseMileage)
        let inLTOnboarding  = canonical < tier.ltIntroCanonical && !isTaper
        let trainingDepth   = Double(weekNumber) / Double(totalWeeks)

        let restSet = Set(schedule.restDays)
        let lrDay   = schedule.longRunDay
        let ltDay   = schedule.workoutDay1
        let mlrDay  = effectiveMlrDay(schedule: schedule)

        // FIX 1: Count actual recovery days from this schedule.
        // This is the denominator for per-day recovery mileage.
        // Pfitz with 1 rest day (standard): Sun, Mon, Wed = 3 recovery days.
        // Pfitz with 2 rest days: 2 recovery days. Formula handles both.
        let specialDays   : Set<Weekday> = restSet.union([lrDay, ltDay, mlrDay])
        let recoveryDays                  = Weekday.allCases.filter { !specialDays.contains($0) }
        let recovDayCount                 = recoveryDays.count

        let isRaceWeek = isTaper && longMiles <= 0
        if isRaceWeek {
            let specialRaceWeekDays: Set<Weekday> = restSet.union([lrDay, ltDay, mlrDay])
            let days = Weekday.allCases.map { day -> TrainingDay in
                if specialRaceWeekDays.contains(day) {
                    return makeRest(day, isTaper: true)
                } else {
                    return makeRecoveryRun(day, miles: 2.0, weekNumber: weekNumber,
                                           isTaper: true, paces: paces)
                }
            }
            return TrainingWeek(weekNumber: weekNumber, phase: phase,
                                phaseLabel: phaseLabel, days: days)
        }

        let mpSection = isTaper ? nil : mpFinishMiles(canonical: canonical,
                                                       weekMiles: totalMiles)

        // FIX 1: pass recovDayCount
        let alloc = allocate(totalMiles: totalMiles, longMiles: longMiles,
                              canonical: canonical, isTaper: isTaper,
                              taperWeeks: taperWeeks, taperPos: taperPos,
                              recovDayCount: recovDayCount)

        var days: [TrainingDay] = []

        for day in Weekday.allCases {
            let td: TrainingDay

            if restSet.contains(day) {
                td = makeRest(day, isTaper: isTaper)
            } else if day == lrDay {
                if let mpMiles = mpSection {
                    td = makeLongRunWithMP(day, longMiles: alloc.longM, mpMiles: mpMiles,
                                           weekNumber: weekNumber, totalWeeks: totalWeeks,
                                           paces: paces)
                } else {
                    td = makeLongRun(day, miles: alloc.longM, canonical: canonical,
                                     weekNumber: weekNumber, totalWeeks: totalWeeks,
                                     isTaper: isTaper, trainingDepth: trainingDepth,
                                     tier: tier, paces: paces)
                }
            } else if day == ltDay {
                if inLTOnboarding {
                    td = makeGeneralAerobicRun(day, miles: alloc.ltTotal,
                                               canonical: canonical, weekNumber: weekNumber,
                                               tier: tier, paces: paces)
                } else {
                    td = makeLTRun(day, totalMiles: alloc.ltTotal,
                                    ltMiles: alloc.ltAtPace, canonical: canonical,
                                    isTaper: isTaper, trainingDepth: trainingDepth,
                                    paces: paces)
                }
            } else if day == mlrDay {
                td = makeMediumLongRun(day, miles: alloc.mlrM, canonical: canonical,
                                        weekNumber: weekNumber, isTaper: isTaper,
                                        trainingDepth: trainingDepth, tier: tier,
                                        paces: paces)
            } else {
                if alloc.recovPerDay > 0 {
                    td = makeRecoveryRun(day, miles: alloc.recovPerDay,
                                         weekNumber: weekNumber, isTaper: isTaper,
                                         paces: paces)
                } else {
                    td = makeRest(day, isTaper: isTaper)
                }
            }

            days.append(td)
        }

        return TrainingWeek(weekNumber: weekNumber, phase: phase,
                            phaseLabel: phaseLabel, days: days)
    }

    // MARK: - Day Makers

    static func makeRest(_ day: Weekday, isTaper: Bool) -> TrainingDay {
        let desc = isTaper
            ? "Rest day. The adaptations from months of training are consolidating. This rest is part of the preparation."
            : "Rest day. After the LT session, medium-long run, and long run, your body synthesizes the adaptations here. This is not a gap in training — it is where the training takes effect."
        return TrainingDay(weekday: day, workoutType: .rest, miles: 0,
                           description: desc, paceNote: "—")
    }

    static func makeGeneralAerobicRun(_ day       : Weekday,
                                       miles      : Double,
                                       canonical  : Int,
                                       weekNumber : Int,
                                       tier       : RunnerReadinessTier,
                                       paces      : PaceEngine) -> TrainingDay {
        let gaRange = paces.rangeString(paces.generalAero)

        let rationale: String
        switch tier {
        case .rebuilding:
            rationale = "You are in the onboarding phase. These general aerobic runs establish the aerobic layering habit before LT intensity is introduced. Your body is adapting to the dual-stimulus structure — this run plus the medium-long run — before the harder threshold demand is added."
        case .developing:
            rationale = "General aerobic running this week builds your base before LT sessions begin. The full Pfitz structure — with threshold work — arrives in the coming weeks."
        default:
            rationale = "General aerobic run to establish the week's aerobic layering before full LT sessions begin."
        }

        let desc = """
General aerobic run: \(String(format: "%.0f", miles)) miles at sustained aerobic effort.

Run at \(gaRange) — comfortably sustained, not easy and not hard.

\(rationale)
"""
        return TrainingDay(weekday: day, workoutType: .generalAerobic, miles: miles,
                           description: desc,
                           paceNote: "\(gaRange) — general aerobic, sustained")
    }

    // MARK: - LT Run
    //
    // FIX 2 — Description arithmetic.
    //
    // Old: description hardcoded "~2 miles easy" for warmup and cooldown.
    //   When the budget cap compressed ltTotal below (ltAtPace + 4.0), the
    //   displayed breakdown (2 + ltMiles + 2) summed higher than the stated total.
    //   Example: ltTotal=10.2, ltAtPace=6.5 → displayed "2+7+2=11 miles" vs stored 10.
    //
    // Fix: warmup and cooldown are derived from (ltTotal - ltAtPace), split evenly.
    //   This guarantees: warmupDisplay + ltAtPace + cooldownDisplay = ltTotal exactly.
    //   Both values are displayed to one decimal place — no rounding gaps.

    static func makeLTRun(_ day          : Weekday,
                           totalMiles    : Double,
                           ltMiles       : Double,
                           canonical     : Int,
                           isTaper       : Bool,
                           trainingDepth : Double,
                           paces         : PaceEngine) -> TrainingDay {
        let ltPace = PaceEngine.format(paces.pfitzLT)
        let ltHigh = PaceEngine.format(paces.pfitzLT - 10)
        let ltLow  = PaceEngine.format(paces.pfitzLT + 10)

        // FIX 2: derive warmup and cooldown from actual remaining budget.
        // warmup + ltMiles + cooldown = totalMiles exactly.
        let warmupCooldownTotal = (totalMiles - ltMiles).rounded(toPlaces: 2)
        let warmupMiles         = (warmupCooldownTotal / 2.0).rounded(toPlaces: 1)
        let cooldownMiles       = (totalMiles - ltMiles - warmupMiles).rounded(toPlaces: 1)

        let tapNote = isTaper
            ? "\n\nTaper week — run the LT section at effort, not a specific pace."
            : ""

        let depthNote: String
        switch trainingDepth {
        case ..<0.35:
            depthNote = "In the endurance phase, LT work establishes the aerobic ceiling your marathon pace will sit beneath. The threshold pace you can sustain is expanding week by week."
        case 0.35..<0.65:
            depthNote = "LT development is the primary focus of this phase. Each session raises the pace you can sustain aerobically — directly translating to what you can hold for 26.2 miles."
        default:
            depthNote = "In the race-specific phase, LT work maintains sharpness alongside marathon-pace long runs. These sessions prevent you from becoming purely a slow, long-distance specialist."
        }

        let desc = """
Lactate threshold run: \(String(format: "%.1f", totalMiles)) miles with \(String(format: "%.1f", ltMiles)) miles at LT pace.\(tapNote)

\(String(format: "%.1f", warmupMiles)) mi easy warmup · \(String(format: "%.1f", ltMiles)) mi at \(ltHigh)–\(ltLow)/mi · \
\(String(format: "%.1f", cooldownMiles)) mi easy cooldown · Total: \(String(format: "%.1f", totalMiles)) miles

LT pace sits at the boundary of your aerobic and anaerobic systems. Sustaining it trains \
your body to clear lactate more effectively, raising the pace you can hold aerobically.

\(depthNote)
"""
        return TrainingDay(weekday: day, workoutType: .lactateThreshold,
                           miles: totalMiles, description: desc,
                           paceNote: "~\(ltPace)/mi for the LT section — 25K–30K race effort")
    }

    static func makeMediumLongRun(_ day          : Weekday,
                                   miles         : Double,
                                   canonical     : Int,
                                   weekNumber    : Int,
                                   isTaper       : Bool,
                                   trainingDepth : Double,
                                   tier          : RunnerReadinessTier,
                                   paces         : PaceEngine) -> TrainingDay {
        let gaRange = paces.rangeString(paces.generalAero)

        let growthNote = (tier == .rebuilding || tier == .developing)
            ? "\n\nAs your weekly mileage grows across the plan, this run lengthens — it always represents a consistent fraction of your total aerobic work, not a fixed distance."
            : ""

        let depthNote: String
        switch trainingDepth {
        case ..<0.33:
            depthNote = "The medium-long run is the defining feature of Pfitz training — a second major aerobic stimulus every week without exception. You are establishing the habit. The distance grows as your base builds."
        case 0.33..<0.67:
            depthNote = "Every Pfitz week contains this run. Not most weeks — every week. The LT session builds your ceiling. The long run builds outer endurance. This run fills the space between them, creating the depth that makes the final 10K manageable."
        default:
            depthNote = "In the race-specific phase, this run provides continuous aerobic stimulus between your marathon-pace long runs and LT sessions. By race day, your body knows how to run on accumulated aerobic stress. That is the Pfitz advantage."
        }

        let tapDesc = "Medium-long run: \(Int(miles)) miles during taper. Shorter than recent MLRs — but still present. The medium-long run never disappears in Pfitz, it only reduces. General aerobic effort throughout."

        let buildDesc = """
Medium-long run: \(Int(miles)) miles at general aerobic effort.

Run at \(gaRange) — not a recovery jog, not a hard effort. Sustained aerobic work at medium intensity.

\(depthNote)\(growthNote)
"""

        return TrainingDay(weekday: day, workoutType: .mediumLong, miles: miles,
                           description: isTaper ? tapDesc : buildDesc,
                           paceNote: "\(gaRange) — general aerobic, comfortably sustained")
    }

    static func makeLongRun(_ day          : Weekday,
                             miles         : Double,
                             canonical     : Int,
                             weekNumber    : Int,
                             totalWeeks    : Int,
                             isTaper       : Bool,
                             trainingDepth : Double,
                             tier          : RunnerReadinessTier,
                             paces         : PaceEngine) -> TrainingDay {
        let lrRange     = paces.rangeString(paces.longRun)
        let weeksToRace = totalWeeks - weekNumber

        let growthNote = (tier == .rebuilding || tier == .developing)
            ? "\n\nYour long run starts conservatively and builds progressively. You are growing into the aerobic density Pfitz demands."
            : ""

        let desc: String
        switch (isTaper, weeksToRace) {
        case (true, 1):
            desc = "Final long run before the race. Run easy. Your fitness is built — this run maintains rhythm and neuromuscular freshness."
        case (true, _):
            desc = "Taper long run. Shorter, easier, correct. The aerobic work is done. These taper runs maintain rhythm while your body consolidates months of adaptation."
        case (false, _) where cutbackWeeks.contains(canonical):
            desc = """
Long run: \(Int(miles)) miles — recovery week.

A planned reduction. You have been building consistently — this lighter long run allows \
adaptation to catch up. Run easy at \(lrRange). The following weeks will be your longest.
"""
        case (false, _) where miles >= 20:
            desc = """
Long run: \(Int(miles)) miles at easy aerobic effort.

Start conservatively — the first 8 miles should feel almost too easy. The medium-long run \
earlier this week means you are running this on legs that have already done meaningful \
aerobic work. That combination is the Pfitz engine.

Run at \(lrRange) throughout.\(growthNote)
"""
        default:
            desc = """
Long run: \(Int(miles)) miles easy.

Run at \(lrRange) — genuinely aerobic throughout. This run and the medium-long run are Pfitz's \
dual-aerobic framework: two major stimuli per week developing the endurance to sustain effort late in a race.\(growthNote)
"""
        }

        return TrainingDay(weekday: day, workoutType: .longRun, miles: miles,
                           description: desc,
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
        let easyMiles = max(0, Int(longMiles) - mpMiles)

        let desc = """
Long run with marathon pace finish: \(Int(longMiles)) miles — first \(easyMiles) miles easy, \
final \(mpMiles) miles at marathon pace.

First \(easyMiles) miles: \(lrRange). Deliberately easy. Build aerobic momentum.

Final \(mpMiles) miles: \(mpPace)/mi — your goal marathon pace, not faster. This section \
teaches your body what marathon effort feels like when you are genuinely tired. That is \
exactly what the second half of the race will require.

If the marathon pace section feels controlled, your fitness is where it needs to be.
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
        let recovPace = paces.singleString(paces.recovery)
        let descs: [String] = [
            "Recovery run. Genuinely easy — slower than your easy pace. After the LT session, medium-long run, and long run, your job today is active recovery without adding new stimulus.",
            "Recovery run. The cardiovascular system recovers faster than the muscles. Run slower than feels necessary — perceived effort underestimates how much recovery your legs still need.",
            "Recovery run. Enhanced blood flow and glycogen replenishment without triggering a new training stimulus. Keep heart rate genuinely low.",
            "Recovery run. In Pfitz training, recovery runs are explicitly slow — not just 'easy.' They serve a specific purpose: accelerating recovery between major aerobic events."
        ]
        let desc = descs[weekNumber % descs.count]
        let note = isTaper ? "Taper recovery — extra easy, just keep the legs moving"
                           : "~\(recovPace)/mi — slower than easy, deliberate"

        return TrainingDay(weekday: day, workoutType: .recovery, miles: miles,
                           description: desc, paceNote: note)
    }
}
