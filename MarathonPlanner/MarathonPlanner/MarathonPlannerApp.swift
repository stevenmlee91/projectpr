//
//  MarathonPlannerApp.swift
//  MarathonPlanner
//
//  Created by Steven Lee on 4/21/26.
//

import SwiftUI

@main
struct MarathonTrainerApp: App {
    @StateObject private var store = PlanStore()

    var body: some Scene {
        WindowGroup {
            PlanListView()
                .environmentObject(store)
        }
    }
}
