//
//  FitnessEngine.swift
//  ProjectPR
//
//  Created by Steven Lee on 4/17/26.
//

import Foundation

class FitnessEngine {

    static func calculate(runs: [Run]) -> FitnessSummary {

        let totalMiles = runs.reduce(0) { $0 + $1.distance }
        let avgPace = runs.map { $0.pace }.reduce(0, +) / Double(runs.count)
        let longestRun = runs.map { $0.distance }.max() ?? 0

        let baseMiles = (totalMiles / 30.0) * 7.0

        return FitnessSummary(
            baseMiles: baseMiles,
            avgPace: avgPace,
            longestRun: longestRun
        )
    }
}
