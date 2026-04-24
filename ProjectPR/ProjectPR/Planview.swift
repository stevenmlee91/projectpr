//
//  Planview.swift
//  ProjectPR
//
//  Created by Steven Lee on 4/18/26.
//

import SwiftUI
struct RunDay: Identifiable {
    let id = UUID()
    let day: String
    let type: String
    let distance: Int
    let pace: String
}
struct PlanView: View {
    func planStructureFactor() -> (longRun: Double, workoutDays: Int, intensity: String) {

        switch planType {

        case .higdon:
            return (0.30, 1, "low")

        case .hansons:
            return (0.25, 2, "moderate")

        case .pfitz:
            return (0.28, 2, "high-volume")

        case .daniels:
            return (0.26, 3, "quality-heavy")
        }
    }
    func generateWeek(week: Int) -> [RunDay] {
        
        let totalMiles = weeklyMileage(week: week)
        
        let easy = easyPaceRange()
        let long = longRunPaceRange()
        
        var weekRuns: [RunDay] = []
        
        let runningDays = 7 - restDays.count
        
        // Long run = ~30% of weekly mileage
        let structure = planStructureFactor()
        
        let longRunMiles = Int(Double(totalMiles) * structure.longRun)
        
        // Remaining miles split across other run days
        let remainingMiles = totalMiles - longRunMiles
        let otherRunDays = runningDays - 1
        let perDayMiles = otherRunDays > 0 ? remainingMiles / otherRunDays : 0
        
        for day in Weekday.allCases {
            
            if restDays.contains(day) {
                
                weekRuns.append(RunDay(
                    day: day.displayName,
                    type: "Rest",
                    distance: 0,
                    pace: "-"
                ))
                
            } else if day == longRunDay {
                
                weekRuns.append(RunDay(
                    day: day.displayName,
                    type: "Long Run",
                    distance: longRunMiles,
                    pace: long
                ))
                
            } else if workoutDays.contains(day) {
                
                let intensity = planStructureFactor().intensity
                
                var workoutType = ""
                
                switch intensity {
                    
                case "low":
                    workoutType = "Light strides"
                    
                case "moderate":
                    workoutType = "Tempo (20–30 min)"
                    
                case "high-volume":
                    workoutType = "Threshold + steady"
                    
                case "quality-heavy":
                    workoutType = "Intervals (800–1200m repeats)"
                    
                default:
                    workoutType = "Workout"
                }
                
                weekRuns.append(RunDay(
                    day: day.displayName,
                    type: "Workout",
                    distance: perDayMiles,
                    pace: workoutType
                ))
                
            } else {
                
                weekRuns.append(RunDay(
                    day: day.displayName,
                    type: "Easy",
                    distance: perDayMiles,
                    pace: easy
                ))
            }
        }
        return weekRuns
    }
    var goalTime: String
    var weeks: Int
    var longRunDay: Weekday
    var workoutDays: Set<Weekday>
    var restDays: Set<Weekday>
    var planType: PlanType
    var baseMileage: Double

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {

                ForEach(1...weeks, id: \.self) { week in

                    VStack(alignment: .leading, spacing: 12) {

                        // WEEK HEADER CARD
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Week \(week)")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Training Plan Breakdown")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                        // RUNS
                        VStack(spacing: 10) {
                            let runs = generateWeek(week: week)

                            ForEach(runs) { run in
                                RunRowView(run: run)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top)
        }
        .navigationTitle("Your Plan")
    }

    func calculateEasyPace() -> String {
        return "9:00 - 10:00 / mile"
    }
    func formatPace(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d / mile", minutes, remainingSeconds)
    }
    func marathonPaceSeconds() -> Int? {
        let components = goalTime.split(separator: ":")

        if components.count != 2 { return nil }

        let hours = Int(components[0]) ?? 0
        let minutes = Int(components[1]) ?? 0

        let totalSeconds = (hours * 3600) + (minutes * 60)
        let pace = totalSeconds / Int(26.2)

        return pace
    }
    func easyPaceRange() -> String {
        guard let mp = marathonPaceSeconds() else { return "N/A" }

        let low = mp + 60
        let high = mp + 90

        return "\(formatPace(seconds: low)) - \(formatPace(seconds: high))"
    }

    func longRunPaceRange() -> String {
        guard let mp = marathonPaceSeconds() else { return "N/A" }

        let low = mp + 30
        let high = mp + 60

        return "\(formatPace(seconds: low)) - \(formatPace(seconds: high))"
    }

    func marathonPaceString() -> String {
        guard let mp = marathonPaceSeconds() else { return "N/A" }
        return formatPace(seconds: mp)
    }
    func weeklyMileage(week: Int) -> Int {

        let base: Double = 25   // starting mileage (we'll make this user input later)
        let peak: Double = 50   // peak mileage

        let buildWeeks = weeks - 2 // reserve last 2 weeks for taper

        // Linear growth toward peak
        let progress = Double(week) / Double(buildWeeks)
        var mileage = base + (peak - base) * progress

        // Cutback every 4th week
        if week % 4 == 0 {
            mileage *= 0.75
        }

        // Taper
        if week == weeks - 1 {
            mileage *= 0.7
        }
        if week == weeks {
            mileage *= 0.5
        }

        return Int(mileage)
    }
    struct RunRowView: View {
        let run: RunDay

        var body: some View {
            HStack {

                VStack(alignment: .leading, spacing: 4) {
                    Text(run.day)
                        .font(.headline)

                    Text(run.type)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if run.distance > 0 {
                        Text("\(run.distance) mi")
                            .fontWeight(.semibold)

                        Text(run.pace)
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        Text("REST")
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }
}
