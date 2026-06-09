import Foundation

// MARK: - Pace Zone Validator
//
// Compares actual pace (from Strava average_speed) against the expected
// training zone for a given workout type and goal time.
//
// IMPORTANT — structured workout limitation:
//   For workouts with warmup + quality segment + cooldown (Tempo, Strength,
//   Speed, LT, Intervals), Strava's average_speed reflects the ENTIRE activity
//   including easy wu/cd miles. A perfect 8-mile tempo at MP with 1.5mi wu/cd
//   produces an overall average ~25–30 sec/mile slower than the quality segment.
//   Verdicts for structured workouts account for this dilution and are phrased
//   as "overall average" assessments rather than direct zone checks.
//
// Verdict string convention:
//   Good verdicts begin with "✓ " — views use this prefix to drive green color.
//   Warning verdicts have no prefix — views show them in amber.

struct PaceZoneValidator {

    // MARK: - Public entry point

    /// Returns a verdict string, or nil for workouts where pace isn't the
    /// primary metric (Rest, Cross-Train, Strides, Shakeout, Race Day).
    static func evaluate(
        workoutType          : String,
        goalMinutes          : Int,
        actualSecondsPerMile : Int
    ) -> String? {

        let e      = PaceEngine(goalMinutes: goalMinutes)
        let actual = actualSecondsPerMile

        switch workoutType {

        // MARK: Simple aerobic — average pace IS the zone metric
        case "Easy Run", "Steady Run":
            return verdictEasy(actual: actual, engine: e)

        case "General Aerobic":
            return verdictGeneralAerobic(actual: actual, engine: e)

        case "Long Run", "Long Run w/ MP Finish", "Long Run w/ HMP Finish":
            return verdictLongRun(actual: actual, engine: e)

        case "Recovery Run":
            return verdictRecovery(actual: actual, engine: e)

        case "Medium-Long Run", "Midweek Longer Run":
            return verdictMediumLong(actual: actual, engine: e)

        // MARK: Structured — overall average is diluted by wu/cd; wider tolerance
        case "Tempo Run":
            return verdictTempoOverall(actual: actual, engine: e)

        case "Marathon Pace":
            return verdictMarathonPaceOverall(actual: actual, engine: e)

        case "Strength (MP)":
            return verdictStrengthOverall(actual: actual, engine: e)

        case "Lactate Threshold", "Cruise Intervals":
            return verdictLTOverall(actual: actual, engine: e)

        case "Speed Work", "Interval Work", "Repetition Work":
            return verdictSpeedOverall(actual: actual, engine: e)

        default:
            return nil
        }
    }

    // MARK: - Helpers

    private static func fmt(_ s: Int) -> String { PaceEngine.format(s) }

    // MARK: - Easy Run  (target: MP+90 – MP+120)

    private static func verdictEasy(actual: Int, engine e: PaceEngine) -> String {
        let lo = e.easy.low    // MP+90  (faster end)
        let hi = e.easy.high   // MP+120 (slower end)

        if actual < e.MP + 45 {
            return "Ran at or near marathon pace on an easy day. This pace accumulates fatigue without the recovery benefit — slow down on the next one."
        }
        if actual < lo - 15 {
            return "A bit fast for an easy day. Target is \(fmt(lo))–\(fmt(hi))/mi — the kind of pace where holding a full conversation is effortless."
        }
        if actual <= hi + 25 {
            return "✓ Easy pace — right zone."
        }
        return "✓ Very easy effort. That's fine — easy runs can't be too slow."
    }

    // MARK: - General Aerobic  (target: MP+45 – MP+75)

    private static func verdictGeneralAerobic(actual: Int, engine e: PaceEngine) -> String {
        let lo = e.generalAero.low    // MP+45
        let hi = e.generalAero.high   // MP+75

        if actual < e.MP + 20 {
            return "Faster than general aerobic zone. Save intensity for your quality sessions."
        }
        if actual <= hi + 20 {
            return "✓ Good aerobic effort — right zone for this type of run."
        }
        return "Slower than general aerobic zone. Aim for \(fmt(lo))–\(fmt(hi))/mi — purposeful but not hard."
    }

    // MARK: - Long Run  (target: MP+60 – MP+90)

    private static func verdictLongRun(actual: Int, engine e: PaceEngine) -> String {
        let lo = e.longRun.low    // MP+60
        let hi = e.longRun.high   // MP+90

        if actual < e.MP + 30 {
            return "Long run pace was close to marathon pace — significantly too fast. Long runs build aerobic base. Slow down 30–45 sec/mile on the next one."
        }
        if actual < lo - 10 {
            return "A bit fast for a long run. Target \(fmt(lo))–\(fmt(hi))/mi — a pace that still feels comfortable at mile 18."
        }
        if actual <= hi + 30 {
            return "✓ Long run pace — solid aerobic work."
        }
        return "✓ Easy long run. The miles are the medicine — pace is secondary."
    }

    // MARK: - Recovery Run  (target: >MP+120)

    private static func verdictRecovery(actual: Int, engine e: PaceEngine) -> String {
        let easyLo = e.easy.low  // MP+90

        if actual < easyLo {
            return "Ran at easy pace or faster on a recovery day. Recovery runs should feel embarrassingly slow — their job is blood flow, not fitness."
        }
        if actual < e.recovery - 20 {
            return "Slightly fast for recovery. Going slower is always better here — even walking is fine."
        }
        return "✓ Recovery pace — exactly right."
    }

    // MARK: - Medium-Long / Midweek Longer  (target: MP+45 – MP+90)

    private static func verdictMediumLong(actual: Int, engine e: PaceEngine) -> String {
        if actual < e.MP + 25 {
            return "Too fast for a mid-week aerobic run. These are not quality sessions — easy and steady is the goal."
        }
        if actual <= e.longRun.high + 20 {
            return "✓ Good aerobic effort for the mid-week run."
        }
        return "✓ Easy mid-week effort. Fine — consistency and volume matter more than pace here."
    }

    // MARK: - Tempo Run (overall avg, diluted by ~1.5mi wu + 1.5mi cd at easy pace)
    //
    // A perfect tempo at MP (Hansons) with 1.5+1.5 wu/cd produces an overall
    // average roughly MP+28. Good range: MP+10 to MP+55.

    private static func verdictTempoOverall(actual: Int, engine e: PaceEngine) -> String {
        if actual < e.MP - 15 {
            return "Overall average ahead of marathon pace — the quality segment was likely too fast. Tempo runs should be comfortably hard, not a race."
        }
        if actual <= e.MP + 55 {
            return "✓ Overall average consistent with hitting the target quality pace."
        }
        if actual <= e.easy.low {
            return "Overall average slower than expected for a tempo session. Check that the quality miles reached the target effort."
        }
        return "Overall average in easy territory — the quality segment may not have been reached. Target a comfortably hard effort for the full tempo portion."
    }

    // MARK: - Marathon Pace (Hansons strength tempo, overall avg ~MP+25 to MP+50)

    private static func verdictMarathonPaceOverall(actual: Int, engine e: PaceEngine) -> String {
        if actual < e.MP - 20 {
            return "Overall average faster than marathon pace — the quality segment ran too hot. MP work is sustained rhythm, not a race effort."
        }
        if actual <= e.MP + 50 {
            return "✓ Overall average consistent with hitting marathon pace in the quality segment."
        }
        if actual <= e.easy.high {
            return "Overall average a bit slower than expected. Focus on locking in marathon pace from the first quality mile."
        }
        return "Overall average in easy territory — the marathon-pace segment may have been too slow. Target \(fmt(e.MP))/mi for the quality portion."
    }

    // MARK: - Strength (MP-10, overall avg ~MP+30 to MP+55)

    private static func verdictStrengthOverall(actual: Int, engine e: PaceEngine) -> String {
        let targetQuality = e.hansonsStrengthPace  // MP-10

        if actual < targetQuality - 20 {
            return "Overall average ahead of strength pace — check that recovery jogs between reps are taken fully. Cutting recovery undermines the session."
        }
        if actual <= e.MP + 60 {
            return "✓ Overall average consistent with hitting strength pace in the quality reps."
        }
        return "Overall average suggests the strength pace wasn't quite reached. Target \(fmt(targetQuality))/mi for the rep segments."
    }

    // MARK: - Lactate Threshold / Cruise Intervals (overall avg ~MP to MP+45)

    private static func verdictLTOverall(actual: Int, engine e: PaceEngine) -> String {
        let targetQuality = e.pfitzLT  // MP-20

        if actual < targetQuality - 20 {
            return "Overall average ahead of LT zone — threshold work should be comfortably hard, not a race effort."
        }
        if actual <= e.MP + 50 {
            return "✓ Overall average consistent with lactate threshold effort."
        }
        return "Overall average below LT zone. Threshold pace should feel like the hardest effort you could sustain for ~60 minutes."
    }

    // MARK: - Speed / Intervals / Repetitions (overall avg highly variable)
    //
    // Most of the session is warmup, cooldown, and recovery jogs. The overall
    // average tells little about interval quality, so just confirm completion.

    private static func verdictSpeedOverall(actual: Int, engine e: PaceEngine) -> String {
        // Flag obvious pacing errors: average slower than easy zone suggests
        // the interval intensity wasn't reached
        if actual > e.easy.high + 30 {
            return "Overall average in recovery territory — the interval intensity may not have been reached. Target a true 5K race effort for the rep segments."
        }
        return "✓ Speed session complete. The quality is in the reps — overall average is secondary to consistent rep effort."
    }
}
