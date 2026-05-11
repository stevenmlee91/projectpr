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

// MARK: - Plan Proximity

enum PlanProximity {
    case far
    case approaching
    case imminent
    case none
}

// MARK: - Recovery Phase (public — drives UI)

enum RecoveryPhase {
    case activeRecovery
    case earlyOffSeason
    case baseBuilding
}

// MARK: - Fitness Level

enum FitnessLevel {
    case beginner
    case intermediate
    case advanced
}

// MARK: - Suggested Workout

struct SuggestedWorkout {
    let title         : String
    let distance      : String
    let description   : String
    let guidance      : String
    let reasoning     : String
    let type          : OffSeasonRunType
    let optionalAddOn : String?
    let phaseLabel    : String
    let intensityNote : String?
    let countdownText : String?
    let weeklyTarget  : String?
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Off-Season Log Entry
//
// A single logged off-season run. Build these from your OffSeasonStore
// and pass the array into OffSeasonTrainingState.build(from:).
// ─────────────────────────────────────────────────────────────────────────────

struct OffSeasonLogEntry: Codable {
    let date      : Date
    let miles     : Double
    let isLongRun : Bool

    init(date: Date, miles: Double, isLongRun: Bool = false) {
        self.date      = date
        self.miles     = miles
        self.isLongRun = isLongRun
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Behavior Tier
//
// The four runner states the engine adapts to.
// Drives workout difficulty, coaching tone, and progression pacing.
// ─────────────────────────────────────────────────────────────────────────────

enum OffSeasonBehaviorTier {
    /// 3+ days/week, consistent mileage, improving.
    case thriving
    /// 2–3 days/week — not perfect, but present.
    case steady
    /// Missing runs, inconsistent, or 3+ days since last run.
    case struggling
    /// First run, or returning after a gap of 5+ days.
    case returning
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Off-Season Training State
//
// Derived from actual logged off-season runs.
// This is what makes the engine behavioral rather than purely date-driven.
// ─────────────────────────────────────────────────────────────────────────────

struct OffSeasonTrainingState {
    let recentMilesPerWeek : Double   // avg miles over last 14 days
    let longestRecentRun   : Double   // longest run in last 21 days
    let daysSinceLastRun   : Int      // 0 = ran today, 99 = no history
    let streak             : Int      // consecutive run days in last 14
    let longRunThisWeek    : Bool     // long run logged in last 7 days
    let totalLoggedRuns    : Int      // all-time logged count
    let tier               : OffSeasonBehaviorTier

    // MARK: Build

    static func build(from log: [OffSeasonLogEntry]) -> OffSeasonTrainingState {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())

        guard !log.isEmpty else { return .fresh }

        let sorted = log.sorted { $0.date > $1.date }

        // Days since last run
        let daysSinceLast: Int = {
            guard let last = sorted.first else { return 99 }
            return max(0, cal.dateComponents(
                [.day],
                from: cal.startOfDay(for: last.date),
                to:   today).day ?? 99)
        }()

        // Miles in last 14 days
        let cutoff14    = cal.date(byAdding: .day, value: -14, to: today)!
        let last14      = log.filter { cal.startOfDay(for: $0.date) >= cutoff14 }
        let miles14     = last14.reduce(0) { $0 + $1.miles }
        let milesPerWeek = miles14 / 2.0

        // Longest run in last 21 days
        let cutoff21      = cal.date(byAdding: .day, value: -21, to: today)!
        let last21        = log.filter { cal.startOfDay(for: $0.date) >= cutoff21 }
        let longestRecent = last21.map { $0.miles }.max() ?? 0

        // Long run this week (last 7 days)
        let cutoff7     = cal.date(byAdding: .day, value: -7, to: today)!
        let last7       = log.filter { cal.startOfDay(for: $0.date) >= cutoff7 }
        let longRunDone = last7.contains { $0.isLongRun || $0.miles >= 8 }

        // Consecutive streak: count run days backwards from yesterday
        var streak    = 0
        var checkDate = cal.date(byAdding: .day, value: -1, to: today)!
        for _ in 0..<14 {
            let d = cal.startOfDay(for: checkDate)
            if log.contains(where: { cal.startOfDay(for: $0.date) == d }) {
                streak    += 1
                checkDate  = cal.date(byAdding: .day, value: -1, to: checkDate)!
            } else { break }
        }

        // Behavior tier
        let tier: OffSeasonBehaviorTier
        if daysSinceLast >= 5 || log.count <= 1 {
            tier = .returning
        } else if daysSinceLast >= 3 || milesPerWeek < 8 {
            tier = .struggling
        } else if last14.count >= 6 && milesPerWeek >= 20 {
            tier = .thriving
        } else {
            tier = .steady
        }

        return OffSeasonTrainingState(
            recentMilesPerWeek: milesPerWeek.rounded(toPlaces: 1),
            longestRecentRun:   longestRecent.rounded(toPlaces: 1),
            daysSinceLastRun:   daysSinceLast,
            streak:             streak,
            longRunThisWeek:    longRunDone,
            totalLoggedRuns:    log.count,
            tier:               tier
        )
    }

    static var fresh: OffSeasonTrainingState {
        OffSeasonTrainingState(
            recentMilesPerWeek: 0,
            longestRecentRun:   0,
            daysSinceLastRun:   99,
            streak:             0,
            longRunThisWeek:    false,
            totalLoggedRuns:    0,
            tier:               .returning
        )
    }
}

// MARK: - OffSeasonWeeklyGoal Extension
// The struct is defined elsewhere. This adds the factory method.

extension OffSeasonWeeklyGoal {
    static func make(from context: OffSeasonContext,
                     state: OffSeasonTrainingState = .fresh) -> OffSeasonWeeklyGoal? {
        guard context.progressiveWeekly > 0 else { return nil }
        let adjustedMiles: Double
        switch state.tier {
        case .thriving:   adjustedMiles = context.progressiveWeekly
        case .steady:     adjustedMiles = context.progressiveWeekly * 0.9
        case .struggling: adjustedMiles = context.progressiveWeekly * 0.75
        case .returning:  adjustedMiles = min(15, context.progressiveWeekly * 0.60)
        }
        return OffSeasonWeeklyGoal(
            daysTarget:  context.daysUntilPlan ?? 0,
            milesTarget: adjustedMiles.rounded(toPlaces: 0),
            label:       weekLabel(context, state: state),
            subLabel:    weekDescription(context, state: state)
        )
    }

    private static func weekLabel(_ c: OffSeasonContext,
                                   state: OffSeasonTrainingState) -> String {
        switch state.tier {
        case .returning:  return "Getting Back Out"
        case .struggling: return "Stay Consistent"
        default:
            switch c.recoveryPhase {
            case .activeRecovery: return "Recovery Week"
            case .earlyOffSeason: return "Building Week \(c.weekWithinPhase + 1)"
            case .baseBuilding:
                if let d = c.daysUntilPlan, d <= 21 { return "Pre-Block Ramp" }
                return "Base Week \(c.weekWithinPhase + 1)"
            }
        }
    }

    private static func weekDescription(_ c: OffSeasonContext,
                                         state: OffSeasonTrainingState) -> String {
        switch state.tier {
        case .thriving:   return "Consistent running — keep building."
        case .struggling: return "Focus on showing up. Distance comes later."
        case .returning:  return "Welcome back. Easy does it."
        case .steady:
            switch c.recoveryPhase {
            case .activeRecovery: return "Easy movement only."
            case .earlyOffSeason: return "Rebuilding consistency."
            case .baseBuilding:
                if let d = c.daysUntilPlan, d <= 21 { return "Bridging to your block." }
                return "Progressive base."
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Off-Season Context
// ─────────────────────────────────────────────────────────────────────────────

struct OffSeasonContext {
    let fitnessLevel        : FitnessLevel
    let recoveryPhase       : RecoveryPhase
    let suggestedLongRun    : Double
    let suggestedWeekly     : Double
    let progressiveLongRun  : Double
    let progressiveWeekly   : Double
    let raceType            : RaceType?
    let daysSinceRace       : Int?
    let upcomingPlan        : SavedPlan?
    let daysUntilPlan       : Int?
    let planProximity       : PlanProximity
    let weeklyTarget        : Double
    let weekWithinPhase     : Int          // FIXED: actual elapsed weeks in phase
    let upcomingPlanType    : PlanType?
    let upcomingBaseMileage : Double?
    let recentPlanType      : PlanType?
    let isPostMarathon      : Bool

    static func build(from plans: [SavedPlan],
                      primaryID: UUID? = nil) -> OffSeasonContext {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())

        // ── Most recently completed plan ─────────────────────────────────

        let recentPlan = plans
            .filter { cal.startOfDay(for: $0.raceDate) <= today }
            .sorted { $0.raceDate > $1.raceDate }
            .first

        let daysSinceRace: Int? = recentPlan.map { plan in
            cal.dateComponents([.day],
                from: cal.startOfDay(for: plan.raceDate), to: today).day ?? 999
        }

        let isPostMarathon = recentPlan?.settings.raceType == .marathon

        // ── Recovery phase ───────────────────────────────────────────────

        let recoveryPhase: RecoveryPhase
        if let days = daysSinceRace {
            if isPostMarathon {
                recoveryPhase = days <= 28 ? .activeRecovery : days <= 56 ? .earlyOffSeason : .baseBuilding
            } else {
                recoveryPhase = days <= 14 ? .activeRecovery : days <= 35 ? .earlyOffSeason : .baseBuilding
            }
        } else {
            recoveryPhase = .baseBuilding
        }

        // ── Upcoming plan ────────────────────────────────────────────────

        let futurePlans = plans.filter {
            cal.startOfDay(for: $0.raceDate)  >= today
                && cal.startOfDay(for: $0.startDate) >= today
        }

        let upcomingPlan: SavedPlan?
        if let id = primaryID, let p = futurePlans.first(where: { $0.id == id }) {
            upcomingPlan = p
        } else {
            upcomingPlan = futurePlans.sorted { $0.startDate < $1.startDate }.first
        }

        let daysUntilPlan: Int? = upcomingPlan.map { plan in
            cal.dateComponents([.day],
                from: today,
                to:   cal.startOfDay(for: plan.startDate)).day ?? 999
        }

        let planProximity: PlanProximity
        if let d = daysUntilPlan {
            planProximity = d <= 14 ? .imminent : d <= 42 ? .approaching : .far
        } else {
            planProximity = .none
        }

        // ── Recency-weighted fitness level ───────────────────────────────

        let peakWeekly: Double
        if let recent = recentPlan {
            let rawPeak = recent.weeks.map { $0.totalMiles }.max() ?? 0
            // Decay if race was more than 90 days ago
            if let days = daysSinceRace, days > 90 {
                peakWeekly = rawPeak * max(0.6, 1.0 - Double(days - 90) / 365.0)
            } else {
                peakWeekly = rawPeak
            }
        } else {
            peakWeekly = 0
        }

        let fitnessLevel: FitnessLevel
        switch peakWeekly {
        case ..<25:   fitnessLevel = .beginner
        case 25...45: fitnessLevel = .intermediate
        default:      fitnessLevel = .advanced
        }

        // ── Longest completed long run ───────────────────────────────────

        let longRunTypes: Set<String> = [
            "Long Run", "Long Run w/ MP Finish", "Long Run w/ HMP Finish"
        ]
        let allDays = plans.flatMap { $0.weeks }.flatMap { $0.days }
        let completedLongDays = allDays.filter {
            longRunTypes.contains($0.workoutType)
                && ($0.completionStatus == .completed
                    || $0.completionStatus == .modified)
        }
        let longestRun: Double = completedLongDays
            .map { $0.actualMiles ?? $0.miles }
            .max() ?? 6.0

        let raceType: RaceType? =
            upcomingPlan?.settings.raceType ?? recentPlan?.settings.raceType
        let isHalf = raceType == .halfMarathon

        // ── FIXED: weekWithinPhase ───────────────────────────────────────
        // Derived from the actual date the current phase started.
        // No longer computed backwards from daysUntilPlan.

        let weekWithinPhase: Int
        if let raceDate = recentPlan?.raceDate {
            let phaseStartOffset: Int
            if isPostMarathon {
                switch recoveryPhase {
                case .activeRecovery: phaseStartOffset = 0
                case .earlyOffSeason: phaseStartOffset = 29
                case .baseBuilding:   phaseStartOffset = 57
                }
            } else {
                switch recoveryPhase {
                case .activeRecovery: phaseStartOffset = 0
                case .earlyOffSeason: phaseStartOffset = 15
                case .baseBuilding:   phaseStartOffset = 36
                }
            }
            let phaseStart = cal.date(byAdding: .day, value: phaseStartOffset,
                                       to: cal.startOfDay(for: raceDate)) ?? today
            let daysInPhase = max(0, cal.dateComponents([.day],
                from: phaseStart, to: today).day ?? 0)
            weekWithinPhase = daysInPhase / 7

        } else if let daysUntil = daysUntilPlan {
            // No recent race — treat as building toward the plan.
            // 8 weeks out = week 0 of build. 1 week out = week 7.
            let window = 8
            weekWithinPhase = max(0, window - (daysUntil / 7))

        } else {
            // No race, no plan — indefinite maintenance, start at week 0.
            weekWithinPhase = 0
        }

        // ── Progressive targets ──────────────────────────────────────────

        let longRunCeiling: Double = isHalf ? 12.0 : 16.0
        let progressiveLongRun: Double

        switch recoveryPhase {
        case .activeRecovery:
            let base = isHalf ? 4.0 : 5.0
            progressiveLongRun = min(isHalf ? 7.0 : 9.0,
                                     base + Double(weekWithinPhase) * 0.5)
        case .earlyOffSeason:
            let base = isHalf ? 7.0 : 9.0
            progressiveLongRun = min(isHalf ? 11.0 : 13.0,
                                     base + Double(weekWithinPhase) * 0.75)
        case .baseBuilding:
            if let d = daysUntilPlan, d <= 21 {
                progressiveLongRun = min(longRunCeiling, longestRun * 0.75)
            } else {
                let base = min(longestRun * 0.50, isHalf ? 9.0 : 11.0)
                progressiveLongRun = min(longRunCeiling,
                                         base + Double(weekWithinPhase) * 0.75)
            }
        }

        let upcomingBaseMileage = upcomingPlan?.settings.baseMileage

        let progressiveWeekly: Double
        if let targetBase = upcomingBaseMileage, let days = daysUntilPlan, days > 0 {
            let currentFitness: Double
            switch recoveryPhase {
            case .activeRecovery: currentFitness = peakWeekly * 0.25
            case .earlyOffSeason: currentFitness = peakWeekly * 0.45 + Double(weekWithinPhase) * 2.0
            case .baseBuilding:   currentFitness = peakWeekly * 0.55 + Double(weekWithinPhase) * 2.5
            }
            let weeksRemaining = max(1.0, Double(days) / 7.0)
            let step = min(3.0, (targetBase - currentFitness) / weeksRemaining)
            progressiveWeekly = min(targetBase,
                max(currentFitness, currentFitness + step * Double(weekWithinPhase))
            ).rounded(toPlaces: 0)
        } else {
            switch recoveryPhase {
            case .activeRecovery:
                progressiveWeekly = min(15, peakWeekly * 0.25 + Double(weekWithinPhase) * 1.5)
            case .earlyOffSeason:
                let pct: Double = fitnessLevel == .advanced ? 0.50
                                : fitnessLevel == .intermediate ? 0.45 : 0.40
                progressiveWeekly = min(40, peakWeekly * pct + Double(weekWithinPhase) * 2.0)
            case .baseBuilding:
                let pct: Double = fitnessLevel == .advanced ? 0.65
                                : fitnessLevel == .intermediate ? 0.60 : 0.55
                progressiveWeekly = min(55, max(20, peakWeekly * pct + Double(weekWithinPhase) * 2.5))
            }
        }

        let weeklyTarget = progressiveWeekly.rounded(toPlaces: 0)

        return OffSeasonContext(
            fitnessLevel:        fitnessLevel,
            recoveryPhase:       recoveryPhase,
            suggestedLongRun:    progressiveLongRun.rounded(toPlaces: 0),
            suggestedWeekly:     weeklyTarget,
            progressiveLongRun:  progressiveLongRun.rounded(toPlaces: 1),
            progressiveWeekly:   progressiveWeekly.rounded(toPlaces: 0),
            raceType:            raceType,
            daysSinceRace:       daysSinceRace,
            upcomingPlan:        upcomingPlan,
            daysUntilPlan:       daysUntilPlan,
            planProximity:       planProximity,
            weeklyTarget:        weeklyTarget,
            weekWithinPhase:     weekWithinPhase,
            upcomingPlanType:    upcomingPlan?.settings.planType,
            upcomingBaseMileage: upcomingBaseMileage,
            recentPlanType:      recentPlan?.settings.planType,
            isPostMarathon:      isPostMarathon
        )
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Internal Off-Season Phase
// ─────────────────────────────────────────────────────────────────────────────

private enum OffSeasonPhase {
    case deepRecovery
    case movementReset
    case maintenanceLow
    case maintenanceBuild
    case preBlockRamp
    case indefiniteMaintenance
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Off-Season Engine
// ─────────────────────────────────────────────────────────────────────────────

struct OffSeasonEngine {

    // MARK: - Weekday Enum (FIXED)
    // Swift Calendar weekday: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
    // Using an explicit enum prevents accidental Sunday fallthrough
    // and makes day assignments readable.

    private enum Wd: Int {
        case sun = 1, mon, tue, wed, thu, fri, sat
    }

    // MARK: - Public Entry Points

    /// Full behavioral version. Pass OffSeasonTrainingState.build(from: logEntries).
    static func todaySuggestion(
        date    : Date = Date(),
        context : OffSeasonContext,
        state   : OffSeasonTrainingState
    ) -> SuggestedWorkout {
        let wd    = Wd(rawValue: Calendar.current.component(.weekday, from: date)) ?? .sun
        let phase = internalPhase(context: context, state: state)
        switch phase {
        case .deepRecovery:          return deepRecovery(wd: wd, ctx: context, state: state)
        case .movementReset:         return movementReset(wd: wd, ctx: context, state: state)
        case .maintenanceLow:        return maintenanceLow(wd: wd, ctx: context, state: state)
        case .maintenanceBuild:      return maintenanceBuild(wd: wd, ctx: context, state: state)
        case .preBlockRamp:          return preBlockRamp(wd: wd, ctx: context, state: state)
        case .indefiniteMaintenance: return indefiniteMaintenance(wd: wd, ctx: context, state: state)
        }
    }

    /// Backward-compatible overload — no log history required.
    static func todaySuggestion(
        date    : Date = Date(),
        context : OffSeasonContext
    ) -> SuggestedWorkout {
        todaySuggestion(date: date, context: context, state: .fresh)
    }

    // MARK: - Phase Resolution

    private static func internalPhase(
        context : OffSeasonContext,
        state   : OffSeasonTrainingState
    ) -> OffSeasonPhase {
        if let days = context.daysUntilPlan,
           days <= 21,
           context.recoveryPhase == .baseBuilding {
            return .preBlockRamp
        }

        if let days = context.daysSinceRace {
            if context.isPostMarathon {
                if days <= 14 { return .deepRecovery }
                if days <= 28 { return .movementReset }
                if days <= 42 { return .maintenanceLow }
            } else {
                if days <= 7  { return .deepRecovery }
                if days <= 21 { return .movementReset }
                if days <= 35 { return .maintenanceLow }
            }
        }

        switch context.recoveryPhase {
        case .activeRecovery: return .deepRecovery
        case .earlyOffSeason: return .maintenanceLow
        case .baseBuilding:
            if context.upcomingPlan == nil && context.daysSinceRace == nil {
                return .indefiniteMaintenance
            }
            return .maintenanceBuild
        }
    }

    // MARK: - Shared Helpers

    private static func countdown(_ ctx: OffSeasonContext) -> String? {
        guard let days = ctx.daysUntilPlan, let plan = ctx.upcomingPlan else { return nil }
        let weeks = days / 7
        let name  = plan.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? plan.planType : plan.name
        switch days {
        case 0:      return "\(name) begins today."
        case 1:      return "\(name) begins tomorrow."
        case 2...13: return "\(days) days until \(name)"
        default:     return "\(weeks) weeks until \(name)"
        }
    }

    private static func targetText(_ ctx: OffSeasonContext,
                                    state: OffSeasonTrainingState) -> String? {
        guard ctx.progressiveWeekly > 0 else { return nil }
        switch state.tier {
        case .struggling: return "Focus on consistency, not mileage"
        case .returning:  return "Easy does it — any miles count this week"
        default:          return "Target: ~\(Int(ctx.progressiveWeekly)) mi this week"
        }
    }

    private static func longRange(_ ctx: OffSeasonContext, buffer: Int = 1) -> String {
        let low = max(3, Int(ctx.progressiveLongRun))
        return "\(low)–\(low + buffer) mi"
    }

    // Reduces distance string when runner is struggling or returning
    private static func dist(_ normal: String,
                              state: OffSeasonTrainingState,
                              reduced: String? = nil) -> String {
        switch state.tier {
        case .struggling, .returning: return reduced ?? normal
        default:                      return normal
        }
    }

    // MARK: - Behavioral Note
    // The "the app notices you" line — injected into reasoning.

    private static func behavioralNote(_ state: OffSeasonTrainingState,
                                        ctx: OffSeasonContext) -> String {
        switch state.tier {
        case .thriving where state.streak >= 10:
            return "\(state.streak) consecutive days of running. The base is genuinely building — don't throw this streak away with an ambitious day."
        case .thriving where state.streak >= 5:
            return "\(state.streak) days in a row. Consistent runners are the ones who show up to the start line healthy. Keep doing this."
        case .thriving:
            return "Solid consistency over the past two weeks. Quiet, regular running like this is what builds a durable base."
        case .struggling where state.daysSinceLastRun >= 5:
            return "\(state.daysSinceLastRun) days since your last run. Getting back out today — at any pace, any distance — is the only goal. Don't let perfect be the enemy of present."
        case .struggling:
            return "The mileage target this week doesn't matter. Showing up does. One run changes the trajectory."
        case .returning where state.totalLoggedRuns <= 1:
            return "First run back. Start slower than you think you need to. You are not testing fitness today — you are reconnecting with the habit."
        case .returning:
            return "You're back after a break. The fitness is still there — it doesn't disappear as fast as it feels like it does. Start easy and trust that."
        case .steady:
            if let days = ctx.daysUntilPlan, days <= 42 {
                return "Consistent running into your upcoming block. Every week you show up now is one less week of adaptation your plan has to do."
            }
            return "Showing up consistently. That is the whole job right now."
        }
    }

    // MARK: - Methodology-Aware Coaching

    private static func reasoning(for type : OffSeasonRunType,
                                   ctx     : OffSeasonContext,
                                   state   : OffSeasonTrainingState) -> String {
        let note      = behavioralNote(state, ctx: ctx)
        let isHalf    = ctx.raceType == .halfMarathon
        let raceLabel = isHalf ? "half marathon" : "marathon"
        let upcoming  = ctx.upcomingPlanType
        let prox      = ctx.planProximity

        // Methodology-specific coaching when plan is known
        if let plan = upcoming, prox != .none {
            switch (type, plan) {
            case (.longRun, .hansons), (.longRun, .hansonsHalf):
                return "\(note)\n\nHansons caps its long run intentionally — you train on cumulative fatigue, not fresh legs. Your off-season long run is building the aerobic base that makes week one manageable rather than shocking."
            case (.longRun, .pfitz):
                return "\(note)\n\nPfitz pairs the long run with a midweek medium-long run every week without exception. The off-season long run re-establishes the habit of sustained time on feet that Pfitz demands."
            case (.longRun, .higdon), (.longRun, .higdonIntermediate):
                return "\(note)\n\nThe long run is the centerpiece of every Higdon week. Maintaining this habit now means your first week of training won't feel like a shock."
            case (.easy, .hansons), (.easy, .hansonsHalf):
                return "\(note)\n\nHansons is built on six days per week of consistent running. These easy off-season miles are training the habit — not just maintaining fitness."
            case (.easy, .pfitz):
                return "\(note)\n\nEasy days in Pfitz absorb the quality work. Learning the discipline of genuinely easy running now pays off when the training loads get heavy."
            default:
                break
            }
        }

        // Phase and type based reasoning
        let baseReasoning: String
        switch (type, ctx.recoveryPhase) {
        case (.rest, .activeRecovery) where ctx.isPostMarathon:
            baseReasoning = "A marathon causes real muscle damage, measurable immune suppression, and glycogen depletion that persists for weeks. This rest is not passive — your body is actively repairing."
        case (.rest, .activeRecovery):
            baseReasoning = "Post-race recovery is real and measurable. Your connective tissue needs this time even when you feel fine. Skipping it is how overuse injuries start the next block."
        case (.recovery, .activeRecovery):
            baseReasoning = "The cardiovascular system recovers from racing faster than the legs. You may feel ready when your tendons and connective tissue are still repairing. Let the body set the pace."
        case (.easy, .earlyOffSeason):
            baseReasoning = "Easy running in the off-season builds the aerobic engine without the cost of structured training. The fitness compounds slowly and invisibly — until the next block, when it becomes obvious."
        case (.easy, .baseBuilding) where prox == .imminent:
            baseReasoning = "Your training block starts soon. These easy miles keep you healthy for week one. Arriving rested is more valuable than arriving with extra miles."
        case (.easy, _):
            baseReasoning = "Easy running builds the aerobic foundation without the recovery cost of harder work. These runs matter more than they feel like they do."
        case (.longRun, .earlyOffSeason):
            baseReasoning = "Rebuilding the long run habit is the highest-value thing the off-season can do. Time on feet at easy effort builds durability that no other session can replicate."
        case (.longRun, _):
            baseReasoning = "The long run is the cornerstone of every training week, including off-season weeks. Running it consistently — even at modest distances — maintains the adaptations that make \(raceLabel) training possible."
        case (.strides, _) where prox == .imminent:
            baseReasoning = "Strides prepare your neuromuscular system for the quality work ahead. Your training block will include structured sessions — these 20-second bursts mean the transition won't feel like a shock."
        case (.strides, _):
            baseReasoning = "Strides prevent the flat, sluggish feeling from too many slow miles. Brief bursts of quick running maintain leg turnover without adding meaningful fatigue."
        case (.crossTrain, .activeRecovery):
            baseReasoning = "Low-impact aerobic movement accelerates recovery without adding mechanical stress to your joints. This is active recovery, not a compromise."
        case (.crossTrain, _):
            baseReasoning = "Cross-training maintains cardiovascular fitness while giving your joints a genuine break from running impact. The runners who stay healthy long-term take this seriously."
        case (.tempo, _):
            baseReasoning = "Light tempo work in the late off-season maintains aerobic sharpness for the next training block. Run by effort, not by pace."
        case (.rest, _):
            baseReasoning = "Fitness is built during recovery, not during the run. A well-rested runner adapts faster, trains better, and stays healthier."
        default:
            baseReasoning = "Consistent effort over weeks compounds into real fitness — even when individual sessions feel unremarkable."
        }

        return "\(note)\n\n\(baseReasoning)"
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Phase: Deep Recovery
    // Marathon days 0–14. Half days 0–7.
    // ─────────────────────────────────────────────────────────────────────────

    private static func deepRecovery(wd: Wd, ctx: OffSeasonContext,
                                      state: OffSeasonTrainingState) -> SuggestedWorkout {
        let cd = countdown(ctx)
        let rl = ctx.raceType == .halfMarathon ? "half marathon" : "marathon"

        switch wd {
        case .mon, .thu:
            return SuggestedWorkout(
                title: "Full Rest", distance: "—",
                description: "Your body is still repairing from the \(rl). Rest is the training today.",
                guidance: "No running. Walking is fine. Focus on sleep and food. The next training block starts from a rested body, not a depleted one.",
                reasoning: reasoning(for: .rest, ctx: ctx, state: state),
                type: .rest, optionalAddOn: nil,
                phaseLabel: "Post-Race Recovery", intensityNote: nil,
                countdownText: cd, weeklyTarget: "No mileage target this week")
        case .tue:
            return SuggestedWorkout(
                title: "Gentle Walk", distance: "20–30 min",
                description: "Easy walking only. First movement since the race.",
                guidance: "Walk at a pace that feels effortless. Stop if anything hurts. This is not a workout — it is the first step back.",
                reasoning: reasoning(for: .recovery, ctx: ctx, state: state),
                type: .recovery, optionalAddOn: nil,
                phaseLabel: "Post-Race Recovery", intensityNote: "Walk only — no running",
                countdownText: cd, weeklyTarget: "No mileage target this week")
        case .wed:
            return SuggestedWorkout(
                title: "Cross-Training", distance: "20–30 min",
                description: "Gentle bike, swim, or yoga. Easy effort only.",
                guidance: "Keep your heart rate conversational. This is about circulation and gentle movement — not fitness.",
                reasoning: reasoning(for: .crossTrain, ctx: ctx, state: state),
                type: .crossTrain, optionalAddOn: nil,
                phaseLabel: "Post-Race Recovery", intensityNote: "Very low effort — RPE 2/10",
                countdownText: cd, weeklyTarget: "No mileage target this week")
        case .fri:
            return SuggestedWorkout(
                title: "Walk or Easy Jog", distance: "2–3 mi",
                description: "First optional run. Walk if your legs say no.",
                guidance: "Completely self-directed. If your legs feel ready, jog easy. If they don't, walk. No wrong answer today.",
                reasoning: reasoning(for: .recovery, ctx: ctx, state: state),
                type: .recovery, optionalAddOn: nil,
                phaseLabel: "Post-Race Recovery", intensityNote: "Walk/jog — effort 2–3/10",
                countdownText: cd, weeklyTarget: "No mileage target this week")
        case .sat:
            return SuggestedWorkout(
                title: "Easy Run", distance: "2–3 mi",
                description: "Short and easy. The beginning of coming back.",
                guidance: "Run a flat familiar route. No watch pressure. The goal is enjoyment and gentle movement — not fitness.",
                reasoning: reasoning(for: .easy, ctx: ctx, state: state),
                type: .easy, optionalAddOn: nil,
                phaseLabel: "Post-Race Recovery", intensityNote: "Fully conversational — walk breaks are fine",
                countdownText: cd, weeklyTarget: "No mileage target this week")
        case .sun:
            return SuggestedWorkout(
                title: "Rest", distance: "—",
                description: "End the week gently. You earned this.",
                guidance: "A 20-minute walk is fine if you want to move. Nothing more needed.",
                reasoning: reasoning(for: .rest, ctx: ctx, state: state),
                type: .rest, optionalAddOn: nil,
                phaseLabel: "Post-Race Recovery", intensityNote: nil,
                countdownText: cd, weeklyTarget: "No mileage target this week")
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Phase: Movement Reset
    // Marathon days 15–28. Half days 8–21. Return without pressure.
    // ─────────────────────────────────────────────────────────────────────────

    private static func movementReset(wd: Wd, ctx: OffSeasonContext,
                                       state: OffSeasonTrainingState) -> SuggestedWorkout {
        let cd  = countdown(ctx)
        let tgt = targetText(ctx, state: state)
        let wk  = ctx.weekWithinPhase

        switch wd {
        case .mon:
            return SuggestedWorkout(
                title: "Easy Run",
                distance: dist(wk == 0 ? "3–4 mi" : "4–5 mi", state: state, reduced: "2–3 mi"),
                description: "Back to running. Keep it genuinely easy.",
                guidance: state.tier == .returning
                    ? "Welcome back. Run slower than feels necessary. The goal today is showing up — nothing else."
                    : "If you feel good, you are probably going fast enough. If you feel great, slow down.",
                reasoning: reasoning(for: .easy, ctx: ctx, state: state),
                type: .easy, optionalAddOn: nil,
                phaseLabel: "Movement Reset", intensityNote: "Easy — conversational throughout",
                countdownText: cd, weeklyTarget: tgt)
        case .tue:
            return SuggestedWorkout(
                title: "Rest or Walk", distance: "—",
                description: "Rest or a 20-minute easy walk.",
                guidance: "You do not need to run every day yet. Rebuilding the habit takes time. Rest without guilt.",
                reasoning: reasoning(for: .rest, ctx: ctx, state: state),
                type: .rest, optionalAddOn: "Optional: 20-minute easy walk.",
                phaseLabel: "Movement Reset", intensityNote: nil,
                countdownText: cd, weeklyTarget: tgt)
        case .wed:
            return SuggestedWorkout(
                title: "Cross-Training", distance: "30–45 min",
                description: "Low-impact aerobic work. Bike, swim, or elliptical.",
                guidance: "Cross-training maintains cardiovascular fitness while your legs continue recovering from the race.",
                reasoning: reasoning(for: .crossTrain, ctx: ctx, state: state),
                type: .crossTrain, optionalAddOn: nil,
                phaseLabel: "Movement Reset", intensityNote: "Aerobic effort — easy conversation",
                countdownText: cd, weeklyTarget: tgt)
        case .thu:
            return SuggestedWorkout(
                title: "Easy Run",
                distance: dist(wk == 0 ? "3–4 mi" : "4–5 mi", state: state, reduced: "2–3 mi"),
                description: "Mid-week easy run.",
                guidance: "Run comfortable. Walk any hills. Frequency before intensity, always.",
                reasoning: reasoning(for: .easy, ctx: ctx, state: state),
                type: .easy, optionalAddOn: nil,
                phaseLabel: "Movement Reset", intensityNote: "Easy — no pace goals",
                countdownText: cd, weeklyTarget: tgt)
        case .fri:
            return SuggestedWorkout(
                title: "Rest", distance: "—",
                description: "Rest before tomorrow's long run.",
                guidance: "Sleep well, eat enough. Tomorrow's long run is the priority.",
                reasoning: reasoning(for: .rest, ctx: ctx, state: state),
                type: .rest, optionalAddOn: nil,
                phaseLabel: "Movement Reset", intensityNote: nil,
                countdownText: cd, weeklyTarget: tgt)
        case .sat:
            return SuggestedWorkout(
                title: "Easy Long Run",
                distance: dist(longRange(ctx, buffer: 1), state: state, reduced: "4–5 mi"),
                description: "Your longest run since the race. Keep the effort gentle.",
                guidance: "Run easy enough to hold a full conversation. Stop early if anything feels off. This run establishes the long run habit — not fitness.",
                reasoning: reasoning(for: .longRun, ctx: ctx, state: state),
                type: .longRun, optionalAddOn: nil,
                phaseLabel: "Movement Reset", intensityNote: "Fully conversational — this is not a test",
                countdownText: cd, weeklyTarget: tgt)
        case .sun:
            return SuggestedWorkout(
                title: wk >= 1 ? "Recovery Run or Rest" : "Rest",
                distance: wk >= 1 ? "2–3 mi" : "—",
                description: wk >= 1
                    ? "Easy Sunday run to move the legs after yesterday."
                    : "Rest. The long run was enough for this week.",
                guidance: wk >= 1
                    ? "Run slower than your easy pace. Your cardiovascular system recovers faster than your legs — perceived effort will lie to you today."
                    : "The recovery run is always optional. Rest is equally valid.",
                reasoning: reasoning(for: wk >= 1 ? .recovery : .rest, ctx: ctx, state: state),
                type: wk >= 1 ? .recovery : .rest, optionalAddOn: nil,
                phaseLabel: "Movement Reset", intensityNote: wk >= 1 ? "Slower than easy" : nil,
                countdownText: cd, weeklyTarget: tgt)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Phase: Maintenance Low
    // Early off-season. 3–4 days. Habit over mileage.
    // Behavior tier drives whether strides appear and how load is framed.
    // ─────────────────────────────────────────────────────────────────────────

    private static func maintenanceLow(wd: Wd, ctx: OffSeasonContext,
                                        state: OffSeasonTrainingState) -> SuggestedWorkout {
        let cd         = countdown(ctx)
        let tgt        = targetText(ctx, state: state)
        let wk         = ctx.weekWithinPhase
        let addStrides = ctx.fitnessLevel != .beginner && wk >= 1 && state.tier == .thriving

        switch wd {
        case .mon:
            return SuggestedWorkout(
                title: "Easy Run",
                distance: dist(wk == 0 ? "3–4 mi" : "4–5 mi", state: state, reduced: "2–3 mi"),
                description: "Start the week with easy mileage.",
                guidance: state.tier == .returning
                    ? "Welcome back. Run slower than feels necessary. The goal today is showing up."
                    : "The habit of showing up matters more than the distance.",
                reasoning: reasoning(for: .easy, ctx: ctx, state: state),
                type: .easy, optionalAddOn: nil,
                phaseLabel: "Early Off-Season", intensityNote: "Easy — conversational",
                countdownText: cd, weeklyTarget: tgt)
        case .tue:
            let shouldRest = state.tier == .struggling || state.tier == .returning
            return SuggestedWorkout(
                title: shouldRest ? "Rest" : "Rest or Cross-Training",
                distance: shouldRest ? "—" : "30–45 min",
                description: shouldRest
                    ? "Rest today. Two quality easy runs this week matters more than forcing a third."
                    : "Rest or low-impact cross-training. Your choice.",
                guidance: shouldRest
                    ? "Rest without guilt. You are building the habit, not the mileage."
                    : "If energy is high, 30 minutes of easy cycling or swimming is a good outlet.",
                reasoning: reasoning(for: .rest, ctx: ctx, state: state),
                type: .rest,
                optionalAddOn: shouldRest ? nil : "Optional: 20-minute easy jog instead.",
                phaseLabel: "Early Off-Season", intensityNote: shouldRest ? nil : "Easy aerobic",
                countdownText: cd, weeklyTarget: tgt)
        case .wed:
            return SuggestedWorkout(
                title: addStrides ? "Easy + Strides" : "Easy Run",
                distance: dist(wk >= 2 ? "4–5 mi" : "3–4 mi", state: state, reduced: "2–3 mi"),
                description: addStrides
                    ? "Easy run with 4 strides. You've been consistent — your legs are ready for this."
                    : "Mid-week easy run. No structure, no pressure.",
                guidance: addStrides
                    ? "4 strides of 20 seconds quick and relaxed at the end. Full walk recovery between each."
                    : "Run at whatever pace feels genuinely comfortable.",
                reasoning: reasoning(for: addStrides ? .strides : .easy, ctx: ctx, state: state),
                type: addStrides ? .strides : .easy, optionalAddOn: nil,
                phaseLabel: "Early Off-Season",
                intensityNote: addStrides ? "Easy + 4 × 20-sec strides" : "Conversational pace",
                countdownText: cd, weeklyTarget: tgt)
        case .thu:
            return SuggestedWorkout(
                title: "Rest", distance: "—",
                description: "Rest before the long run.",
                guidance: "What you do tonight matters as much as today's run would have.",
                reasoning: reasoning(for: .rest, ctx: ctx, state: state),
                type: .rest, optionalAddOn: nil,
                phaseLabel: "Early Off-Season", intensityNote: nil,
                countdownText: cd, weeklyTarget: tgt)
        case .fri:
            return SuggestedWorkout(
                title: "Easy Run",
                distance: dist(wk >= 1 ? "4–5 mi" : "3–4 mi", state: state, reduced: "2–3 mi"),
                description: "Easy run before tomorrow's long run.",
                guidance: "Keep this genuinely easy. The goal is to stay loose — not add stress before Saturday.",
                reasoning: reasoning(for: .easy, ctx: ctx, state: state),
                type: .easy, optionalAddOn: nil,
                phaseLabel: "Early Off-Season", intensityNote: "Very easy — saving legs for Saturday",
                countdownText: cd, weeklyTarget: tgt)
        case .sat:
            return SuggestedWorkout(
                title: "Long Run",
                distance: dist(longRange(ctx, buffer: 1), state: state, reduced: "5–6 mi"),
                description: "The most important run of your off-season week.",
                guidance: "Start slower than feels right. You should be able to hold a full conversation throughout.",
                reasoning: reasoning(for: .longRun, ctx: ctx, state: state),
                type: .longRun, optionalAddOn: nil,
                phaseLabel: "Early Off-Season", intensityNote: "Easy aerobic — conversational throughout",
                countdownText: cd, weeklyTarget: tgt)
        case .sun:
            return SuggestedWorkout(
                title: wk >= 1 ? "Recovery Run" : "Rest",
                distance: wk >= 1 ? "2–3 mi" : "—",
                description: wk >= 1 ? "Short and slow after yesterday." : "Full rest.",
                guidance: wk >= 1
                    ? "If your legs are sore, walk instead. The recovery run is optional — the long run is not."
                    : "Adaptation happens during recovery. Today is as important as yesterday.",
                reasoning: reasoning(for: wk >= 1 ? .recovery : .rest, ctx: ctx, state: state),
                type: wk >= 1 ? .recovery : .rest, optionalAddOn: nil,
                phaseLabel: "Early Off-Season", intensityNote: wk >= 1 ? "Slower than feels necessary" : nil,
                countdownText: cd, weeklyTarget: tgt)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Phase: Maintenance Build
    // Progressive mileage toward plan's base. 4–5 days.
    // Micro-progression: strides appear in week 1, tempo option in week 4 (thriving).
    // ─────────────────────────────────────────────────────────────────────────

    private static func maintenanceBuild(wd: Wd, ctx: OffSeasonContext,
                                          state: OffSeasonTrainingState) -> SuggestedWorkout {
        let cd       = countdown(ctx)
        let tgt      = targetText(ctx, state: state)
        let wk       = ctx.weekWithinPhase
        let advanced = ctx.fitnessLevel == .advanced
        let addStrides = ctx.fitnessLevel != .beginner && wk >= 1
                      && state.tier != .struggling && state.tier != .returning
        let addTempo   = advanced && wk >= 4 && state.tier == .thriving

        switch wd {
        case .mon:
            return SuggestedWorkout(
                title: "Easy Run",
                distance: dist(advanced && wk >= 2 ? "6–7 mi" : "5–6 mi", state: state, reduced: "4–5 mi"),
                description: "Start the week with easy aerobic mileage.",
                guidance: "Easy runs build the aerobic engine without accumulating fatigue. They matter more than they feel like they do.",
                reasoning: reasoning(for: .easy, ctx: ctx, state: state),
                type: .easy, optionalAddOn: nil,
                phaseLabel: "Base Building", intensityNote: "Conversational pace — HR zone 2",
                countdownText: cd, weeklyTarget: tgt)
        case .tue:
            let strideCount = wk >= 3 ? 6 : 4
            return SuggestedWorkout(
                title: addStrides ? "Easy + Strides" : "Easy Run",
                distance: dist("5–6 mi", state: state, reduced: "3–4 mi"),
                description: addStrides
                    ? "Easy run with \(strideCount) strides."
                    : "Easy mid-week run.",
                guidance: addStrides
                    ? "\(strideCount) strides of 20 seconds: controlled, quick, relaxed. Full walk recovery. Strides are neuromuscular work — they don't add meaningful fatigue."
                    : "No pace goals. Run at whatever pace feels genuinely comfortable.",
                reasoning: reasoning(for: addStrides ? .strides : .easy, ctx: ctx, state: state),
                type: addStrides ? .strides : .easy, optionalAddOn: nil,
                phaseLabel: "Base Building",
                intensityNote: addStrides ? "Easy + \(strideCount) × 20-sec strides" : "Easy effort",
                countdownText: cd, weeklyTarget: tgt)
        case .wed:
            if advanced {
                return SuggestedWorkout(
                    title: addTempo ? "Moderate + Tempo Miles" : "Moderate Run",
                    distance: dist(wk >= 2 ? "8–10 mi" : "7–8 mi", state: state, reduced: "5–6 mi"),
                    description: addTempo
                        ? "Moderate run with 2–3 miles at comfortably hard tempo effort."
                        : "Mid-week aerobic run at a comfortably sustained effort.",
                    guidance: addTempo
                        ? "Run mostly aerobic, then 2–3 miles at the pace you could hold for an hour. Most quality work you need in the off-season. You've earned this by being consistent."
                        : "Not easy, not hard. A pace you could hold for two hours if asked.",
                    reasoning: reasoning(for: addTempo ? .tempo : .easy, ctx: ctx, state: state),
                    type: addTempo ? .tempo : .easy, optionalAddOn: nil,
                    phaseLabel: "Base Building",
                    intensityNote: addTempo ? "Aerobic + 2–3 mi comfortably hard" : "General aerobic — moderate",
                    countdownText: cd, weeklyTarget: tgt)
            }
            return SuggestedWorkout(
                title: "Cross-Training", distance: "45–60 min",
                description: "Mid-week cross-training.",
                guidance: "Cross-training maintains aerobic fitness without impact stress. As mileage increases, this break matters more.",
                reasoning: reasoning(for: .crossTrain, ctx: ctx, state: state),
                type: .crossTrain, optionalAddOn: "Optional: 3-mile easy jog after if energy is good.",
                phaseLabel: "Base Building", intensityNote: "Moderate aerobic effort",
                countdownText: cd, weeklyTarget: tgt)
        case .thu:
            return SuggestedWorkout(
                title: "Easy Run",
                distance: dist(advanced ? "6–7 mi" : "5–6 mi", state: state, reduced: "3–4 mi"),
                description: "Thursday easy run.",
                guidance: "Runners who build their base this way arrive at training genuinely stronger. Each easy run accumulates quietly.",
                reasoning: reasoning(for: .easy, ctx: ctx, state: state),
                type: .easy, optionalAddOn: nil,
                phaseLabel: "Base Building", intensityNote: "Easy — fully conversational",
                countdownText: cd, weeklyTarget: tgt)
        case .fri:
            return SuggestedWorkout(
                title: wk >= 2 ? "Easy Shakeout" : "Rest",
                distance: wk >= 2 ? "3–4 mi" : "—",
                description: wk >= 2 ? "Short pre-long-run shakeout." : "Rest before tomorrow's long run.",
                guidance: wk >= 2
                    ? "Under 40 minutes. The purpose is to feel loose tomorrow."
                    : "Sleep well, eat enough. Tomorrow's long run is the priority of the week.",
                reasoning: reasoning(for: wk >= 2 ? .easy : .rest, ctx: ctx, state: state),
                type: wk >= 2 ? .easy : .rest, optionalAddOn: nil,
                phaseLabel: "Base Building", intensityNote: wk >= 2 ? "Very easy — legs for Saturday" : nil,
                countdownText: cd, weeklyTarget: tgt)
        case .sat:
            let isLongRunDay = !state.longRunThisWeek
            return SuggestedWorkout(
                title: isLongRunDay ? "Long Run" : "Easy Run",
                distance: isLongRunDay
                    ? dist(longRange(ctx, buffer: 2), state: state, reduced: "6–8 mi")
                    : "4–5 mi",
                description: isLongRunDay
                    ? "The cornerstone of your off-season week."
                    : "Long run already logged this week — easy run today instead.",
                guidance: isLongRunDay
                    ? "Start slower than feels right. The long run should feel comfortable at mile 3 and honest at mile 8. If you are fading early, you went out too fast."
                    : "Keep this easy and brief. Your long run habit is established this week.",
                reasoning: reasoning(for: isLongRunDay ? .longRun : .easy, ctx: ctx, state: state),
                type: isLongRunDay ? .longRun : .easy, optionalAddOn: nil,
                phaseLabel: "Base Building", intensityNote: "Easy aerobic — conversational throughout",
                countdownText: cd, weeklyTarget: tgt)
        case .sun:
            let doRecovery = wk >= 1 && state.tier != .struggling
            return SuggestedWorkout(
                title: doRecovery ? "Recovery Run" : "Rest",
                distance: doRecovery ? "3–4 mi" : "—",
                description: doRecovery ? "Easy recovery run after the long run." : "Full rest.",
                guidance: doRecovery
                    ? "Run slower than your easy pace. Perceived effort will lie to you today."
                    : "Adaptation happens during recovery, not during the run.",
                reasoning: reasoning(for: doRecovery ? .recovery : .rest, ctx: ctx, state: state),
                type: doRecovery ? .recovery : .rest, optionalAddOn: nil,
                phaseLabel: "Base Building", intensityNote: doRecovery ? "Slower than easy" : nil,
                countdownText: cd, weeklyTarget: tgt)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Phase: Pre-Block Ramp
    // ≤3 weeks to plan start. Methodology-aware bridge.
    // ─────────────────────────────────────────────────────────────────────────

    private static func preBlockRamp(wd: Wd, ctx: OffSeasonContext,
                                      state: OffSeasonTrainingState) -> SuggestedWorkout {
        let cd        = countdown(ctx)
        let tgt       = targetText(ctx, state: state)
        let upcoming  = ctx.upcomingPlanType
        let isHansons = upcoming == .hansons || upcoming == .hansonsHalf
        let isPfitz   = upcoming == .pfitz
        let days      = ctx.daysUntilPlan ?? 14
        let urgency   = days <= 7
            ? "Your training block starts in \(days) day\(days == 1 ? "" : "s")."
            : "Your training block starts in \(days / 7) week\(days / 7 == 1 ? "" : "s")."

        switch wd {
        case .mon:
            return SuggestedWorkout(
                title: "Easy Run", distance: isHansons ? "5–6 mi" : "4–5 mi",
                description: "\(urgency) Start the week easy and fresh.",
                guidance: isHansons
                    ? "Hansons asks for six days per week from day one. These miles are already training that habit."
                    : "Arriving healthy and rested matters more than any mileage you can squeeze in now.",
                reasoning: reasoning(for: .easy, ctx: ctx, state: state),
                type: .easy, optionalAddOn: nil,
                phaseLabel: "Pre-Block Ramp", intensityNote: "Easy — conversational",
                countdownText: cd, weeklyTarget: tgt)
        case .tue:
            return SuggestedWorkout(
                title: "Easy + Strides", distance: "4–5 mi",
                description: "Easy run with strides to maintain leg speed.",
                guidance: "4–6 strides of 20 seconds quick and relaxed. Your plan will include quality work — these mean the first session won't feel like a shock.",
                reasoning: reasoning(for: .strides, ctx: ctx, state: state),
                type: .strides, optionalAddOn: nil,
                phaseLabel: "Pre-Block Ramp", intensityNote: "Easy + 4–6 × 20-sec strides",
                countdownText: cd, weeklyTarget: tgt)
        case .wed:
            return SuggestedWorkout(
                title: isPfitz ? "Moderate Run" : "Cross-Training",
                distance: isPfitz ? "6–8 mi" : "40 min",
                description: isPfitz
                    ? "Pfitz includes a medium-long run most weeks. This is preparation for that habit."
                    : "Cross-training to protect your joints before the block begins.",
                guidance: isPfitz
                    ? "Comfortable aerobic effort — honest but well within control."
                    : "Bike, swim, or elliptical. Arrive at week one with healthy joints.",
                reasoning: reasoning(for: isPfitz ? .easy : .crossTrain, ctx: ctx, state: state),
                type: isPfitz ? .easy : .crossTrain, optionalAddOn: nil,
                phaseLabel: "Pre-Block Ramp",
                intensityNote: isPfitz ? "General aerobic — honest but controlled" : "Easy aerobic",
                countdownText: cd, weeklyTarget: tgt)
        case .thu:
            return SuggestedWorkout(
                title: "Easy Run", distance: isHansons ? "5–6 mi" : "4–5 mi",
                description: "Pre-plan easy miles. Keep the legs fresh.",
                guidance: isHansons
                    ? "You are about to run six days per week. These miles are training that habit."
                    : "Easy running now is the best preparation for whatever week one asks.",
                reasoning: reasoning(for: .easy, ctx: ctx, state: state),
                type: .easy, optionalAddOn: nil,
                phaseLabel: "Pre-Block Ramp", intensityNote: "Easy — fully conversational",
                countdownText: cd, weeklyTarget: tgt)
        case .fri:
            return SuggestedWorkout(
                title: days <= 7 ? "Rest" : "Easy Shakeout",
                distance: days <= 7 ? "—" : "3–4 mi",
                description: days <= 7 ? "Rest before your last long run before training." : "Short and easy.",
                guidance: days <= 7 ? "Your training block starts next week. Rest well." : "Keep it brief.",
                reasoning: reasoning(for: days <= 7 ? .rest : .easy, ctx: ctx, state: state),
                type: days <= 7 ? .rest : .easy, optionalAddOn: nil,
                phaseLabel: "Pre-Block Ramp", intensityNote: nil,
                countdownText: cd, weeklyTarget: tgt)
        case .sat:
            return SuggestedWorkout(
                title: "Long Run", distance: longRange(ctx, buffer: 1),
                description: days <= 7
                    ? "Your last long run before training begins. Run it well."
                    : "Pre-plan long run. Build the habit you will use every week.",
                guidance: days <= 7
                    ? "Run easy and enjoy it. Arrive at week one with this long run in your legs — not an ambitious effort."
                    : "Start slower than feels right. Easy and comfortable throughout.",
                reasoning: reasoning(for: .longRun, ctx: ctx, state: state),
                type: .longRun, optionalAddOn: nil,
                phaseLabel: "Pre-Block Ramp", intensityNote: "Easy throughout — this is not a test",
                countdownText: cd, weeklyTarget: tgt)
        case .sun:
            return SuggestedWorkout(
                title: "Rest", distance: "—",
                description: "Rest. Your training block starts soon.",
                guidance: "Arrive rested. Every decision between now and day one should answer: does this help me show up healthy?",
                reasoning: reasoning(for: .rest, ctx: ctx, state: state),
                type: .rest, optionalAddOn: nil,
                phaseLabel: "Pre-Block Ramp", intensityNote: nil,
                countdownText: cd, weeklyTarget: tgt)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Phase: Indefinite Maintenance
    // No upcoming plan. No recent race. Enjoyable, sustainable running.
    // Behavioral tier is the primary driver — no external deadline exists.
    // ─────────────────────────────────────────────────────────────────────────

    private static func indefiniteMaintenance(wd: Wd, ctx: OffSeasonContext,
                                               state: OffSeasonTrainingState) -> SuggestedWorkout {
        let cd         = countdown(ctx)
        let tgt        = targetText(ctx, state: state)
        let advanced   = ctx.fitnessLevel == .advanced
        let addStrides = ctx.fitnessLevel != .beginner && state.tier == .thriving

        switch wd {
        case .mon:
            return SuggestedWorkout(
                title: "Easy Run",
                distance: dist(advanced ? "5–6 mi" : "4–5 mi", state: state, reduced: "3–4 mi"),
                description: "Start the week with easy, enjoyable running.",
                guidance: state.tier == .returning
                    ? "Welcome back. Slower than feels necessary. The only goal today is being out there."
                    : "No race on the horizon means no pressure. Run because you enjoy it.",
                reasoning: reasoning(for: .easy, ctx: ctx, state: state),
                type: .easy, optionalAddOn: nil,
                phaseLabel: "Maintenance", intensityNote: "Easy and enjoyable",
                countdownText: cd, weeklyTarget: tgt)
        case .tue:
            return SuggestedWorkout(
                title: addStrides ? "Easy + Strides" : "Easy Run",
                distance: dist("4–5 mi", state: state, reduced: "2–3 mi"),
                description: addStrides
                    ? "Easy run with strides. You've been consistent — keep it sharp."
                    : "Mid-week easy run.",
                guidance: addStrides
                    ? "6 strides of 20 seconds at the end. Quick and relaxed. Full walk recovery between each."
                    : "Run your favorite route at comfortable effort. No goals today.",
                reasoning: reasoning(for: addStrides ? .strides : .easy, ctx: ctx, state: state),
                type: addStrides ? .strides : .easy, optionalAddOn: nil,
                phaseLabel: "Maintenance",
                intensityNote: addStrides ? "Easy + 6 × 20-sec strides" : "Comfortable pace",
                countdownText: cd, weeklyTarget: tgt)
        case .wed:
            return SuggestedWorkout(
                title: "Cross-Training or Rest", distance: "30–45 min",
                description: "Cross-train, rest, or do something you genuinely enjoy moving.",
                guidance: "Yoga, cycling, hiking, swimming — all count. The off-season is the best time to maintain fitness through variety.",
                reasoning: reasoning(for: .crossTrain, ctx: ctx, state: state),
                type: .crossTrain, optionalAddOn: nil,
                phaseLabel: "Maintenance", intensityNote: "Moderate — enjoy it",
                countdownText: cd, weeklyTarget: tgt)
        case .thu:
            return SuggestedWorkout(
                title: "Easy Run",
                distance: dist(advanced ? "6–7 mi" : "4–5 mi", state: state, reduced: "3–4 mi"),
                description: "Thursday easy run.",
                guidance: state.tier == .thriving
                    ? "The runners who show up for this run without race pressure or structure are the ones who arrive at their next block genuinely ready. That's you."
                    : "The off-season runner who keeps showing up quietly is building something. Every run counts.",
                reasoning: reasoning(for: .easy, ctx: ctx, state: state),
                type: .easy, optionalAddOn: nil,
                phaseLabel: "Maintenance", intensityNote: "Easy — conversational",
                countdownText: cd, weeklyTarget: tgt)
        case .fri:
            return SuggestedWorkout(
                title: state.tier == .thriving ? "Easy Shakeout" : "Rest",
                distance: state.tier == .thriving ? "3–4 mi" : "—",
                description: state.tier == .thriving
                    ? "Short easy run. Staying loose for tomorrow."
                    : "Rest before tomorrow's long run.",
                guidance: state.tier == .thriving
                    ? "Keep this brief and easy. The long run is tomorrow."
                    : "Rest, eat well, sleep enough.",
                reasoning: reasoning(for: state.tier == .thriving ? .easy : .rest, ctx: ctx, state: state),
                type: state.tier == .thriving ? .easy : .rest, optionalAddOn: nil,
                phaseLabel: "Maintenance", intensityNote: nil,
                countdownText: cd, weeklyTarget: tgt)
        case .sat:
            return SuggestedWorkout(
                title: "Long Run",
                distance: dist(longRange(ctx, buffer: 2), state: state, reduced: "5–7 mi"),
                description: "The cornerstone of your week.",
                guidance: "Long runs between races keep your aerobic base from eroding. Run easy, run consistently, and your next block starts from a stronger place than the last.",
                reasoning: reasoning(for: .longRun, ctx: ctx, state: state),
                type: .longRun, optionalAddOn: nil,
                phaseLabel: "Maintenance", intensityNote: "Easy aerobic — conversational throughout",
                countdownText: cd, weeklyTarget: tgt)
        case .sun:
            return SuggestedWorkout(
                title: "Rest", distance: "—",
                description: "Rest. Recovery is part of training even between blocks.",
                guidance: "The off-season is for recharging — physically and mentally. Rest without guilt.",
                reasoning: reasoning(for: .rest, ctx: ctx, state: state),
                type: .rest, optionalAddOn: nil,
                phaseLabel: "Maintenance", intensityNote: nil,
                countdownText: cd, weeklyTarget: tgt)
        }
    }
}
