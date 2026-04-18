//
//  File.swift
//  ProjectPR
//
//  Created by Steven Lee on 4/17/26.
//

import Foundation

class HansonsEngine {

    enum Phase {
        case speed
        case strength
        case taper
    }

    static func generatePlan(
        fitness: FitnessSummary,
        goalTime: Double
    ) -> [TrainingWeek] {

        let goalPace = goalTime / 26.2
        let baseMiles = fitness.baseMiles
        let peakMiles = baseMiles * 1.25

        var plan: [TrainingWeek] = []

        for week in 1...12 {

            // MARK: Phase
            let phase: Phase
            if week <= 4 {
                phase = .speed
            } else if week <= 10 {
                phase = .strength
            } else {
                phase = .taper
            }

            // MARK: Weekly Mileage
            let progression = min(Double(week) / 10.0, 1.0)
            var weeklyMiles = baseMiles + (peakMiles - baseMiles) * progression

            if phase == .taper {
                weeklyMiles *= (week == 11) ? 0.8 : 0.6
            }

            // MARK: Long Run
            var longRun = min(16.0, weeklyMiles * 0.28)

            switch phase {
            case .speed:
                longRun *= 0.85
            case .strength:
                break
            case .taper:
                longRun *= (week == 11) ? 0.8 : 0.6
            }

            // MARK: Pace Ranges
            let easyLow = goalPace + 1.0
            let easyHigh = goalPace + 1.5

            var tempoLow = goalPace - 0.4
            var tempoHigh = goalPace - 0.2

            var intervalLow = goalPace - 1.0
            var intervalHigh = goalPace - 0.6

            switch phase {
            case .speed:
                tempoLow -= 0.2
                tempoHigh -= 0.2

            case .strength:
                break

            case .taper:
                tempoLow += 0.1
                tempoHigh += 0.1
            }

            let weekPlan = buildWeek(
                week: week,
                weeklyMiles: weeklyMiles,
                longRun: longRun,
                easyLow: easyLow,
                easyHigh: easyHigh,
                tempoLow: tempoLow,
                tempoHigh: tempoHigh,
                intervalLow: intervalLow,
                intervalHigh: intervalHigh,
                phase: phase
            )

            plan.append(weekPlan)
        }

        return plan
    }
}

extension HansonsEngine {

    static func buildWeek(
        week: Int,
        weeklyMiles: Double,
        longRun: Double,
        easyLow: Double,
        easyHigh: Double,
        tempoLow: Double,
        tempoHigh: Double,
        intervalLow: Double,
        intervalHigh: Double,
        phase: Phase
    ) -> TrainingWeek {

        let mon = 0.15 * weeklyMiles
        let tue = 0.18 * weeklyMiles
        let wed = 0.15 * weeklyMiles
        let thu = 0.18 * weeklyMiles
        let sun = weeklyMiles - (mon + tue + wed + thu + longRun)

        // MARK: Workout Types
        let tuesdayType: RunType
        let tuesdayNotes: String

        switch phase {
        case .speed:
            tuesdayType = .interval
            tuesdayNotes = "6 x 800m @ interval pace"

        case .strength:
            tuesdayType = .tempo
            tuesdayNotes = "5–8 miles @ marathon pace"

        case .taper:
            tuesdayType = .tempo
            tuesdayNotes = "Light tempo (shortened)"
        }

        let thursdayType: RunType = (week % 2 == 0) ? .tempo : .easy

        let days: [TrainingDay] = [

            TrainingDay(
                day: "Mon",
                distance: mon,
                type: .easy,
                paceRange: paceString(low: easyLow, high: easyHigh),
                notes: nil
            ),

            TrainingDay(
                day: "Tue",
                distance: tue,
                type: tuesdayType,
                paceRange: tuesdayType == .interval
                    ? paceString(low: intervalLow, high: intervalHigh)
                    : paceString(low: tempoLow, high: tempoHigh),
                notes: tuesdayNotes
            ),

            TrainingDay(
                day: "Wed",
                distance: wed,
                type: .easy,
                paceRange: paceString(low: easyLow, high: easyHigh),
                notes: nil
            ),

            TrainingDay(
                day: "Thu",
                distance: thu,
                type: thursdayType,
                paceRange: paceString(low: tempoLow, high: tempoHigh),
                notes: thursdayType == .tempo ? "Steady effort" : nil
            ),

            TrainingDay(
                day: "Fri",
                distance: 0,
                type: .rest,
                paceRange: "-",
                notes: "Rest day"
            ),

            TrainingDay(
                day: "Sat",
                distance: longRun,
                type: .longRun,
                paceRange: paceString(low: easyLow, high: easyHigh),
                notes: "Keep controlled effort"
            ),

            TrainingDay(
                day: "Sun",
                distance: sun,
                type: .recovery,
                paceRange: paceString(low: easyHigh, high: easyHigh + 0.5),
                notes: "Recovery run"
            )
        ]

        return TrainingWeek(
            weekNumber: week,
            totalMiles: weeklyMiles,
            days: days
        )
    }

    static func paceString(low: Double, high: Double) -> String {
        "\(formatPace(low)) - \(formatPace(high))"
    }

    static func formatPace(_ pace: Double) -> String {
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d /mi", minutes, seconds)
    }
}
