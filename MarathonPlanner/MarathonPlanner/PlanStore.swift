import Foundation

// MARK: - Saved Plan Models

struct SavedPlan: Identifiable, Codable {
    let id        : UUID
    var name      : String
    var raceDate  : Date
    var startDate : Date
    var planType  : String
    var weeks     : [SavedWeek]
    var settings  : UserSettings

    init(id: UUID = UUID(), name: String, raceDate: Date,
         startDate: Date, planType: String,
         weeks: [SavedWeek], settings: UserSettings) {
        self.id        = id
        self.name      = name
        self.raceDate  = raceDate
        self.startDate = startDate
        self.planType  = planType
        self.weeks     = weeks
        self.settings  = settings
    }
}

struct SavedWeek: Identifiable, Codable {
    let id         : UUID
    let weekNumber : Int
    let phase      : String
    var days       : [SavedDay]

    init(id: UUID = UUID(), weekNumber: Int, phase: String, days: [SavedDay]) {
        self.id         = id
        self.weekNumber = weekNumber
        self.phase      = phase
        self.days       = days
    }

    var totalMiles: Double { days.reduce(0) { $0 + $1.miles } }
}

struct SavedDay: Identifiable, Codable {
    let id          : UUID
    let date        : Date
    let weekday     : String
    let workoutType : String
    let miles       : Double
    let description : String
    let paceNote    : String

    init(id: UUID = UUID(), date: Date, weekday: String,
         workoutType: String, miles: Double,
         description: String, paceNote: String) {
        self.id          = id
        self.date        = date
        self.weekday     = weekday
        self.workoutType = workoutType
        self.miles       = miles
        self.description = description
        self.paceNote    = paceNote
    }
}

// MARK: - Plan Creation

func createSavedPlan(
    name     : String,
    raceDate : Date,
    settings : UserSettings
) -> SavedPlan {
    let cal       = Calendar.current
    let weeksBack = settings.planLength.rawValue

    guard let startDate = cal.date(
        byAdding: .weekOfYear, value: -weeksBack, to: raceDate
    ) else { fatalError("Could not calculate plan start date") }

    let trainingWeeks = PlanGenerator.generate(settings: settings)
    let savedWeeks    = buildSavedWeeks(
        from: trainingWeeks, startDate: startDate, cal: cal
    )

    return SavedPlan(
        name:      name,
        raceDate:  raceDate,
        startDate: startDate,
        planType:  settings.planType.rawValue,
        weeks:     savedWeeks,
        settings:  settings
    )
}

// Shared helper used by both create and edit paths
func buildSavedWeeks(
    from trainingWeeks : [TrainingWeek],
    startDate          : Date,
    cal                : Calendar
) -> [SavedWeek] {
    trainingWeeks.map { week in
        let savedDays: [SavedDay] = week.days.map { day in
            let weekOffset  = week.weekNumber - 1
            let dayOffset   = day.weekday.calendarOffset   // rawValue - 1, 0-based
            let totalOffset = weekOffset * 7 + dayOffset
            let realDate    = cal.date(
                byAdding: .day, value: totalOffset, to: startDate
            ) ?? startDate

            return SavedDay(
                date:        realDate,
                weekday:     day.weekday.fullName,
                workoutType: day.workoutType.rawValue,
                miles:       day.miles,
                description: day.description,
                paceNote:    day.paceNote
            )
        }
        return SavedWeek(
            weekNumber: week.weekNumber,
            phase:      week.phase,
            days:       savedDays
        )
    }
}

// MARK: - Plan Store

class PlanStore: ObservableObject {
    @Published var plans: [SavedPlan] = []
    private let key = "saved_training_plans"

    init() { loadPlans() }

    func savePlan(_ plan: SavedPlan) {
        plans.removeAll { $0.id == plan.id }
        plans.append(plan)
        persist()
    }

    func deletePlan(_ plan: SavedPlan) {
        plans.removeAll { $0.id == plan.id }
        persist()
    }

    func deletePlans(at offsets: IndexSet) {
        plans.remove(atOffsets: offsets)
        persist()
    }

    // MARK: - Edit: Schedule-only reflow
    // Preserves mileage progression — just moves workouts
    // onto newly selected weekdays. Fast, no recalculation.

    func reflowSchedule(
        _ plan        : SavedPlan,
        newSchedule   : UserSchedule
    ) -> SavedPlan {
        var newSettings          = plan.settings
        newSettings.schedule     = newSchedule

        let cal           = Calendar.current
        let trainingWeeks = PlanGenerator.generate(settings: newSettings)
        let savedWeeks    = buildSavedWeeks(
            from: trainingWeeks, startDate: plan.startDate, cal: cal
        )

        return SavedPlan(
            id:        plan.id,
            name:      plan.name,
            raceDate:  plan.raceDate,
            startDate: plan.startDate,
            planType:  newSettings.planType.rawValue,
            weeks:     savedWeeks,
            settings:  newSettings
        )
    }

    // MARK: - Edit: Full regeneration
    // Used when goal time, base mileage, plan type, or
    // plan length changes. Rebuilds everything from scratch.

    func regeneratePlan(
        _ plan       : SavedPlan,
        newSettings  : UserSettings
    ) -> SavedPlan {
        let cal           = Calendar.current
        let trainingWeeks = PlanGenerator.generate(settings: newSettings)
        let savedWeeks    = buildSavedWeeks(
            from: trainingWeeks, startDate: plan.startDate, cal: cal
        )

        return SavedPlan(
            id:        plan.id,
            name:      plan.name,
            raceDate:  plan.raceDate,
            startDate: plan.startDate,
            planType:  newSettings.planType.rawValue,
            weeks:     savedWeeks,
            settings:  newSettings
        )
    }

    // MARK: - Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(plans) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadPlans() {
        guard
            let data  = UserDefaults.standard.data(forKey: key),
            let saved = try? JSONDecoder().decode([SavedPlan].self, from: data)
        else { return }
        plans = saved
    }
}
