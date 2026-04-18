//
//  TrainingModels.swift
//  ProjectPR
//
//  Created by Steven Lee on 4/17/26.
//

import Foundation

enum RunType: String {
    case easy = "Easy"
    case tempo = "Tempo"
    case interval = "Intervals"
    case longRun = "Long Run"
    case recovery = "Recovery"
    case rest = "Rest"
}

struct TrainingDay {
    let day: String
    let distance: Double
    let type: RunType
    let paceRange: String
    let notes: String?
}

struct TrainingWeek {
    let weekNumber: Int
    let totalMiles: Double
    let days: [TrainingDay]
}
