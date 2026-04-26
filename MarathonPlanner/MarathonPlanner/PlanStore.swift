import Foundation

// MARK: - Completion Status

enum CompletionStatus: String, Codable, CaseIterable {
    case notStarted = "notStarted"
    case completed  = "completed"
    case skipped    = "skipped"
    case modified   = "modified"
}

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

    var totalMiles: Double {
        days.reduce(0) { $0 + $1.miles }
    }

    var actualMiles: Double {
        days.reduce(0) { $0 + ($1.actualMiles ?? 0) }
    }

    var completionPercentage: Double {
        let trackable = days.filter { $0.workoutType != "Rest" }
        guard !trackable.isEmpty else { return 1.0 }
        let done = trackable.filter {
            $0.completionStatus == .completed
            || $0.completionStatus == .modified
        }.count
        return Double(done) / Double(trackable.count)
    }

    var completedDayCount: Int {
        days.filter {
            $0.completionStatus == .completed
            || $0.completionStatus == .modified
        }.count
    }

    var trackableDayCount: Int {
        days.filter { $0.workoutType != "Rest" }.count
    }
}

struct SavedDay: Identifiable, Codable {
    let id               : UUID
    let date             : Date
    let weekday          : String
    let workoutType      : String
    let miles            : Double
    let description      : String
    let paceNote         : String
    var completionStatus : CompletionStatus
    var actualMiles      : Double?
    var completionNote   : String?

    init(id: UUID = UUID(), date: Date, weekday: String,
         workoutType: String, miles: Double, description: String,
         paceNote: String, completionStatus: CompletionStatus = .notStarted,
         actualMiles: Double? = nil, completionNote: String? = nil) {
        self.id               = id
        self.date             = date
        self.weekday          = weekday
        self.workoutType      = workoutType
        self.miles            = miles
        self.description      = description
        self.paceNote         = paceNote
        self.completionStatus = completionStatus
        self.actualMiles      = actualMiles
        self.completionNote   = completionNote
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var isPast: Bool {
        date < Calendar.current.startOfDay(for: Date())
    }
}

// MARK: - Plan Creation

func createSavedPlan(name: String, raceDate: Date,
                     settings: UserSettings) -> SavedPlan {
    let cal = Calendar.current
    guard let startDate = cal.date(
        byAdding: .weekOfYear,
        value: -settings.planLength.rawValue,
        to: raceDate
    ) else { fatalError("Could not calculate plan start date") }

    let trainingWeeks = PlanGenerator.generate(settings: settings)
    let savedWeeks    = buildSavedWeeks(from: trainingWeeks,
                                        startDate: startDate, cal: cal)
    return SavedPlan(name: name, raceDate: raceDate, startDate: startDate,
                     planType: settings.planType.rawValue,
                     weeks: savedWeeks, settings: settings)
}

func buildSavedWeeks(from trainingWeeks: [TrainingWeek],
                     startDate: Date, cal: Calendar) -> [SavedWeek] {
    trainingWeeks.map { week in
        let savedDays: [SavedDay] = week.days.map { day in
            let weekOffset  = week.weekNumber - 1
            let dayOffset   = day.weekday.calendarOffset
            let totalOffset = weekOffset * 7 + dayOffset
            let realDate    = cal.date(byAdding: .day,
                                       value: totalOffset,
                                       to: startDate) ?? startDate
            return SavedDay(date: realDate, weekday: day.weekday.fullName,
                            workoutType: day.workoutType.rawValue,
                            miles: day.miles, description: day.description,
                            paceNote: day.paceNote)
        }
        return SavedWeek(weekNumber: week.weekNumber,
                         phase: week.phase, days: savedDays)
    }
}

// MARK: - Plan Store

class PlanStore: ObservableObject {
    @Published var plans: [SavedPlan] = []
    private let key = "saved_training_plans_v2"

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

    // Look up a week by plan ID + week ID
    // Used by SPVWeekDetailView to get fresh data
    func week(planID: UUID, weekID: UUID) -> SavedWeek? {
        plans.first { $0.id == planID }?
             .weeks.first { $0.id == weekID }
    }

    func updateCompletion(planID: UUID, weekID: UUID, dayID: UUID,
                          status: CompletionStatus, actual: Double? = nil) {
        guard
            let pi = plans.firstIndex(where: { $0.id == planID }),
            let wi = plans[pi].weeks.firstIndex(where: { $0.id == weekID }),
            let di = plans[pi].weeks[wi].days.firstIndex(where: { $0.id == dayID })
        else {
            print("⚠️ updateCompletion: could not find day")
            return
        }

        plans[pi].weeks[wi].days[di].completionStatus = status
        if let actual = actual {
            plans[pi].weeks[wi].days[di].actualMiles = actual
        }
        if status == .notStarted {
            plans[pi].weeks[wi].days[di].actualMiles = nil
        }

        // Persist on background thread
        let snapshot = plans
        DispatchQueue.global(qos: .utility).async {
            if let data = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(data, forKey: "saved_training_plans_v2")
            }
        }
    }

    func reflowSchedule(_ plan: SavedPlan,
                        newSchedule: UserSchedule) -> SavedPlan {
        var newSettings      = plan.settings
        newSettings.schedule = newSchedule
        let cal              = Calendar.current
        let trainingWeeks    = PlanGenerator.generate(settings: newSettings)
        let saved            = buildSavedWeeks(from: trainingWeeks,
                                               startDate: plan.startDate,
                                               cal: cal)
        return SavedPlan(id: plan.id, name: plan.name,
                         raceDate: plan.raceDate, startDate: plan.startDate,
                         planType: newSettings.planType.rawValue,
                         weeks: saved, settings: newSettings)
    }

    func regeneratePlan(_ plan: SavedPlan,
                        newSettings: UserSettings) -> SavedPlan {
        let cal           = Calendar.current
        let trainingWeeks = PlanGenerator.generate(settings: newSettings)
        let saved         = buildSavedWeeks(from: trainingWeeks,
                                            startDate: plan.startDate,
                                            cal: cal)
        return SavedPlan(id: plan.id, name: plan.name,
                         raceDate: plan.raceDate, startDate: plan.startDate,
                         planType: newSettings.planType.rawValue,
                         weeks: saved, settings: newSettings)
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
    func saveNote(planID: UUID, weekID: UUID, dayID: UUID, note: String) {
        guard
            let pi = plans.firstIndex(where: { $0.id == planID }),
            let wi = plans[pi].weeks.firstIndex(where: { $0.id == weekID }),
            let di = plans[pi].weeks[wi].days.firstIndex(where: { $0.id == dayID })
        else { return }

        plans[pi].weeks[wi].days[di].completionNote = note.isEmpty ? nil : note

        let snapshot = plans
        DispatchQueue.global(qos: .utility).async {
            if let data = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(data, forKey: "saved_training_plans_v2")
            }
        }
    }
}

// MARK: - Conformances
// Only hash/compare by ID — never by contents.
// Comparing contents of large structs inside NavigationLink
// causes the freeze you were seeing.

extension SavedPlan: Equatable, Hashable {
    static func == (lhs: SavedPlan, rhs: SavedPlan) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension SavedWeek: Equatable, Hashable {
    static func == (lhs: SavedWeek, rhs: SavedWeek) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension SavedDay: Equatable, Hashable {
    static func == (lhs: SavedDay, rhs: SavedDay) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
