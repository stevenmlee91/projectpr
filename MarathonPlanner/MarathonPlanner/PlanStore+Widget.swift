import WidgetKit

// MARK: - PlanStore Widget Sync
// Called after any mutation that changes what the widget should display.
// Builds a lightweight snapshot from the active plan and writes it to the
// shared App Group so the widget extension can read it without touching SavedPlan.

extension PlanStore {

    func syncWidget() {
        if let plan = primaryPlan {
            WidgetSnapshotBuilder.build(from: plan).write()
        } else {
            WidgetPlanSnapshot.clear()
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
