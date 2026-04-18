//
//  MockData.swift
//  ProjectPR
//
//  Created by Steven Lee on 4/17/26.
//

import Foundation

class MockDataService {

    static func getRuns() -> [Run] {
        return [
            Run(distance: 5, pace: 9.0, date: Date()),
            Run(distance: 6, pace: 8.8, date: Date()),
            Run(distance: 10, pace: 9.2, date: Date()),
            Run(distance: 4, pace: 8.5, date: Date()),
            Run(distance: 8, pace: 9.1, date: Date())
        ]
    }
}
