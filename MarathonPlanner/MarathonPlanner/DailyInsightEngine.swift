import Foundation

// MARK: - Daily Insight

struct DailyInsight {
    let message  : String
    let detail   : String?
    let icon     : String
    let category : InsightCategory
}

enum InsightCategory {
    case consistency
    case progress
    case missed
    case upcoming
    case phase
    case motivation
    case raceWeek
}

// MARK: - Engine

struct DailyInsightEngine {
    
    // MARK: - Public
    
    static func generate(for plan: SavedPlan) -> DailyInsight {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        let ctx   = buildContext(plan: plan, today: today, cal: cal)
        
        // Priority order — most specific wins
        if ctx.isRaceDay               { return insightRaceDay(ctx) }
        if ctx.daysToRace <= 7         { return insightRaceWeek(ctx) }
        if ctx.isInTaper               { return insightTaper(ctx) }
        if ctx.isPeakWeek              { return insightPeak(ctx) }
        if ctx.daysSinceLastRun >= 2
            && ctx.daysSinceLastRun < 5 { return insightMissed(ctx) }
        if ctx.tomorrowIsLongRun       { return insightLongRunEve(ctx) }
        if ctx.todayIsLongRun
            && !ctx.todayCompleted     { return insightLongRunDay(ctx) }
        if ctx.weekCompletionPct >= 1.0 { return insightWeekComplete(ctx) }
        if ctx.weekCompletionPct >= 0.6 { return insightProgress(ctx) }
        if ctx.currentStreak >= 3      { return insightStreak(ctx) }
        return insightDefault(ctx)
    }
    
    // MARK: - Context Builder
    
    private struct Context {
        var plan               : SavedPlan
        var today              : Date
        var currentWeek        : SavedWeek?
        var todayDay           : SavedDay?
        var tomorrowDay        : SavedDay?
        var daysToRace         : Int
        var isRaceDay          : Bool
        var isInTaper          : Bool
        var isPeakWeek         : Bool
        var weekCompletionPct  : Double
        var completedThisWeek  : Int
        var trackableThisWeek  : Int
        var daysSinceLastRun   : Int
        var currentStreak      : Int
        var todayIsLongRun     : Bool
        var tomorrowIsLongRun  : Bool
        var todayCompleted     : Bool
        var totalWeeks         : Int
        var currentWeekNum     : Int
        var phaseName          : String
        var weeklyMilesPlanned : Double
        var weeklyMilesDone    : Double
    }
    
    private static func buildContext(
        plan  : SavedPlan,
        today : Date,
        cal   : Calendar
    ) -> Context {
        
        var ctx          = Context(
            plan:              plan,
            today:             today,
            currentWeek:       nil,
            todayDay:          nil,
            tomorrowDay:       nil,
            daysToRace:        0,
            isRaceDay:         false,
            isInTaper:         false,
            isPeakWeek:        false,
            weekCompletionPct: 0,
            completedThisWeek: 0,
            trackableThisWeek: 0,
            daysSinceLastRun:  0,
            currentStreak:     0,
            todayIsLongRun:    false,
            tomorrowIsLongRun: false,
            todayCompleted:    false,
            totalWeeks:        plan.weeks.count,
            currentWeekNum:    1,
            phaseName:         "",
            weeklyMilesPlanned:0,
            weeklyMilesDone:   0
        )
        
        // Days to race
        let raceStart = cal.startOfDay(for: plan.raceDate)
        ctx.daysToRace = max(0, cal.dateComponents(
            [.day], from: today, to: raceStart).day ?? 0)
        ctx.isRaceDay  = ctx.daysToRace == 0
        
        // Find current week and today/tomorrow days
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
        
        for week in plan.weeks {
            for day in week.days {
                let d = cal.startOfDay(for: day.date)
                if d == today {
                    ctx.todayDay    = day
                    ctx.currentWeek = week
                    ctx.currentWeekNum = week.weekNumber
                    ctx.phaseName   = week.phase
                    ctx.todayIsLongRun = day.workoutType.contains("Long Run")
                    ctx.todayCompleted = day.completionStatus == .completed
                    || day.completionStatus == .modified
                }
                if d == cal.startOfDay(for: tomorrow) {
                    ctx.tomorrowDay = day
                    ctx.tomorrowIsLongRun = day.workoutType
                        .contains("Long Run")
                }
            }
        }
        
        // Week stats
        if let week = ctx.currentWeek {
            let trackable = week.days.filter { $0.workoutType != "Rest" }
            let done      = trackable.filter {
                $0.completionStatus == .completed
                || $0.completionStatus == .modified
            }
            ctx.trackableThisWeek  = trackable.count
            ctx.completedThisWeek  = done.count
            ctx.weekCompletionPct  = trackable.isEmpty
            ? 0
            : Double(done.count) / Double(trackable.count)
            ctx.weeklyMilesPlanned = week.totalMiles
            ctx.weeklyMilesDone    = week.actualTotalMiles
        }
        
        // Taper / peak detection
        let totalW      = plan.weeks.count
        let currentW    = ctx.currentWeekNum
        let weeksToRace = totalW - currentW
        ctx.isInTaper   = weeksToRace <= 2
        && ctx.phaseName.lowercased().contains("taper")
        ctx.isPeakWeek  = ctx.phaseName.lowercased().contains("peak")
        
        // Days since last completed run
        let allDays = plan.weeks.flatMap { $0.days }
            .filter { $0.workoutType != "Rest" }
            .sorted { $0.date < $1.date }
        
        var lastRunDate: Date? = nil
        for day in allDays {
            let d = cal.startOfDay(for: day.date)
            guard d < today else { break }
            if day.completionStatus == .completed
                || day.completionStatus == .modified {
                lastRunDate = d
            }
        }
        if let last = lastRunDate {
            ctx.daysSinceLastRun = cal.dateComponents(
                [.day], from: last, to: today).day ?? 0
        } else {
            ctx.daysSinceLastRun = 99
        }
        
        // Current streak
        var streak = 0
        var checkDate = cal.date(byAdding: .day, value: -1, to: today)!
        for _ in 0..<30 {
            let cd = cal.startOfDay(for: checkDate)
            let match = allDays.first {
                cal.startOfDay(for: $0.date) == cd
            }
            if let m = match,
               (m.completionStatus == .completed
                || m.completionStatus == .modified) {
                streak += 1
                checkDate = cal.date(byAdding: .day,
                                     value: -1, to: checkDate)!
            } else {
                break
            }
        }
        ctx.currentStreak = streak
        
        return ctx
    }
    
    // MARK: - Insight Generators
    
    private static func insightRaceDay(_ c: Context) -> DailyInsight {
        DailyInsight(
            message:  "Race day is here.",
            detail:   "Everything you trained for starts today.",
            icon:     "flag.checkered",
            category: .raceWeek
        )
    }
    
    private static func insightRaceWeek(_ c: Context) -> DailyInsight {
        let days = c.daysToRace
        let msg  = days == 1
        ? "Race is tomorrow."
        : "\(days) days to race day."
        return DailyInsight(
            message:  msg,
            detail:   "Protect your legs. Trust what you have built.",
            icon:     "flag.checkered",
            category: .raceWeek
        )
    }
    
    private static func insightTaper(_ c: Context) -> DailyInsight {
        let options: [(String, String)] = [
            ("You're in taper.",
             "Trust the process. The fitness is already there."),
            ("Taper week.",
             "Less is more right now. Rest is training."),
            ("The hard work is done.",
             "Your body is adapting. Let it."),
        ]
        let pick = options[dayIndex() % options.count]
        return DailyInsight(
            message:  pick.0,
            detail:   pick.1,
            icon:     "arrow.down.right.and.arrow.up.left",
            category: .phase
        )
    }
    
    private static func insightPeak(_ c: Context) -> DailyInsight {
        let options: [(String, String)] = [
            ("Peak week.",
             "This is where your fitness ceiling gets raised."),
            ("Highest mileage week.",
             "It is supposed to feel hard. That is the point."),
            ("Peak week is here.",
             "Get through this and taper starts."),
        ]
        let pick = options[dayIndex() % options.count]
        return DailyInsight(
            message:  pick.0,
            detail:   pick.1,
            icon:     "mountain.2.fill",
            category: .phase
        )
    }
    
    private static func insightMissed(_ c: Context) -> DailyInsight {
        let d = c.daysSinceLastRun
        let msg = d == 2
        ? "Two days off the plan."
        : "\(d) days since your last run."
        return DailyInsight(
            message:  msg,
            detail:   "Today is a clean slate. Get one run in.",
            icon:     "arrow.counterclockwise",
            category: .missed
        )
    }
    
    private static func insightLongRunEve(_ c: Context) -> DailyInsight {
        let miles = c.tomorrowDay?.miles ?? 0
        let detail = miles > 0
        ? String(format: "%.0f miles on the schedule. Sleep well.", miles)
        : "Get the sleep. Stay off your feet tonight."
        return DailyInsight(
            message:  "Long run tomorrow.",
            detail:   detail,
            icon:     "moon.stars",
            category: .upcoming
        )
    }
    
    private static func insightLongRunDay(_ c: Context) -> DailyInsight {
        let miles = c.todayDay?.miles ?? 0
        let msg   = miles > 0
        ? String(format: "%.0f mile long run today.", miles)
        : "Long run day."
        return DailyInsight(
            message:  msg,
            detail:   "The most important run of your week. Go own it.",
            icon:     "arrow.left.and.right",
            category: .upcoming
        )
    }
    
    private static func insightWeekComplete(_ c: Context) -> DailyInsight {
        let miles = String(format: "%.0f", c.weeklyMilesDone)
        return DailyInsight(
            message:  "Full week complete.",
            detail:   "\(miles) miles in the bank. Rest up.",
            icon:     "checkmark.seal.fill",
            category: .progress
        )
    }
    
    private static func insightProgress(_ c: Context) -> DailyInsight {
        let pct     = Int(c.weekCompletionPct * 100)
        let done    = c.completedThisWeek
        let total   = c.trackableThisWeek
        let options: [(String, String)] = [
            ("\(pct)% through your week.",
             "\(done) of \(total) workouts done. Keep the momentum."),
            ("\(done) of \(total) workouts complete.",
             "You are building something real."),
        ]
        let pick = options[dayIndex() % options.count]
        return DailyInsight(
            message:  pick.0,
            detail:   pick.1,
            icon:     "chart.bar.fill",
            category: .progress
        )
    }
    
    private static func insightStreak(_ c: Context) -> DailyInsight {
        let s = c.currentStreak
        return DailyInsight(
            message:  "\(s) days in a row.",
            detail:   "Consistency is the most underrated training tool.",
            icon:     "flame.fill",
            category: .consistency
        )
    }
    
    private static func insightDefault(_ c: Context) -> DailyInsight {
        let week  = c.currentWeekNum
        let total = c.totalWeeks
        let options: [(String, String, String)] = [
            ("Week \(week) of \(total).",
             "Every session is a deposit into race day.",
             "calendar"),
            ("Stay consistent.",
             "The runners who show up every week are the ones who PR.",
             "figure.run"),
            ("Training block in progress.",
             "Week \(week) of \(total). You are right on track.",
             "chart.line.uptrend.xyaxis"),
        ]
        let pick = options[dayIndex() % options.count]
        return DailyInsight(
            message:  pick.0,
            detail:   pick.1,
            icon:     pick.2,
            category: .motivation
        )
    }
    
    // MARK: - Day index for variety without randomness
    
    private static func dayIndex() -> Int {
        Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
    }
}
