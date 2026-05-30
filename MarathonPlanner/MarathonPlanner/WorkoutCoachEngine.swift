import Foundation

// MARK: - Workout Coaching Content

struct WorkoutCoachingContent {
    let objective : String    // What this workout develops — 2-3 sentences
    let focus     : String    // What to think about during the run
    let context   : String?   // Phase/week context — shown for key moments only
}

// MARK: - Workout Coaching Engine
//
// Generates methodology-aware, phase-aware coaching content for every
// workout type. Never generic — always reflects the specific system
// the runner chose and the moment in their training cycle.
//
// When a WeekCompletionSnapshot is supplied, the "THIS WEEK" context
// responds to what the runner has actually done — skipped sessions,
// overrun long runs, a clean week so far — before falling back to the
// standard phase context.

struct WorkoutCoachingEngine {

    // MARK: - Public Entry Point

    static func content(
        workoutType  : WorkoutType,
        planType     : PlanType,
        phase        : TrainingPhase,
        weekNumber   : Int,
        totalWeeks   : Int,
        raceType     : RaceType,
        weekSnapshot : WeekCompletionSnapshot? = nil
    ) -> WorkoutCoachingContent? {

        guard workoutType != .rest,
              workoutType != .crossTrain,
              workoutType != .raceDay else { return nil }

        let obj = objective(workoutType, planType, raceType)
        let foc = focus(workoutType, planType, phase)

        // Completion-aware context takes priority when the snapshot has
        // something meaningful to say. Phase context is the fallback.
        let ctx: String?
        if let snap = weekSnapshot,
           !snap.noPriorActivity,
           let completionCtx = completionAwareContext(snap, workoutType) {
            ctx = completionCtx
        } else {
            ctx = phaseContext(phase, weekNumber, totalWeeks, workoutType)
        }

        return WorkoutCoachingContent(
            objective: obj,
            focus:     foc,
            context:   ctx
        )
    }

    // MARK: - Objective
    // Explains what this workout develops and why it exists in this plan.
    // Methodology-specific — Hansons content never appears in a Pfitz plan.

    private static func objective(
        _ workout  : WorkoutType,
        _ plan     : PlanType,
        _ raceType : RaceType
    ) -> String {
        let isHalf = raceType == .halfMarathon
        let raceLabel = isHalf ? "half marathon" : "marathon"

        switch workout {

        // MARK: Long Run

        case .longRun:
            switch plan {
            case .hansons, .hansonsHalf:
                return "The Hansons long run is intentionally capped — not because 16 miles is the limit of useful long running, but because you are running it on already-tired legs. That accumulated fatigue is the training stimulus. It teaches your body to run efficiently when depleted, which is precisely what the final miles of a \(raceLabel) demand."
            case .pfitz:
                return "Long runs in Pfitz anchor the week's aerobic work. Combined with the medium-long run earlier in the week, you are accumulating high-quality endurance volume that compresses months of adaptation into a single training cycle. This is where \(raceLabel) fitness is actually built."
            case .higdon, .higdonIntermediate:
                return "The long run is the centerpiece of your week. Every other session exists to support this one. Its purpose is simple: accumulate time on feet at a comfortable effort. Pace is irrelevant. The miles are the medicine."
            case .higdonHalfNovice, .higdonHalfIntermediate:
                return "Long run day. The most important run of your week. Building the endurance to cover \(isHalf ? "13.1" : "26.2") miles takes time on feet — not speed, not intensity. Just consistent distance run at a pace you can sustain."
            case .firstHalf:
                return "This is the most important run of your week. You are building the endurance base that will carry you through 13.1 miles. The distance matters more than the pace — always. Every long run you complete makes race day more achievable."
            }

        // MARK: Long Run with MP Finish

        case .longRunWithMP:
            return "The long run with \(raceLabel) pace finish is one of the most effective marathon-specific sessions that exists. The easy opening miles prepare your body for the work ahead, then the pace miles teach you what goal effort actually feels like when you are fatigued. This is not a test — it is rehearsal."

        // MARK: Strength MP (Hansons)

        case .strengthMP:
            return "The Hansons strength workout is the signature session of this methodology. You are running \(raceLabel) pace on legs that already carry a full week of training miles. That is intentional — not a design flaw. Race day will feel exactly like this. The purpose is to make that familiar."

        // MARK: Speed Work (Hansons)

        case .speedWork:
            return "Speed work in Hansons develops running economy and neuromuscular efficiency at the top of your aerobic range. These intervals build turnover and smoothness at paces faster than goal race effort without the excessive recovery cost of all-out sessions. They make \(raceLabel) pace feel controlled later in the cycle."

        // MARK: Lactate Threshold (Pfitz)

        case .lactateThreshold:
            return "Threshold running targets the exact pace at which your body's aerobic system begins to be overwhelmed by lactate accumulation. Training consistently at this effort raises that threshold — allowing you to run faster before fatigue compounds. This session directly moves your \(raceLabel) finish time."

        // MARK: Cruise Intervals

        case .cruiseIntervals:
            return "Cruise intervals develop lactate threshold through repeated shorter efforts with brief rest. The structured rest allows you to accumulate more total time at threshold than a continuous tempo run, creating a stronger training signal with equivalent recovery cost."

        // MARK: Interval Work

        case .intervalWork:
            return "Interval work develops VO2 max — your ceiling for aerobic energy production. Raising that ceiling expands the range of paces available to you aerobically, which ultimately makes \(raceLabel) pace feel less demanding and more sustainable."

        // MARK: Tempo Run

        case .tempoRun:
            return "Tempo running develops your lactate threshold — the pace you can sustain for roughly an hour at maximum aerobic effort. Consistent tempo work raises this threshold over weeks, making \(raceLabel) pace feel progressively more manageable as the training cycle builds."

        // MARK: Marathon / Half Marathon Pace

        case .marathonPace:
            return "\(isHalf ? "Half marathon" : "Marathon") pace runs reinforce your goal race effort under training fatigue. Running at race pace when not fully recovered teaches your body to find and hold that rhythm in the conditions that matter — which is exactly what the final miles of the race will demand."

        // MARK: Medium-Long Run (Pfitz)

        case .mediumLong:
            return "The medium-long run is a Pfitz signature — a distinctly longer mid-week effort that most training programs simply omit. It creates a second major aerobic stimulus during the week, layering endurance on top of the weekend long run rather than marking time between efforts. This is what separates Pfitz's mileage from programs of similar volume."

        // MARK: Midweek Longer Run (Higdon)

        case .midweekLong:
            return "The midweek longer run extends your aerobic base beyond what the weekend long run alone can develop. It adds meaningful endurance volume at an effort that doesn't compromise your ability to recover — which is the defining characteristic of sustainable high mileage training."

        // MARK: Easy Run

        case .easy, .generalAerobic:
            switch plan {
            case .hansons, .hansonsHalf:
                return "Easy runs are the connective tissue of cumulative fatigue training. They keep your aerobic system engaged while your body recovers and adapts between the quality sessions. Running easy is not running slow — it is running smart."
            case .pfitz:
                return "Easy days in Pfitz do genuine work. They add aerobic volume without meaningful recovery cost, preserving your ability to execute the quality sessions and long runs at full effectiveness. Every mile at easy pace is compound interest on your fitness."
            case .higdon, .higdonIntermediate:
                return "Easy running is the foundation of this program. Consistent, comfortable effort accumulated over weeks and months builds aerobic capacity more reliably than any harder session. These runs matter more than they feel like they do."
            case .higdonHalfNovice, .higdonHalfIntermediate, .firstHalf:
                return "Every easy run you complete builds your aerobic base. These runs are quietly developing the endurance foundation that will carry you to the finish line — even when they feel insignificant in the moment."
            }

        // MARK: Recovery Run

        case .recovery:
            return "Recovery runs serve one specific purpose: moving blood through tired muscles to accelerate adaptation without adding to the training load. They should feel almost embarrassingly easy. That slowness is not a failure of effort — it is the correct execution of a tool that enhances everything else."

        // MARK: Steady Run (First Half)

        case .steadyRun:
            return "Steady runs sit between easy and tempo effort — more purposeful than a recovery shuffle, but well within your sustainable aerobic range. They build comfort at a controlled working pace, developing the ability to run steadily for extended periods without undue fatigue."

        // MARK: Strides

        case .strides:
            return "Strides develop neuromuscular coordination and running economy through brief, controlled accelerations. They teach your body to recruit muscle fibers efficiently at faster paces without creating meaningful fatigue. Over weeks, they make faster running feel more natural."

        // MARK: Shakeout

        case .shakeout:
            return "A shakeout run exists for one reason: keeping your legs loose without creating fatigue. Your fitness is already built and cannot be added to now. This run maintains rhythm and reduces pre-race stiffness — nothing more, nothing less."

        default:
            return "This session develops a specific component of your \(raceLabel) fitness. Execute it with intention and let the adaptation follow."
        }
    }

    // MARK: - Focus
    // What the runner should actually think about during the workout.
    // Practical, immediate, actionable.

    private static func focus(
        _ workout : WorkoutType,
        _ plan    : PlanType,
        _ phase   : TrainingPhase
    ) -> String {
        switch workout {

        case .longRun:
            switch plan {
            case .hansons, .hansonsHalf:
                return "Settle into a rhythm early and hold it. If you finish feeling like you had more left, you ran it correctly. Restraint on long run day is the discipline that makes the methodology work."
            case .pfitz:
                return "Run the first third deliberately easy — resist the temptation to drift faster as you warm up. The final miles are where the real adaptation occurs. Let the distance come to you."
            case .higdon, .higdonIntermediate, .higdonHalfNovice, .higdonHalfIntermediate:
                return "Walk when you need to — this is completely fine and will not undermine your training. Your goal is to cover the distance. Every step, walked or run, counts toward the adaptation."
            case .firstHalf:
                return "Do not worry about your pace. Focus entirely on completing the distance at whatever effort lets you finish feeling capable rather than depleted. There is no pace goal today."
            }

        case .longRunWithMP:
            return "Run the opening miles genuinely easy — anticipation of the pace finish should not make you drift faster early. When the pace section begins, find the rhythm rather than forcing the splits. Notice what goal effort actually feels like in this context."

        case .strengthMP:
            return "Find the pace and lock into it. Do not chase the early miles — let them come to you. This workout is about holding goal effort when it is legitimately hard, not setting a time. If you are running this on tired legs, controlled is more important than precise."

        case .speedWork:
            return "Focus on controlled speed rather than maximum effort. Each interval should feel challenging but not all-out — more like 5K effort than a sprint. Take the recovery between reps fully. Shortcutting rest undermines the session."

        case .lactateThreshold:
            return "Settle into a pace you could sustain for roughly an hour if required. Comfortably hard — you could speak a short sentence, but you would choose not to. Stay relaxed in your shoulders, hands, and jaw. Tension costs energy."

        case .tempoRun:
            return "Run by effort rather than pace. The target is comfortably hard — working, controlled, sustainable. If the final minutes required real mental effort, you ran it correctly. If it felt easy, you left something behind."

        case .marathonPace:
            return "Find the rhythm rather than the pace. Let your body settle into the effort instead of forcing splits. Running by feel at race effort is often more valuable than chasing a number on your watch."

        case .mediumLong:
            return "This is not a quality session and should not feel like one. Run at a pace you could hold indefinitely if required. The purpose is aerobic volume, not intensity — do not let competitiveness drift you faster than the workout calls for."

        case .midweekLong:
            return "Comfortable and conversational throughout. This run is about accumulating endurance miles, not testing fitness. Save what you have for the weekend long run."

        case .easy, .generalAerobic:
            return "If you cannot comfortably speak in full sentences, you are running too fast. Slow down without apology. Easy runs done at genuinely easy effort produce far more adaptation than easy runs done slightly too hard — which compromise recovery without adding training stimulus."

        case .recovery:
            return "Go slower than feels necessary. The purpose of this run is compromised the moment it becomes an honest aerobic effort. If your legs feel heavy, err toward walking. You are not losing fitness — you are building it."

        case .cruiseIntervals:
            return "Each rep at threshold pace, each rest taken fully. The brief recovery is part of the design — it allows you to accumulate more total time at the target effort. Don't shorten the rest to feel tougher. It is not toughness, it is undermining the session."

        case .intervalWork:
            return "Each rep should feel similarly challenging. If the final intervals feel dramatically harder than the first, you went out too fast. Aim for even effort across the session — not even pace, but even perceived exertion."

        case .steadyRun:
            return "More purposeful than your easy days, but never hard. You could hold a conversation if you chose to — you simply prefer not to. Stay consistent and relaxed. This is a building block, not a test."

        case .strides:
            return "Accelerate gradually over the first 10 seconds, hold the fast effort for 15-20 seconds, then decelerate gently. Take full recovery between each one — 60 to 90 seconds of easy walking. These should feel quick and light, not strained."

        case .shakeout:
            return "Keep it genuinely easy and brief. Do not try to shake anything out aggressively, add any intensity, or run further than prescribed. The goal is to arrive at the start line feeling loose, not tired."

        default:
            if phase == .taper {
                return "Keep the effort conservative. You are not building fitness today — you are protecting what you have built."
            }
            return "Execute with consistent effort. Focus on controlled execution rather than chasing splits."
        }
    }

    // MARK: - Completion-Aware Context
    // Responds to what has actually happened in the current week.
    // Priority over phase context — if something meaningful can be said
    // about the week's actual progress, say that instead.

    private static func completionAwareContext(
        _ snap    : WeekCompletionSnapshot,
        _ workout : WorkoutType
    ) -> String? {

        let isQuality = workout.isQualityType
        let isLong    = workout.isLongRunType
        let isEasy    = workout.isEasyType

        // ── 1. Long run significantly overrun ────────────────────────
        // Warn about carry-over fatigue for any non-long workout after an
        // overrun long run.
        if snap.longRunOverrun && !isLong {
            let extra = Int((snap.longRunActual ?? 0) - snap.longRunPlanned)
            let milesWord = extra == 1 ? "mile" : "miles"
            return "Your long run was \(extra) \(milesWord) longer than planned. That extra mileage carries real fatigue into today. Let effort — not pace — be your guide."
        }

        // ── 2. Skipped sessions ───────────────────────────────────────
        if snap.hasSkips {
            if isQuality {
                return "A session slipped earlier this week. Don't try to compensate by pushing harder today — execute this workout at the right effort and move on. One well-run session recovers the week better than one punishing one."
            }
            if isLong {
                return "The week leading into this long run has been imperfect. The long run is the most important session in this training cycle. Get it done at a controlled, sustainable effort and the week is salvaged."
            }
            if isEasy {
                return "It has been an uneven week. An easy run banked today keeps the weekly training load from falling further behind. Keep it controlled — and let it be enough."
            }
        }

        // ── 3. All quality sessions complete → today is easy/recovery ─
        if snap.allQualityDone && isEasy {
            return "The quality work this week is done. Today's easy miles complete the weekly training load. Run genuinely easy and let the adaptations set in."
        }

        // ── 4. Running a clean week (≥3 done, no skips) ──────────────
        if snap.completedCount >= 3 && snap.skippedCount == 0 {
            return "Every session this week has been completed on schedule. Consistency is the whole job — today keeps that record intact."
        }

        // ── 5. Consistent week heading into the long run ──────────────
        if isLong && snap.completedCount >= 2 && snap.completionPct >= 0.75 {
            return "You have been consistent this week. The long run is the payoff session — start controlled, settle into a rhythm, and let the miles develop."
        }

        return nil
    }

    // MARK: - Phase Context
    // Optional additional layer for key training moments.
    // Only shown when it meaningfully adds to runner understanding.

    private static func phaseContext(
        _ phase      : TrainingPhase,
        _ weekNumber : Int,
        _ totalWeeks : Int,
        _ workout    : WorkoutType
    ) -> String? {
        let weeksRemaining = totalWeeks - weekNumber

        switch phase {

        case .base:
            guard weekNumber <= 2 else { return nil }
            return "You are in the opening weeks of training. These sessions are about establishing rhythm and allowing your body to adapt to consistent load. The fitness you want does not arrive in week two — it arrives because of what you do in weeks two through sixteen. Start easier than you think you should."

        case .build:
            return nil  // Build phase is self-evident — no additional context needed

        case .peak:
            switch workout {
            case .longRun, .longRunWithMP:
                return "This is peak week — your highest training load. Completing this long run in the context of everything else you have done this week is one of the most significant training sessions of your cycle. Get through it, and the hardest part of your preparation is behind you."
            case .strengthMP, .speedWork, .lactateThreshold, .tempoRun:
                return "Peak week. The accumulated fatigue you are carrying into this session is real and intentional — it is the point. Completing quality work in this condition is exactly the preparation race day demands. It will not feel as good as a fresh session. That is fine."
            default:
                return "You are in peak week — the highest training load of this cycle. Fatigue is expected. It is not a problem to be solved; it is evidence that the adaptation is happening. Get through the week, recover well, and trust what comes next."
            }

        case .taper:
            if weeksRemaining <= 1 {
                return "Race week. The fitness you have built cannot be added to now — only protected. Your job this week is to arrive at the start line rested, healthy, and confident. Trust the work you have done."
            }
            if weeksRemaining == 2 {
                return "You are in taper. The reduced training load may feel strange — flat legs, restless energy, doubt about your fitness. These are normal responses to decreased stimulus. Your body is consolidating the fitness you built over weeks of hard work. The taper is working even when it does not feel like it is."
            }
            return "Taper week. Less is more. The temptation to add miles or intensity to calm the anxiety is understandable — resist it. The work is done."

        case .race:
            return nil  // Race day cards handle their own context

        }
    }
}

// MARK: - WorkoutType classification (file-private)
// Used only by the completion-aware context logic above.

private extension WorkoutType {

    /// True for sessions that demand targeted intensity:
    /// tempo, speed, strength, threshold, intervals, marathon-pace reps.
    var isQualityType: Bool {
        switch self {
        case .strengthMP, .speedWork, .lactateThreshold, .cruiseIntervals,
             .intervalWork, .repetitionWork, .tempoRun, .marathonPace:
            return true
        default:
            return false
        }
    }

    /// True for the primary long run (plain or with a pace finish).
    var isLongRunType: Bool {
        self == .longRun || self == .longRunWithMP
    }

    /// True for workouts that should be run at genuinely easy effort:
    /// easy, recovery, general aerobic, steady, medium-long, midweek long.
    var isEasyType: Bool {
        switch self {
        case .easy, .recovery, .generalAerobic, .steadyRun,
             .mediumLong, .midweekLong:
            return true
        default:
            return false
        }
    }
}
