//
//  Models.swift
//  ProjectPR
//
//  Created by Steven Lee on 4/17/26.
//

import Foundation

struct Run {
    let distance: Double   // miles
    let pace: Double       // min per mile
    let date: Date
}

struct FitnessSummary {
    let baseMiles: Double
    let avgPace: Double
    let longestRun: Double
}
