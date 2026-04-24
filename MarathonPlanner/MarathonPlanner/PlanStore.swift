import Foundation

// MARK: - Saved Plan Model
// Wraps a generated plan with a name, race date, and real calendar dates.

struct SavedPlan: Identifiable, Codable {
    let id        : UUID
    var name      : String
    var raceDate  : Date
    var startDate : Date
    var planType  : String          // stored as raw string for Codable
    var weeks     : [SavedWeek]

    init(id: UUID = UUID(), name: String, raceDate: Date, startDate: Date, planType: String, weeks: [SavedWeek]) {
        self.id        = id
        self.name      = name
        self.raceDate  = raceDate
        self.startDate = startDate
        self.planType  = planType
        self.weeks     = weeks
    }
}

struct SavedWeek: Identifiable, Codable {
    let id         : UUID
    let weekNumber : Int
    let phase      : String
    var days       : [SavedDay]

    var totalMiles: Double {
        days.reduce(0) { $0 + $1.miles }
    }

    init(id: UUID = UUID(), weekNumber: Int, phase: String, days: [SavedDay]) {
        self.id         = id
        self.weekNumber = weekNumber
        self.phase      = phase
        self.days       = days
    }
}

struct SavedDay: Identifiable, Codable {
    let id          : UUID
    let date        : Date          // Real calendar date
    let weekday     : String        // "Monday", "Tuesday", etc.
    let workoutType : String        // WorkoutType.rawValue
    let miles       : Double
    let description : String
    let paceNote    : String

    init(id: UUID = UUID(), date: Date, weekday: String, workoutType: String,
         miles: Double, description: String, paceNote: String) {
        self.id          = id
        self.date        = date
        self.weekday     = weekday
        self.workoutType = workoutType
        self.miles       = miles
        self.description = description
        self.paceNote    = paceNote
    }
}

// MARK: - Plan Creation with Race Date

func createSavedPlan(
    name        : String,
    raceDate    : Date,
    settings    : UserSettings
) -> SavedPlan {
    let cal = Calendar.current

    // Start date = race date minus plan length in weeks
    let weeksBack = settings.planLength.rawValue
    guard let startDate = cal.date(byAdding: .weekOfYear, value: -weeksBack, to: raceDate) else {
        fatalError("Could not calculate start date")
    }

    // Generate the training weeks using existing generator
    let trainingWeeks = PlanGenerator.generate(settings: settings)

    // Map each TrainingWeek + TrainingDay to SavedWeek + SavedDay with real dates
    let savedWeeks: [SavedWeek] = trainingWeeks.map { week in
        let savedDays: [SavedDay] = week.days.map { day in

            // Find the real calendar date for this weekday in this week
            let weekOffset  = week.weekNumber - 1
            let dayOffset   = day.weekday.rawValue  // 0 = Monday
            let totalOffset = weekOffset * 7 + dayOffset

            let realDate = cal.date(byAdding: .day, value: totalOffset, to: startDate) ?? startDate

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

    return SavedPlan(
        name:      name,
        raceDate:  raceDate,
        startDate: startDate,
        planType:  settings.planType.rawValue,
        weeks:     savedWeeks
    )
}

// MARK: - Plan Store (UserDefaults persistence)

class PlanStore: ObservableObject {
    @Published var plans: [SavedPlan] = []

    private let key = "saved_training_plans"

    init() {
        loadPlans()
    }

    func savePlan(_ plan: SavedPlan) {
        // Remove existing plan with same id if updating
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

    private func persist() {
        if let data = try? JSONEncoder().encode(plans) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadPlans() {
        guard let data  = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode([SavedPlan].self, from: data) else { return }
        plans = saved
    }
}
