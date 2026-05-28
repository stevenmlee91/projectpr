import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct WidgetEntry: TimelineEntry {
    let date     : Date
    let snapshot : WidgetPlanSnapshot
}

// MARK: - Timeline Provider

struct MileZeroTimelineProvider: TimelineProvider {
    typealias Entry = WidgetEntry

    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (WidgetEntry) -> Void) {
        let snap = WidgetPlanSnapshot.read() ?? .empty
        completion(WidgetEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let snap  = WidgetPlanSnapshot.read() ?? .empty
        let entry = WidgetEntry(date: Date(), snapshot: snap)

        // Refresh at midnight — new day means a new workout
        let tomorrow = Calendar.current.date(
            byAdding: .day, value: 1, to: Date())!
        let midnight = Calendar.current.startOfDay(for: tomorrow)

        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}
