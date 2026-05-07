import Foundation

// MARK: - Off-Season Run Type

enum OffSeasonRunType: String {
    case easy       = "Easy Run"
    case recovery   = "Recovery Run"
    case tempo      = "Tempo Run"
    case strides    = "Easy + Strides"
    case longRun    = "Long Run"
    case crossTrain = "Cross-Training"
    case rest       = "Rest"

    var icon: String {
        switch self {
        case .easy:       return "figure.run"
        case .recovery:   return "figure.walk"
        case .tempo:      return "flame"
        case .strides:    return "hare"
        case .longRun:    return "arrow.right.to.line"
        case .crossTrain: return "figure.cross.training"
        case .rest:       return "moon.stars"
        }
    }
}

// MARK: - Proximity to Plan

enum PlanProximity {
    case far          // 7+ weeks out
    case approaching  // 3–6 weeks out
    case imminent     // 1–2 weeks out
    case none         // no upcoming plan
}

// MARK: - Suggested Workout

struct SuggestedWorkout {
    let title         : String
    let distance      : String
    let description   : String
    let guidance      : String
    let reasoning     : String       // why this workout, today
    let type          : OffSeasonRunType
    let optionalAddOn : String?
    let phaseLabel    : String
    let intensityNote : String?
    let countdownText : String?      // "Training begins in 38 days"
    let weeklyTarget  : String?      // "Target: ~28 mi this week"
}

// MARK: - Fitness Level

enum FitnessLevel {
    case beginner
    case intermediate
    case advanced
}

// MARK: - Recovery Phase

enum RecoveryPhase {
    case activeRecovery
    case earlyOffSeason
    case baseBuilding
}

// MARK: - Off-Season Context

struct OffSeasonContext {
    let fitnessLevel     : FitnessLevel
    let recoveryPhase    : RecoveryPhase
    let suggestedLongRun : Double
    let suggestedWeekly  : Double
    let raceType         : RaceType?
    let daysSinceRace    : Int?
    let upcomingPlan     : SavedPlan?
    let daysUntilPlan    : Int?
    let planProximity    : PlanProximity
    let weeklyTarget     : Double    // target mpw for this off-season week

    static func build(from plans: [SavedPlan]) -> OffSeasonContext {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())

        // ── Past plan (most recently raced) ───────────────────
        let recentPlan = plans
            .filter { cal.startOfDay(for: $0.raceDate) <= today }
            .sorted { $0.raceDate > $1.raceDate }
            .first

        let daysSinceRace: Int? = recentPlan.map { plan in
            cal.dateComponents([.day],
                from: cal.startOfDay(for: plan.raceDate),
                to:   today).day ?? 999
        }

        let recoveryPhase: RecoveryPhase
        if let days = daysSinceRace {
            switch days {
            case 0...14:  recoveryPhase = .activeRecovery
            case 15...42: recoveryPhase = .earlyOffSeason
            default:      recoveryPhase = .baseBuilding
            }
        } else {
            recoveryPhase = .baseBuilding
        }

        // ── Upcoming plan (starts in the future) ──────────────
        let upcomingPlan = plans
            .filter { cal.startOfDay(for: $0.startDate) > today }
            .sorted { $0.startDate < $1.startDate }
            .first

        let daysUntilPlan: Int? = upcomingPlan.map { plan in
            cal.dateComponents([.day],
                from: today,
                to:   cal.startOfDay(for: plan.startDate)).day ?? 999
        }

        let planProximity: PlanProximity
        if let days = daysUntilPlan {
            switch days {
            case 0...14:  planProximity = .imminent
            case 15...42: planProximity = .approaching
            default:      planProximity = .far
            }
        } else {
            planProximity = .none
        }

        // ── Fitness level from recent peak ────────────────────
        let peakWeekly = recentPlan.map { plan in
            plan.weeks.map { $0.totalMiles }.max() ?? 0
        } ?? 0

        let fitnessLevel: FitnessLevel
        switch peakWeekly {
        case ..<25:   fitnessLevel = .beginner
        case 25...45: fitnessLevel = .intermediate
        default:      fitnessLevel = .advanced
        }

        // ── Longest completed long run ─────────────────────────
        let allDays: [SavedDay] = plans
            .flatMap { $0.weeks }
            .flatMap { $0.days }

        let longRunTypes: Set<String> = [
            "Long Run",
            "Long Run w/ MP Finish",
            "Long Run w/ HMP Finish"
        ]

        let completedLongRuns = allDays.filter { day in
            longRunTypes.contains(day.workoutType)
                && (day.completionStatus == .completed
                    || day.completionStatus == .modified)
        }

        let longestRun: Double = completedLongRuns
            .map { $0.actualMiles ?? $0.miles }
            .max() ?? 6.0

        // ── Race type ─────────────────────────────────────────
        // Prefer upcoming plan's race type, fall back to recent
        let raceType: RaceType? =
            upcomingPlan?.settings.raceType
            ?? recentPlan?.settings.raceType

        let isHalf = raceType == .halfMarathon

        // ── Long run ceiling (race-type aware) ────────────────
        let longRunCeiling: Double
        switch recoveryPhase {
        case .activeRecovery:
            longRunCeiling = isHalf ? 5.0 : 6.0
        case .earlyOffSeason:
            longRunCeiling = isHalf ? 9.0 : 11.0
        case .baseBuilding:
            longRunCeiling = isHalf ? 12.0 : 16.0
        }

        let suggestedLong: Double
        switch recoveryPhase {
        case .activeRecovery:
            suggestedLong = min(longRunCeiling, longestRun * 0.35)
        case .earlyOffSeason:
            suggestedLong = min(longRunCeiling, longestRun * 0.55)
        case .baseBuilding:
            suggestedLong = min(longRunCeiling, longestRun * 0.65)
        }

        // ── Weekly mileage target ─────────────────────────────
        // If there is an upcoming plan, progress toward its
        // starting mileage. Otherwise use fitness-based defaults.
        let weeklyTarget: Double
        if let upcoming = upcomingPlan,
           let days = daysUntilPlan,
           days > 0 {
            let planStartMileage = upcoming.settings.baseMileage
            let currentEstimate  = peakWeekly > 0
                ? peakWeekly * 0.55
                : planStartMileage * 0.65
            // Linear progression from current estimate to plan start
            // mileage over the days remaining, capped at a safe rate
            let weeksRemaining   = max(1.0, Double(days) / 7.0)
            let weeklyIncrease   = min(
                3.0,  // never more than 3 mpw increase per week
                (planStartMileage - currentEstimate) / weeksRemaining
            )
            let weeksElapsed = max(0.0,
                Double(daysUntilPlan ?? 99) - Double(days)) / 7.0
            weeklyTarget = min(
                planStartMileage,
                max(currentEstimate,
                    currentEstimate + weeklyIncrease * weeksElapsed)
            ).rounded(toPlaces: 0)
        } else {
            switch (recoveryPhase, fitnessLevel) {
            case (.activeRecovery, _):
                weeklyTarget = min(15, peakWeekly * 0.30)
            case (.earlyOffSeason, .beginner):
                weeklyTarget = min(18, peakWeekly * 0.45)
            case (.earlyOffSeason, .intermediate):
                weeklyTarget = min(25, peakWeekly * 0.50)
            case (.earlyOffSeason, .advanced):
                weeklyTarget = min(35, peakWeekly * 0.55)
            case (.baseBuilding, .beginner):
                weeklyTarget = min(25, max(15, peakWeekly * 0.60))
            case (.baseBuilding, .intermediate):
                weeklyTarget = min(35, max(20, peakWeekly * 0.65))
            case (.baseBuilding, .advanced):
                weeklyTarget = min(50, max(30, peakWeekly * 0.70))
            }
        }

        let suggestedWeekly = weeklyTarget

        return OffSeasonContext(
            fitnessLevel:     fitnessLevel,
            recoveryPhase:    recoveryPhase,
            suggestedLongRun: suggestedLong.rounded(toPlaces: 0),
            suggestedWeekly:  suggestedWeekly.rounded(toPlaces: 0),
            raceType:         raceType,
            daysSinceRace:    daysSinceRace,
            upcomingPlan:     upcomingPlan,
            daysUntilPlan:    daysUntilPlan,
            planProximity:    planProximity,
            weeklyTarget:     weeklyTarget
        )
    }
}

// MARK: - Off-Season Engine

struct OffSeasonEngine {

    static func todaySuggestion(
        date    : Date = Date(),
        context : OffSeasonContext
    ) -> SuggestedWorkout {
        let cal     = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        let weekNum = cal.component(.weekOfYear, from: date)
        let variant = weekNum % 3

        switch context.recoveryPhase {
        case .activeRecovery:
            return activeRecovery(weekday: weekday, context: context)
        case .earlyOffSeason:
            return earlyOffSeason(weekday: weekday,
                                   variant: variant,
                                   context: context)
        case .baseBuilding:
            return baseBuilding(weekday: weekday,
                                variant: variant,
                                context: context)
        }
    }

    // MARK: - Shared Helpers

    private static func countdownText(
        _ context: OffSeasonContext
    ) -> String? {
        guard let days = context.daysUntilPlan,
              let plan = context.upcomingPlan else { return nil }

        let weeks = days / 7
        let name  = plan.name

        switch days {
        case 0:
            return "\(name) begins today."
        case 1:
            return "\(name) begins tomorrow."
        case 2...13:
            return "\(name) begins in \(days) days."
        default:
            return "\(name) begins in \(weeks) week\(weeks == 1 ? "" : "s")."
        }
    }

    private static func weeklyTargetText(
        _ context: OffSeasonContext
    ) -> String? {
        guard context.weeklyTarget > 0 else { return nil }
        return "Target: ~\(Int(context.weeklyTarget)) mi this week"
    }

    // MARK: - Reasoning by proximity and workout type

    private static func reasoning(
        for type    : OffSeasonRunType,
        context     : OffSeasonContext
    ) -> String {
        let proximity = context.planProximity
        let isHalf    = context.raceType == .halfMarathon
        let raceLabel = isHalf ? "half marathon" : "marathon"

        switch (type, proximity) {

        case (.easy, .imminent):
            return "Your \(raceLabel) training block starts soon. Easy running now keeps you fresh and healthy for week one."
        case (.easy, .approaching):
            return "Building aerobic base before your \(raceLabel) plan begins. These miles compound quietly."
        case (.easy, .far), (.easy, .none):
            return "Easy running builds the aerobic engine. The fitness you gain here is invisible — until race day."

        case (.recovery, _):
            return "Adaptation happens during recovery, not during the run. This is not a light day — it is a necessary one."

        case (.longRun, .imminent):
            return "Your last long run before \(raceLabel) training begins. Run it well — this sets the tone for what follows."
        case (.longRun, .approaching):
            return "Building your long run toward the level your \(raceLabel) plan will expect from week one."
        case (.longRun, .far), (.longRun, .none):
            return "The long run is the cornerstone of any off-season week. Time on feet at easy effort builds durability nothing else can."

        case (.strides, .imminent):
            return "Strides keep your leg speed sharp going into training. Your \(raceLabel) plan will include quality work — this is the bridge."
        case (.strides, .approaching):
            return "Introducing leg speed before the training block begins. Strides now mean less shock when the quality work starts."
        case (.strides, _):
            return "Strides prevent the flat, sluggish feeling that comes from too many easy miles. 20 seconds of quick running, full recovery."

        case (.crossTrain, .imminent):
            return "Protect your joints before training begins. Your \(raceLabel) block will ask a lot of your legs — arrive healthy."
        case (.crossTrain, _):
            return "Cross-training maintains cardiovascular fitness while giving your connective tissue a break from impact."

        case (.rest, _):
            return "Fitness is built during recovery. A well-rested runner trains better than a tired one every time."

        case (.tempo, _):
            return "Maintaining aerobic sharpness without the full cost of structured training."
        }
    }

    // MARK: - Active Recovery (0–14 days post-race)

    private static func activeRecovery(
        weekday : Int,
        context : OffSeasonContext
    ) -> SuggestedWorkout {
        let countdown = countdownText(context)
        let target    = weeklyTargetText(context)

        switch weekday {
        case 2:
            return SuggestedWorkout(
                title:         "Full Rest",
                distance:      "—",
                description:   "Your body needs complete recovery. Don't underestimate what racing does to you.",
                guidance:      "No running. Walking is fine. Sleep and eat well. This is not wasted time — it is when adaptation happens.",
                reasoning:     reasoning(for: .rest, context: context),
                type:          .rest,
                optionalAddOn: nil,
                phaseLabel:    "Active Recovery",
                intensityNote: nil,
                countdownText: countdown,
                weeklyTarget:  target
            )
        case 3:
            return SuggestedWorkout(
                title:         "Easy Walk or Jog",
                distance:      "2–3 miles",
                description:   "First steps back. Walk whenever you want to.",
                guidance:      "There is no pace goal. No distance goal. Just gentle movement to start the recovery process.",
                reasoning:     reasoning(for: .recovery, context: context),
                type:          .recovery,
                optionalAddOn: nil,
                phaseLabel:    "Active Recovery",
                intensityNote: "Walk/jog — completely self-directed",
                countdownText: countdown,
                weeklyTarget:  target
            )
        case 4:
            return SuggestedWorkout(
                title:         "Cross-Training",
                distance:      "30–40 min",
                description:   "Low-impact movement. Bike, swim, or gentle yoga.",
                guidance:      "Keep your heart rate conversational. This is active recovery, not a workout.",
                reasoning:     reasoning(for: .crossTrain, context: context),
                type:          .crossTrain,
                optionalAddOn: "Optional: 10-minute easy walk after if legs feel ready.",
                phaseLabel:    "Active Recovery",
                intensityNote: "Low effort — aerobic only",
                countdownText: countdown,
                weeklyTarget:  target
            )
        case 5:
            return SuggestedWorkout(
                title:         "Rest",
                distance:      "—",
                description:   "Another rest day. Post-race fatigue often peaks at days 3–5.",
                guidance:      "Your muscles are still repairing at the cellular level even if you feel okay. Do not rush this.",
                reasoning:     reasoning(for: .rest, context: context),
                type:          .rest,
                optionalAddOn: nil,
                phaseLabel:    "Active Recovery",
                intensityNote: nil,
                countdownText: countdown,
                weeklyTarget:  target
            )
        case 6:
            return SuggestedWorkout(
                title:         "Easy Jog",
                distance:      "2–3 miles",
                description:   "If your legs want to run, let them. If they don't, walk.",
                guidance:      "The only rule: if it hurts, stop. This run does not matter. Next month's training does.",
                reasoning:     reasoning(for: .recovery, context: context),
                type:          .recovery,
                optionalAddOn: nil,
                phaseLabel:    "Active Recovery",
                intensityNote: "RPE 2–3 out of 10",
                countdownText: countdown,
                weeklyTarget:  target
            )
        case 7:
            return SuggestedWorkout(
                title:         "Easy Run",
                distance:      "3–4 miles",
                description:   "First slightly longer run since the race. Keep it genuinely easy.",
                guidance:      "Run a route you know well. No watch pressure. This is about enjoyment, not fitness.",
                reasoning:     reasoning(for: .easy, context: context),
                type:          .easy,
                optionalAddOn: nil,
                phaseLabel:    "Active Recovery",
                intensityNote: "Fully conversational",
                countdownText: countdown,
                weeklyTarget:  target
            )
        default:
            return SuggestedWorkout(
                title:         "Rest or Walk",
                distance:      "—",
                description:   "End the week gently. You earned this.",
                guidance:      "A 20-minute walk is fine if you want to move. Nothing more needed today.",
                reasoning:     reasoning(for: .rest, context: context),
                type:          .rest,
                optionalAddOn: nil,
                phaseLabel:    "Active Recovery",
                intensityNote: nil,
                countdownText: countdown,
                weeklyTarget:  target
            )
        }
    }

    // MARK: - Early Off-Season (15–42 days)

    private static func earlyOffSeason(
        weekday : Int,
        variant : Int,
        context : OffSeasonContext
    ) -> SuggestedWorkout {
        let longLow   = max(4, Int(context.suggestedLongRun) - 1)
        let longHigh  = Int(context.suggestedLongRun) + 1
        let longMiles = "\(longLow)–\(longHigh) miles"
        let countdown = countdownText(context)
        let target    = weeklyTargetText(context)

        switch weekday {
        case 2:
            return SuggestedWorkout(
                title:         "Easy Run or Rest",
                distance:      "3–4 miles",
                description:   "Low-pressure start to the week. Run if you feel like it.",
                guidance:      "You are rebuilding the habit, not fitness yet. Showing up matters more than the miles.",
                reasoning:     reasoning(for: .easy, context: context),
                type:          .easy,
                optionalAddOn: nil,
                phaseLabel:    "Early Off-Season",
                intensityNote: "Easy effort only",
                countdownText: countdown,
                weeklyTarget:  target
            )
        case 3:
            if context.fitnessLevel == .advanced && variant == 0 {
                return SuggestedWorkout(
                    title:         "Easy + Strides",
                    distance:      "4–5 miles",
                    description:   "Easy run with 4 strides at the end to keep leg speed.",
                    guidance:      "Strides are 20 seconds quick and relaxed — not a sprint. Full walk recovery between each.",
                    reasoning:     reasoning(for: .strides, context: context),
                    type:          .strides,
                    optionalAddOn: nil,
                    phaseLabel:    "Early Off-Season",
                    intensityNote: "Easy with brief 5K-effort bursts",
                    countdownText: countdown,
                    weeklyTarget:  target
                )
            }
            return SuggestedWorkout(
                title:         "Easy Run",
                distance:      "3–5 miles",
                description:   "Mid-week easy mileage. No structure, no pressure.",
                guidance:      "Run a comfortable loop. The goal is enjoyment and consistency.",
                reasoning:     reasoning(for: .easy, context: context),
                type:          .easy,
                optionalAddOn: nil,
                phaseLabel:    "Early Off-Season",
                intensityNote: "Conversational pace",
                countdownText: countdown,
                weeklyTarget:  target
            )
        case 4:
            return SuggestedWorkout(
                title:         "Cross-Training",
                distance:      "45 min",
                description:   "Break from running. Bike, swim, yoga, or strength work.",
                guidance:      "Cross-training during the off-season protects your joints and keeps general fitness without the impact.",
                reasoning:     reasoning(for: .crossTrain, context: context),
                type:          .crossTrain,
                optionalAddOn: "Optional: 2–3 mile easy jog before or after if legs feel fresh.",
                phaseLabel:    "Early Off-Season",
                intensityNote: "Moderate effort",
                countdownText: countdown,
                weeklyTarget:  target
            )
        case 5:
            return SuggestedWorkout(
                title:         "Easy Run",
                distance:      "4–5 miles",
                description:   "Thursday easy run. One of the most important habits to rebuild.",
                guidance:      "Mid-week mileage during off-season is what raises your base for the next training block.",
                reasoning:     reasoning(for: .easy, context: context),
                type:          .easy,
                optionalAddOn: nil,
                phaseLabel:    "Early Off-Season",
                intensityNote: "Easy — could hold a full conversation",
                countdownText: countdown,
                weeklyTarget:  target
            )
        case 6:
            return SuggestedWorkout(
                title:         "Rest",
                distance:      "—",
                description:   "Rest before tomorrow's long run.",
                guidance:      "What you do today affects tomorrow's run quality. Sleep well and eat enough.",
                reasoning:     reasoning(for: .rest, context: context),
                type:          .rest,
                optionalAddOn: nil,
                phaseLabel:    "Early Off-Season",
                intensityNote: nil,
                countdownText: countdown,
                weeklyTarget:  target
            )
        case 7:
            return SuggestedWorkout(
                title:         "Long Run",
                distance:      longMiles,
                description:   "The most important run of your off-season week. Fully conversational effort.",
                guidance:      "Your long run should feel comfortable throughout. You are building the aerobic base your next plan will sit on top of.",
                reasoning:     reasoning(for: .longRun, context: context),
                type:          .longRun,
                optionalAddOn: nil,
                phaseLabel:    "Early Off-Season",
                intensityNote: "Easy — this is not a race effort",
                countdownText: countdown,
                weeklyTarget:  target
            )
        default:
            return SuggestedWorkout(
                title:         "Recovery Run",
                distance:      "2–3 miles",
                description:   "Short and slow after yesterday. Move the legs, nothing more.",
                guidance:      "If your legs are sore, walk instead. The recovery run is optional. The long run is not.",
                reasoning:     reasoning(for: .recovery, context: context),
                type:          .recovery,
                optionalAddOn: nil,
                phaseLabel:    "Early Off-Season",
                intensityNote: "Slower than feels necessary",
                countdownText: countdown,
                weeklyTarget:  target
            )
        }
    }

    // MARK: - Base Building (43+ days or no recent race)

    private static func baseBuilding(
        weekday : Int,
        variant : Int,
        context : OffSeasonContext
    ) -> SuggestedWorkout {
        let longLow   = max(5, Int(context.suggestedLongRun))
        let longHigh  = longLow + 2
        let longMiles = "\(longLow)–\(longHigh) miles"
        let countdown = countdownText(context)
        let target    = weeklyTargetText(context)

        // When plan is imminent, introduce strides more aggressively
        let useStrides = context.planProximity == .imminent
            ? context.fitnessLevel != .beginner
            : context.fitnessLevel != .beginner && variant != 2

        switch weekday {
        case 2:
            switch variant {
            case 0:
                return SuggestedWorkout(
                    title:         "Easy Run",
                    distance:      "4–5 miles",
                    description:   "Start the week with easy mileage. Shake out the weekend.",
                    guidance:      "Monday easy runs build aerobic base without accumulating fatigue. They matter more than they feel like they do.",
                    reasoning:     reasoning(for: .easy, context: context),
                    type:          .easy,
                    optionalAddOn: nil,
                    phaseLabel:    "Base Building",
                    intensityNote: "Conversational pace",
                    countdownText: countdown,
                    weeklyTarget:  target
                )
            case 1:
                return SuggestedWorkout(
                    title:         "Rest or Cross-Train",
                    distance:      "30–40 min",
                    description:   "Active recovery to start the week.",
                    guidance:      "A Monday rest day is a legitimate training choice. You will run better on Tuesday for it.",
                    reasoning:     reasoning(for: .crossTrain, context: context),
                    type:          .crossTrain,
                    optionalAddOn: "Optional: 20-minute easy jog if legs feel good.",
                    phaseLabel:    "Base Building",
                    intensityNote: "Low effort",
                    countdownText: countdown,
                    weeklyTarget:  target
                )
            default:
                return SuggestedWorkout(
                    title:         "Easy Run",
                    distance:      "5–6 miles",
                    description:   "Longer Monday easy run for higher-mileage weeks.",
                    guidance:      "Keep it genuinely easy. Monday's job is volume, not effort.",
                    reasoning:     reasoning(for: .easy, context: context),
                    type:          .easy,
                    optionalAddOn: nil,
                    phaseLabel:    "Base Building",
                    intensityNote: "Easy aerobic — HR zone 2",
                    countdownText: countdown,
                    weeklyTarget:  target
                )
            }

        case 3:
            if useStrides {
                return SuggestedWorkout(
                    title:         "Easy + Strides",
                    distance:      "5–6 miles",
                    description:   "Easy run with 6 strides at the end.",
                    guidance:      "Strides keep leg speed sharp. 20 seconds quick and relaxed, full walk recovery between each.",
                    reasoning:     reasoning(for: .strides, context: context),
                    type:          .strides,
                    optionalAddOn: nil,
                    phaseLabel:    "Base Building",
                    intensityNote: "Easy + 6 × 20-sec quick strides",
                    countdownText: countdown,
                    weeklyTarget:  target
                )
            }
            return SuggestedWorkout(
                title:         "Easy Run",
                distance:      "4–6 miles",
                description:   "Tuesday easy run. No structure today — just run.",
                guidance:      "Run your comfortable loop. Do not look at pace. This is about time on feet.",
                reasoning:     reasoning(for: .easy, context: context),
                type:          .easy,
                optionalAddOn: nil,
                phaseLabel:    "Base Building",
                intensityNote: "Easy effort",
                countdownText: countdown,
                weeklyTarget:  target
            )

        case 4:
            if context.fitnessLevel == .advanced {
                return SuggestedWorkout(
                    title:         "Moderate Run",
                    distance:      "7–9 miles",
                    description:   "Mid-week honest aerobic running. Not easy, not hard.",
                    guidance:      "Run at a pace you could hold for two hours, but choose not to.",
                    reasoning:     reasoning(for: .easy, context: context),
                    type:          .easy,
                    optionalAddOn: nil,
                    phaseLabel:    "Base Building",
                    intensityNote: "General aerobic — moderate effort",
                    countdownText: countdown,
                    weeklyTarget:  target
                )
            }
            return SuggestedWorkout(
                title:         "Cross-Training",
                distance:      "45–60 min",
                description:   "Mid-week alternative. Bike, swim, elliptical, or strength.",
                guidance:      "Cross-training lets you add aerobic work without the cumulative joint stress of another running day.",
                reasoning:     reasoning(for: .crossTrain, context: context),
                type:          .crossTrain,
                optionalAddOn: "Optional: 3-mile easy jog after. Total time under 90 minutes.",
                phaseLabel:    "Base Building",
                intensityNote: "Aerobic effort",
                countdownText: countdown,
                weeklyTarget:  target
            )

        case 5:
            return SuggestedWorkout(
                title:         "Easy Run",
                distance:      "5–7 miles",
                description:   "Thursday run. One of the most important habits of any training block.",
                guidance:      "Runners who nail their Thursday easy run consistently are the ones who arrive at their next plan with a real base.",
                reasoning:     reasoning(for: .easy, context: context),
                type:          .easy,
                optionalAddOn: nil,
                phaseLabel:    "Base Building",
                intensityNote: "Easy — fully conversational",
                countdownText: countdown,
                weeklyTarget:  target
            )

        case 6:
            if variant == 0 {
                return SuggestedWorkout(
                    title:         "Rest",
                    distance:      "—",
                    description:   "Rest before tomorrow's long run.",
                    guidance:      "What you do today determines how tomorrow's long run goes. Sleep, eat, hydrate.",
                    reasoning:     reasoning(for: .rest, context: context),
                    type:          .rest,
                    optionalAddOn: nil,
                    phaseLabel:    "Base Building",
                    intensityNote: nil,
                    countdownText: countdown,
                    weeklyTarget:  target
                )
            }
            return SuggestedWorkout(
                title:         "Easy Shakeout",
                distance:      "3–4 miles",
                description:   "Short easy run to stay loose before tomorrow's long run.",
                guidance:      "Keep it under 35 minutes. The point is to feel ready tomorrow, not fatigued.",
                reasoning:     reasoning(for: .easy, context: context),
                type:          .easy,
                optionalAddOn: nil,
                phaseLabel:    "Base Building",
                intensityNote: "Very easy — leave energy for Saturday",
                countdownText: countdown,
                weeklyTarget:  target
            )

        case 7:
            return SuggestedWorkout(
                title:         "Long Run",
                distance:      longMiles,
                description:   "The cornerstone of your off-season week.",
                guidance:      "Start slower than feels right. The long run should feel comfortable at mile 3 and honest at mile \(longLow - 2). If you are fading early, you went out too fast.",
                reasoning:     reasoning(for: .longRun, context: context),
                type:          .longRun,
                optionalAddOn: nil,
                phaseLabel:    "Base Building",
                intensityNote: "Easy aerobic — conversational throughout",
                countdownText: countdown,
                weeklyTarget:  target
            )

        default:
            if variant == 0 {
                return SuggestedWorkout(
                    title:         "Recovery Run",
                    distance:      "3–4 miles",
                    description:   "Easy Sunday run to keep the legs moving after Saturday.",
                    guidance:      "Run slower than your easy pace. Your cardiovascular system recovers faster than your legs — perceived effort will lie to you today.",
                    reasoning:     reasoning(for: .recovery, context: context),
                    type:          .recovery,
                    optionalAddOn: nil,
                    phaseLabel:    "Base Building",
                    intensityNote: "Slower than easy",
                    countdownText: countdown,
                    weeklyTarget:  target
                )
            }
            return SuggestedWorkout(
                title:         "Rest",
                distance:      "—",
                description:   "Full rest. Recover from the long run.",
                guidance:      "Adaptation happens during recovery, not during the run. Today is as important as yesterday.",
                reasoning:     reasoning(for: .rest, context: context),
                type:          .rest,
                optionalAddOn: nil,
                phaseLabel:    "Base Building",
                intensityNote: nil,
                countdownText: countdown,
                weeklyTarget:  target
            )
        }
    }
}
