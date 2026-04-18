//
//  ContentView.swift
//  ProjectPR
//
//  Created by Steven Lee on 4/17/26.
//

import SwiftUI

struct ContentView: View {
    
    @State private var summary: FitnessSummary?
    @State private var plan: [TrainingWeek] = []

    var body: some View {
        VStack(spacing: 20) {

            Text("Run Planner")
                .font(.largeTitle)
                .bold()

            Button("Generate Plan") {
                let runs = MockDataService.getRuns()
                let summary = FitnessEngine.calculate(runs: runs)

                plan = HansonsEngine.generatePlan(
                    fitness: summary,
                    goalTime: 210
                )
            }
            .padding()
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(12)

            if let summary = summary {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Base Miles: \(summary.baseMiles, specifier: "%.1f")")
                    Text("Avg Pace: \(summary.avgPace, specifier: "%.2f")")
                    Text("Longest Run: \(summary.longestRun, specifier: "%.1f")")
                }
                .padding()
            }
            ScrollView {
                ForEach(plan, id: \.weekNumber) { week in
                    VStack(alignment: .leading, spacing: 8) {

                        Text("Week \(week.weekNumber) - \(week.totalMiles, specifier: "%.1f") mi")
                            .bold()

                        ForEach(week.days, id: \.day) { day in
                            Text("\(day.day): \(day.type.rawValue) - \(day.distance, specifier: "%.1f") mi @ \(day.paceRange)")
                                .font(.caption)
                        }
                    }
                    .padding()
                }
            }
            Spacer()
        }
        .padding()
    }
}
