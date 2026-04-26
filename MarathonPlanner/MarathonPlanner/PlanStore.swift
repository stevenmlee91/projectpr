import Foundation

// MARK: - Saved Plan Models

struct SavedPlan: Identifiable, Codable {
    let id        : UUID
    var name      : String
    var raceDate  : Date
    var startDate : Date
    var planType  : String
    var weeks     : [SavedWeek]

    init(id: UUID = UUID(), name: String, raceDate: Date,
         startDate: Date, planType: String, weeks: [SavedWeek]) {
        self.id = id; self.name = name; self.raceDate = raceDate
        self.startDate = startDate; self.planType = planType; self.weeks = weeks
    }
}

struct SavedWeek: Identifiable, Codable {
    let id         : UUID
    let weekNumber : Int
    let phase      : String
    var days       : [SavedDay]

    init(id: UUID = UUID(), weekNumber: Int, phase: String, days: [SavedDay]) {
        self.id = id; self.weekNumber = weekNumber
        self.phase = phase; self.days = days
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
        self.id = id; self.date = date; self.weekday = weekday
        self.workoutType = workoutType; self.miles = miles
        self.description = description; self.paceNote = paceNote
    }
}

// MARK: - Plan Creation
//
// THE FIX IS HERE.
//
// Root cause of "Wednesday rest becomes Thursday":
//   Old code used day.weekday.rawValue as the day offset.
//   Weekday.sunday = 1, so rawValue is 1-based.
//   This shifted every day forward by one position.
//   Wednesday (rawValue=4) got offset 4 → landed on Thursday.
//
// Fix: subtract 1 from rawValue to get a 0-based offset.
//   Sunday=0, Monday=1, Tuesday=2, Wednesday=3, Thursday=4,
//   Friday=5, Saturday=6.
//   Wednesday (rawValue=4) now gets offset 3 → lands on Wednesday. ✓

func createSavedPlan(
    name     : String,
    raceDate : Date,
    settings : UserSettings
) -> SavedPlan {
    let cal = Calendar.current

    let weeksBack = settings.planLength.rawValue
    guard let startDate = cal.date(
        byAdding: .weekOfYear, value: -weeksBack, to: raceDate
    ) else {
        fatalError("Could not calculate plan start date")
    }

    // Generate the training weeks using the user's exact settings.
    // PlanGenerator.generate() calls validated() internally, which only
    // fixes hard conflicts — it does not replace user-chosen rest days.
    let trainingWeeks = PlanGenerator.generate(settings: settings)

    let savedWeeks: [SavedWeek] = trainingWeeks.map { week in
        let savedDays: [SavedDay] = week.days.map { day in

            let weekOffset = week.weekNumber - 1

            // CORRECTED: subtract 1 so Sunday=0, Monday=1 ... Saturday=6
            // This is the single line that was causing Wednesday→Thursday shift.
            let dayOffset  = day.weekday.rawValue - 1

            let totalOffset = weekOffset * 7 + dayOffset

            let realDate = cal.date(
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

    return SavedPlan(
        name:      name,
        raceDate:  raceDate,
        startDate: startDate,
        planType:  settings.planType.rawValue,
        weeks:     savedWeeks
    )
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
