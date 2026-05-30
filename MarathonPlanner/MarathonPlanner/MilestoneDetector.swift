import Foundation
import SwiftUI

// MARK: - Milestone

enum Milestone: String, Codable, Equatable {
    // Mileage
    case firstDoubleFigureLongRun
    case firstFifteenMileLongRun
    case longestRunOfBlock
    case twentyMileLongRun
    case peakWeek
    case fiftyMileWeek

    // Progress
    case firstWorkoutCompleted
    case quarterwayThroughPlan
    case halfwayThroughPlan
    case threeQuartersThroughPlan
    case firstPerfectWeek
    case threeConsecutivePerfectWeeks

    // Phase
    case lastLongRunBeforeTaper
    case taperBegins
    case finalWeek
    case raceWeekStarts

    // Streaks
    case sevenDayStreak
    case fourteenDayStreak

    // MARK: - Display

    var headline: String {
        switch self {
        case .firstDoubleFigureLongRun:
            return "Double figures."
        case .firstFifteenMileLongRun:
            return "15 miles."
        case .longestRunOfBlock:
            return "Longest run of your block."
        case .twentyMileLongRun:
            return "20 miles."
        case .peakWeek:
            return "Peak week complete."
        case .fiftyMileWeek:
            return "50 miles in a week."
        case .firstWorkoutCompleted:
            return "The plan is real now."
        case .quarterwayThroughPlan:
            return "One quarter complete."
        case .halfwayThroughPlan:
            return "Halfway there."
        case .threeQuartersThroughPlan:
            return "Three quarters done."
        case .firstPerfectWeek:
            return "Perfect week."
        case .threeConsecutivePerfectWeeks:
            return "Three perfect weeks."
        case .lastLongRunBeforeTaper:
            return "The hay is in the barn."
        case .taperBegins:
            return "Taper starts now."
        case .finalWeek:
            return "Final week of training."
        case .raceWeekStarts:
            return "Race week is here."
        case .sevenDayStreak:
            return "Seven days straight."
        case .fourteenDayStreak:
            return "Fourteen consecutive days."
        }
    }

    var subline: String {
        switch self {
        case .firstDoubleFigureLongRun:
            return "Double figures on the long run. The training block just got serious."
        case .firstFifteenMileLongRun:
            return "This is the distance where runners find out who they are."
        case .longestRunOfBlock:
            return "Every long run builds on the last. This was your biggest yet."
        case .twentyMileLongRun:
            return "You have now run far enough to know you can finish the marathon."
        case .peakWeek:
            return "The hardest week of your training is behind you."
        case .fiftyMileWeek:
            return "Fifty miles in seven days. You are in serious training now."
        case .firstWorkoutCompleted:
            return "The first step is always the most important. Now keep going."
        case .quarterwayThroughPlan:
            return "One quarter in. The habit is forming."
        case .halfwayThroughPlan:
            return "The back half is where fitness becomes confidence."
        case .threeQuartersThroughPlan:
            return "The hardest part of training is done. Finish strong."
        case .firstPerfectWeek:
            return "Every workout. Every session. Consistency is everything."
        case .threeConsecutivePerfectWeeks:
            return "Three weeks of perfect execution. You are doing everything right."
        case .lastLongRunBeforeTaper:
            return "Your long runs are done. Trust what you have built."
        case .taperBegins:
            return "The work is done. Rest, eat, and trust the process."
        case .finalWeek:
            return "One week to go. Stay loose, stay sharp, trust your training."
        case .raceWeekStarts:
            return "Everything has been leading to this. You are ready."
        case .sevenDayStreak:
            return "Seven days without missing a session. Momentum is building."
        case .fourteenDayStreak:
            return "Two weeks of consistency. This is how fitness is built."
        }
    }

    var icon: String {
        switch self {
        case .firstDoubleFigureLongRun, .firstFifteenMileLongRun,
             .longestRunOfBlock, .twentyMileLongRun:
            return "arrow.left.and.right"
        case .peakWeek, .fiftyMileWeek:
            return "mountain.2.fill"
        case .firstWorkoutCompleted:
            return "checkmark.circle"
        case .quarterwayThroughPlan, .halfwayThroughPlan,
             .threeQuartersThroughPlan:
            return "chart.line.uptrend.xyaxis"
        case .firstPerfectWeek, .threeConsecutivePerfectWeeks:
            return "star.fill"
        case .lastLongRunBeforeTaper:
            return "checkmark.seal.fill"
        case .taperBegins:
            return "arrow.down.right.and.arrow.up.left"
        case .finalWeek, .raceWeekStarts:
            return "flag.checkered"
        case .sevenDayStreak, .fourteenDayStreak:
            return "flame.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .longestRunOfBlock, .twentyMileLongRun,
             .firstFifteenMileLongRun, .fiftyMileWeek,
             .firstDoubleFigureLongRun:
            return Color(hex: "0A84FF")
        case .lastLongRunBeforeTaper, .firstPerfectWeek,
             .threeConsecutivePerfectWeeks, .firstWorkoutCompleted:
            return Color(hex: "30D158")
        case .halfwayThroughPlan, .threeQuartersThroughPlan,
             .quarterwayThroughPlan, .sevenDayStreak,
             .fourteenDayStreak:
            return Color(hex: "FF9F0A")
        case .peakWeek:
            return Color(hex: "FF453A")
        case .taperBegins, .finalWeek:
            return Color(hex: "BF5AF2")
        case .raceWeekStarts:
            return Color(hex: "FFD60A")
        }
    }
}

// MARK: - Milestone Detector

struct MilestoneDetector {

    /// Call immediately after a workout is marked complete.
    /// Returns at most one milestone — the highest priority one detected.
    static func detect(
        completedDay : SavedDay,
        plan         : SavedPlan,
        currentWeek  : SavedWeek
    ) -> Milestone? {

        let allDays = plan.weeks.flatMap { $0.days }
        let isLong  = isLongRun(completedDay)

        // ── Ordered by emotional priority ──────────────────────────

        // 1. Last long run before taper
        if isLong {
            let nextWeekPhase = plan.weeks
                .first { $0.weekNumber == currentWeek.weekNumber + 1 }?
                .phase
            let futureLongRuns = allDays.filter {
                isLongRun($0) && $0.date > completedDay.date
            }
            if nextWeekPhase == .taper || futureLongRuns.isEmpty {
                return .lastLongRunBeforeTaper
            }
        }

        // 2. 20-mile long run (marathon only) — fire on the very first one
        if isLong && plan.settings.raceType == .marathon {
            let miles = completedDay.actualMiles ?? completedDay.miles
            if miles >= 20 {
                let isFirstTwenty = allDays.filter {
                    $0.id != completedDay.id
                        && isLongRun($0)
                        && ($0.actualMiles ?? $0.miles) >= 20
                        && isComplete($0)
                }.isEmpty   // isEmpty = no other completed 20-milers = this is the first
                if isFirstTwenty { return .twentyMileLongRun }
            }
        }

        // 3. Longest run of the block
        if isLong {
            let thisMiles = completedDay.actualMiles ?? completedDay.miles
            let prevMax   = allDays.filter {
                $0.id != completedDay.id
                    && isLongRun($0)
                    && isComplete($0)
            }.map { $0.actualMiles ?? $0.miles }.max() ?? 0
            if thisMiles > prevMax && thisMiles >= 10 {
                return .longestRunOfBlock
            }
        }

        // 4. First 15-mile long run
        if isLong {
            let miles = completedDay.actualMiles ?? completedDay.miles
            if miles >= 15 {
                let firstTime = allDays.filter {
                    $0.id != completedDay.id
                        && isLongRun($0)
                        && ($0.actualMiles ?? $0.miles) >= 15
                        && isComplete($0)
                }.isEmpty
                if firstTime { return .firstFifteenMileLongRun }
            }
        }

        // 5. First double-figure long run
        if isLong {
            let miles = completedDay.actualMiles ?? completedDay.miles
            if miles >= 10 {
                let firstTime = allDays.filter {
                    $0.id != completedDay.id
                        && isLongRun($0)
                        && ($0.actualMiles ?? $0.miles) >= 10
                        && isComplete($0)
                }.isEmpty
                if firstTime { return .firstDoubleFigureLongRun }
            }
        }

        // 6. Three quarters through plan
        let trackable = allDays.filter { $0.workoutType != "Rest" }
        let done      = allDays.filter {
            $0.workoutType != "Rest" && isComplete($0)
        }
        let pct = Double(done.count) / Double(max(trackable.count, 1))
        if pct >= 0.75 && pct < 0.78 { return .threeQuartersThroughPlan }

        // 7. Halfway
        if pct >= 0.50 && pct < 0.53 { return .halfwayThroughPlan }

        // 8. One quarter
        if pct >= 0.25 && pct < 0.28 { return .quarterwayThroughPlan }

        // 9. Three consecutive perfect weeks
        let sortedWeeks = plan.weeks.sorted { $0.weekNumber < $1.weekNumber }
        let idx = sortedWeeks.firstIndex { $0.id == currentWeek.id } ?? 0
        if idx >= 2 {
            let w0 = sortedWeeks[idx]
            let w1 = sortedWeeks[idx - 1]
            let w2 = sortedWeeks[idx - 2]
            let allPerfect = [w0, w1, w2].allSatisfy {
                $0.completionPercentage >= 1.0
                    && $0.trackableDayCount > 0
            }
            if allPerfect { return .threeConsecutivePerfectWeeks }
        }

        // 10. First perfect week
        let trackableThisWeek = currentWeek.days.filter {
            $0.workoutType != "Rest"
        }
        let doneThisWeek = trackableThisWeek.filter { isComplete($0) }
        if doneThisWeek.count == trackableThisWeek.count
            && !trackableThisWeek.isEmpty {
            let prevPerfect = plan.weeks.filter {
                $0.weekNumber < currentWeek.weekNumber
                    && $0.completionPercentage >= 1.0
                    && $0.trackableDayCount > 0
            }
            if prevPerfect.isEmpty { return .firstPerfectWeek }
        }

        // 11. 50-mile week
        if currentWeek.actualTotalMiles >= 50 {
            let prevFiftyWeeks = plan.weeks.filter {
                $0.weekNumber < currentWeek.weekNumber
                    && $0.actualTotalMiles >= 50
            }
            if prevFiftyWeeks.isEmpty { return .fiftyMileWeek }
        }

        // 12. 14-day streak — fire exactly once on day 7 / day 14
        let streak = consecutiveStreak(before: completedDay, in: allDays)
        if streak == 14 { return .fourteenDayStreak }
        if streak == 7  { return .sevenDayStreak }

        // 13. First workout ever completed
        let prevCompleted = allDays.filter {
            $0.id != completedDay.id
                && $0.workoutType != "Rest"
                && isComplete($0)
        }
        if prevCompleted.isEmpty { return .firstWorkoutCompleted }

        return nil
    }

    // MARK: - Helpers

    private static func isLongRun(_ day: SavedDay) -> Bool {
        day.workoutType == "Long Run"
            || day.workoutType == "Long Run w/ MP Finish"
            || day.workoutType == "Long Run w/ HMP Finish"
    }

    private static func isComplete(_ day: SavedDay) -> Bool {
        day.completionStatus == .completed
            || day.completionStatus == .modified
    }

    private static func consecutiveStreak(
        before day : SavedDay,
        in days    : [SavedDay]
    ) -> Int {
        let runDays = days
            .filter { $0.workoutType != "Rest" }
            .sorted { $0.date > $1.date }

        var streak = 0
        for d in runDays {
            if d.date > day.date { continue }
            if isComplete(d) { streak += 1 }
            else { break }
        }
        return streak
    }
}
