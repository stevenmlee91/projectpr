import Foundation

// MARK: - Plan Type

enum PlanType: String, CaseIterable, Identifiable, Codable {
    case pfitz              = "Pfitz"
    case hansons            = "Hansons"
    case higdon             = "Higdon Novice"
    case higdonIntermediate = "Higdon Intermediate"
    case jackDaniels        = "Jack Daniels"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .pfitz:
            return "High mileage with medium-long mid-week runs. Two hard days. Builds a massive aerobic engine."
        case .hansons:
            return "Cumulative fatigue model. You always train tired. Long run capped at 16 mi. Race day feels easy."
        case .higdon:
            return "Gentle build-up. Mostly easy running. Long run is the main event. Best for first-timers."
        case .higdonIntermediate:
            return "Adds cross-training and a midweek longer run. For runners with 1–2 marathons completed."
        case .jackDaniels:
            return "VDOT-based precision. Two structured quality days. Every pace is mathematically derived."
        }
    }

    var requiresTwoWorkoutDays: Bool {
        switch self {
        case .hansons, .pfitz, .jackDaniels: return true
        case .higdon:                         return false
        case .higdonIntermediate:             return true
        }
    }

    var usesMidweekLongRun: Bool {
        switch self {
        case .higdon, .higdonIntermediate, .pfitz: return true
        default:                                   return false
        }
    }

    var usesCrossTraining: Bool { self == .higdonIntermediate }

    var minimumRestDays: Int {
        switch self {
        case .higdon: return 2
        default:      return 1
        }
    }

    var allowsZeroRestDays: Bool {
        switch self {
        case .hansons, .pfitz: return true
        default:               return false
        }
    }
}

// MARK: - Plan Length

enum PlanLength: Int, CaseIterable, Identifiable, Codable {
    case twelveWeek   = 12
    case sixteenWeek  = 16
    case eighteenWeek = 18

    var id: Int { rawValue }
    var label: String { "\(rawValue) Weeks" }
}

// MARK: - Weekday
//
// Raw values match Calendar.component(.weekday):
//   Sunday=1, Monday=2, Tuesday=3, Wednesday=4,
//   Thursday=5, Friday=6, Saturday=7
//
// When converting to a day offset from the plan start date,
// ALWAYS use (rawValue - 1) to get 0-based offsets:
//   Sunday=0, Monday=1, Tuesday=2, Wednesday=3,
//   Thursday=4, Friday=5, Saturday=6

enum Weekday: Int, CaseIterable, Identifiable, Codable, Hashable {
    case sunday    = 1
    case monday    = 2
    case tuesday   = 3
    case wednesday = 4
    case thursday  = 5
    case friday    = 6
    case saturday  = 7

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .sunday:    return "Sun"
        case .monday:    return "Mon"
        case .tuesday:   return "Tue"
        case .wednesday: return "Wed"
        case .thursday:  return "Thu"
        case .friday:    return "Fri"
        case .saturday:  return "Sat"
        }
    }

    var fullName: String {
        switch self {
        case .sunday:    return "Sunday"
        case .monday:    return "Monday"
        case .tuesday:   return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday:  return "Thursday"
        case .friday:    return "Friday"
        case .saturday:  return "Saturday"
        }
    }

    // 0-based offset for calendar arithmetic.
    // Use this instead of rawValue when calculating dates.
    var calendarOffset: Int { rawValue - 1 }

    var next: Weekday {
        Weekday(rawValue: (rawValue % 7) + 1) ?? .sunday
    }
}

// MARK: - Workout Type

enum WorkoutType: String, Codable {
    case rest             = "Rest"
    case easy             = "Easy Run"
    case recovery         = "Recovery Run"
    case generalAerobic   = "General Aerobic"
    case mediumLong       = "Medium-Long Run"
    case midweekLong      = "Midweek Longer Run"
    case longRun          = "Long Run"
    case longRunWithMP    = "Long Run w/ MP Finish"
    case lactateThreshold = "Lactate Threshold"
    case cruiseIntervals  = "Cruise Intervals"
    case strengthMP       = "Strength (MP)"
    case speedWork        = "Speed Work"
    case intervalWork     = "Interval Work"
    case repetitionWork   = "Repetition Work"
    case marathonPace     = "Marathon Pace"
    case tempoRun         = "Tempo Run"
    case strides          = "Easy + Strides"
    case crossTrain       = "Cross-Training"

    var effortLevel: Int {
        switch self {
        case .rest:                                             return 0
        case .recovery:                                         return 1
        case .easy, .strides, .crossTrain:                    return 2
        case .generalAerobic, .mediumLong, .midweekLong:      return 3
        case .longRun, .marathonPace, .tempoRun, .strengthMP: return 4
        case .lactateThreshold, .cruiseIntervals, .speedWork,
             .intervalWork, .repetitionWork, .longRunWithMP:   return 5
        }
    }

    var colorName: String {
        switch effortLevel {
        case 0:  return "gray"
        case 1:  return "mint"
        case 2:  return "green"
        case 3:  return "teal"
        case 4:  return "orange"
        case 5:  return "red"
        default: return "gray"
        }
    }
}

// MARK: - Training Day

struct TrainingDay: Identifiable, Codable {
    let id          : UUID
    let weekday     : Weekday
    let workoutType : WorkoutType
    let miles       : Double
    let description : String
    let paceNote    : String

    init(id: UUID = UUID(), weekday: Weekday, workoutType: WorkoutType,
         miles: Double, description: String, paceNote: String) {
        self.id = id; self.weekday = weekday; self.workoutType = workoutType
        self.miles = miles; self.description = description; self.paceNote = paceNote
    }
}

// MARK: - Training Week

struct TrainingWeek: Identifiable, Codable {
    let id         : UUID
    let weekNumber : Int
    let phase      : String
    let days       : [TrainingDay]

    init(id: UUID = UUID(), weekNumber: Int, phase: String, days: [TrainingDay]) {
        self.id = id; self.weekNumber = weekNumber
        self.phase = phase; self.days = days
    }

    var totalMiles: Double { days.reduce(0) { $0 + $1.miles } }
    var label: String { "Week \(weekNumber)" }
}

// MARK: - User Schedule
//
// THE RULE: This struct stores exactly what the user chose.
// validated() is a conflict resolver only — it does NOT reset
// or replace days the user explicitly selected unless there is
// a direct collision with a higher-priority assignment.
//
// Rest days in particular are preserved as-is unless they
// directly conflict with the longRunDay.

struct UserSchedule: Codable, Equatable {
    var longRunDay     : Weekday
    var workoutDay1    : Weekday
    var workoutDay2    : Weekday
    var restDays       : [Weekday]
    var crossTrainDay  : Weekday?
    var midweekLongDay : Weekday

    static func defaultFor(_ planType: PlanType) -> UserSchedule {
        switch planType {
        case .higdon:
            return UserSchedule(longRunDay: .sunday,  workoutDay1: .tuesday,
                                workoutDay2: .thursday, restDays: [.monday, .friday],
                                crossTrainDay: nil, midweekLongDay: .wednesday)
        case .higdonIntermediate:
            return UserSchedule(longRunDay: .sunday,  workoutDay1: .tuesday,
                                workoutDay2: .thursday, restDays: [.monday],
                                crossTrainDay: .saturday, midweekLongDay: .wednesday)
        case .hansons:
            return UserSchedule(longRunDay: .sunday,  workoutDay1: .tuesday,
                                workoutDay2: .thursday, restDays: [.monday],
                                crossTrainDay: nil, midweekLongDay: .wednesday)
        case .pfitz:
            return UserSchedule(longRunDay: .saturday, workoutDay1: .tuesday,
                                workoutDay2: .thursday, restDays: [.friday],
                                crossTrainDay: nil, midweekLongDay: .wednesday)
        case .jackDaniels:
            return UserSchedule(longRunDay: .sunday,  workoutDay1: .tuesday,
                                workoutDay2: .thursday, restDays: [.friday],
                                crossTrainDay: nil, midweekLongDay: .wednesday)
        }
    }

    // MARK: Validation
    //
    // Called ONLY inside PlanGenerator.generate() — never during UI interaction.
    //
    // What it does:
    //   - Resolves hard collisions between specific role assignments
    //   - Removes rest days that directly conflict with running roles
    //   - Does NOT add rest days the user didn't select
    //   - Does NOT enforce minimums that override user intent
    //   - Does NOT shift rest days to other weekdays
    //
    // Priority order for conflict resolution:
    //   1. longRunDay (never moved)
    //   2. workoutDay1
    //   3. workoutDay2 (only if plan requires two workout days)
    //   4. midweekLongDay (only if plan uses midweek long run)
    //   5. crossTrainDay (only if plan uses cross-training)
    //   6. restDays — remove only those that conflict with 1–5

    func validated(for planType: PlanType) -> UserSchedule {
        var s     = self
        var taken = Set<Weekday>()

        // 1. Long run day — highest priority, never moved
        taken.insert(s.longRunDay)

        // 2. Primary workout day
        if taken.contains(s.workoutDay1) {
            s.workoutDay1 = firstFree(taken)
        }
        taken.insert(s.workoutDay1)

        // 3. Secondary workout day (only relevant plans)
        if planType.requiresTwoWorkoutDays {
            if taken.contains(s.workoutDay2) {
                s.workoutDay2 = firstFree(taken)
            }
            taken.insert(s.workoutDay2)
        }

        // 4. Midweek long run day (only relevant plans)
        if planType.usesMidweekLongRun {
            if taken.contains(s.midweekLongDay) {
                s.midweekLongDay = firstFree(taken)
            }
            taken.insert(s.midweekLongDay)
        }

        // 5. Cross-train day (only relevant plans)
        if planType.usesCrossTraining {
            if let ct = s.crossTrainDay {
                if taken.contains(ct) {
                    s.crossTrainDay = firstFreeOptional(taken)
                }
                if let finalCT = s.crossTrainDay { taken.insert(finalCT) }
            }
        } else {
            s.crossTrainDay = nil
        }

        // 6. Rest days — ONLY remove those that conflict with running days.
        //    Do NOT add new rest days. Do NOT shift rest days.
        //    The user's rest day choices are preserved unless they
        //    directly overlap with a higher-priority running day.
        s.restDays = s.restDays.filter { !taken.contains($0) }

        // Remove duplicate rest days (shouldn't happen but defensive)
        s.restDays = Array(Set(s.restDays))

        return s
    }

    private func firstFree(_ taken: Set<Weekday>) -> Weekday {
        Weekday.allCases.first { !taken.contains($0) } ?? .monday
    }

    private func firstFreeOptional(_ taken: Set<Weekday>) -> Weekday? {
        Weekday.allCases.first { !taken.contains($0) }
    }
}

// MARK: - User Settings

struct UserSettings: Codable {
    var goalTimeMinutes : Int          = 210
    var baseMileage     : Double       = 25
    var planType        : PlanType     = .higdon
    var planLength      : PlanLength   = .sixteenWeek
    var schedule        : UserSchedule = UserSchedule.defaultFor(.higdon)

    var goalTimeFormatted: String {
        let h = goalTimeMinutes / 60
        let m = goalTimeMinutes % 60
        return String(format: "%d:%02d:00", h, m)
    }

    mutating func resetScheduleForNewPlanType() {
        schedule = UserSchedule.defaultFor(planType)
    }
}

// MARK: - Pace Engine

struct PaceEngine {
    let goalMinutes: Int
    var MP: Int { (goalMinutes * 60) / 26 }

    var easy            : (low: Int, high: Int) { (MP + 90,  MP + 120) }
    var longRun         : (low: Int, high: Int) { (MP + 60,  MP + 90)  }
    var generalAero     : (low: Int, high: Int) { (MP + 45,  MP + 75)  }
    var recovery        : Int                   { MP + 150 }
    var pfitzLT         : Int                   { MP - 20  }
    var hansonsStrength : (low: Int, high: Int) { (MP - 5,  MP + 5)    }
    var hansonsSpeed    : Int                   { MP - 55  }
    var dThreshold      : Int                   { MP - 28  }
    var dInterval       : Int                   { MP - 55  }
    var dRepetition     : Int                   { MP - 80  }
    var higdonTempo     : Int                   { MP - 15  }

    static func format(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
    func rangeString(_ r: (low: Int, high: Int)) -> String {
        "\(PaceEngine.format(r.high))–\(PaceEngine.format(r.low))/mi"
    }
    func singleString(_ s: Int) -> String { "\(PaceEngine.format(s))/mi" }
}

// MARK: - Training Paces

struct TrainingPaces {
    let easy     : (min: Int, max: Int)
    let longRun  : (min: Int, max: Int)
    let marathon : Int
    let tempo    : Int
    let interval : Int
    let recovery : Int

    static func calculate(goalMinutes: Int) -> TrainingPaces {
        let e = PaceEngine(goalMinutes: goalMinutes)
        return TrainingPaces(
            easy:     (e.easy.high, e.easy.low),
            longRun:  (e.longRun.high, e.longRun.low),
            marathon: e.MP, tempo: e.pfitzLT,
            interval: e.dInterval, recovery: e.recovery)
    }
    static func format(_ s: Int) -> String { PaceEngine.format(s) }
}

// MARK: - Peak Targets

struct PeakTargets {
    let peakLongRun     : Double
    let peakWeeklyMiles : Double
    let peakWeekNumber  : Int
    let taperWeeks      : Int
}

func calculatePeakTargets(method: PlanType, planLength: Int) -> PeakTargets {
    let pw = planLength - 4
    switch method {
    case .hansons:
        return PeakTargets(peakLongRun: 16, peakWeeklyMiles: 55,
                           peakWeekNumber: pw, taperWeeks: 2)
    case .pfitz:
        return PeakTargets(peakLongRun: 22, peakWeeklyMiles: 70,
                           peakWeekNumber: pw, taperWeeks: 3)
    case .higdon:
        return PeakTargets(peakLongRun: 20, peakWeeklyMiles: 40,
                           peakWeekNumber: pw, taperWeeks: 2)
    case .higdonIntermediate:
        return PeakTargets(peakLongRun: 22, peakWeeklyMiles: 48,
                           peakWeekNumber: pw, taperWeeks: 2)
    case .jackDaniels:
        return PeakTargets(peakLongRun: 18, peakWeeklyMiles: 60,
                           peakWeekNumber: pw, taperWeeks: 2)
    }
}

// MARK: - Method Constraints

enum ProgressionStyle { case cumulativeFatigue, periodicCutback, phasedQuality }

struct MethodConstraints {
    let maxLongRunMiles      : Double
    let minLongRunMiles      : Double
    let longRunAsPercentage  : Double
    let minRunDays           : Int
    let maxRunDays           : Int
    let requiredWorkouts     : [WorkoutType]
    let progressionStyle     : ProgressionStyle
    let requiresMediumLong   : Bool
    let earliestQualityWeek  : Int
    let allowsConsecutiveHard: Bool
    let absoluteMinWeekly    : Double
    let absoluteMaxWeekly    : Double
}

func getMethodConstraints(for planType: PlanType) -> MethodConstraints {
    switch planType {
    case .hansons:
        return MethodConstraints(maxLongRunMiles: 16, minLongRunMiles: 8,
            longRunAsPercentage: 0.30, minRunDays: 5, maxRunDays: 6,
            requiredWorkouts: [.speedWork, .strengthMP, .longRun],
            progressionStyle: .cumulativeFatigue, requiresMediumLong: false,
            earliestQualityWeek: 1, allowsConsecutiveHard: false,
            absoluteMinWeekly: 25, absoluteMaxWeekly: 65)
    case .pfitz:
        return MethodConstraints(maxLongRunMiles: 23, minLongRunMiles: 12,
            longRunAsPercentage: 0.35, minRunDays: 5, maxRunDays: 6,
            requiredWorkouts: [.lactateThreshold, .mediumLong, .longRun],
            progressionStyle: .periodicCutback, requiresMediumLong: true,
            earliestQualityWeek: 1, allowsConsecutiveHard: false,
            absoluteMinWeekly: 35, absoluteMaxWeekly: 85)
    case .higdon:
        return MethodConstraints(maxLongRunMiles: 20, minLongRunMiles: 6,
            longRunAsPercentage: 0.40, minRunDays: 4, maxRunDays: 5,
            requiredWorkouts: [.longRun, .midweekLong],
            progressionStyle: .periodicCutback, requiresMediumLong: false,
            earliestQualityWeek: 99, allowsConsecutiveHard: false,
            absoluteMinWeekly: 15, absoluteMaxWeekly: 45)
    case .higdonIntermediate:
        return MethodConstraints(maxLongRunMiles: 22, minLongRunMiles: 8,
            longRunAsPercentage: 0.40, minRunDays: 4, maxRunDays: 6,
            requiredWorkouts: [.tempoRun, .longRun, .midweekLong, .crossTrain],
            progressionStyle: .periodicCutback, requiresMediumLong: false,
            earliestQualityWeek: 3, allowsConsecutiveHard: false,
            absoluteMinWeekly: 20, absoluteMaxWeekly: 55)
    case .jackDaniels:
        return MethodConstraints(maxLongRunMiles: 22, minLongRunMiles: 8,
            longRunAsPercentage: 0.25, minRunDays: 4, maxRunDays: 6,
            requiredWorkouts: [.repetitionWork, .cruiseIntervals, .intervalWork],
            progressionStyle: .phasedQuality, requiresMediumLong: false,
            earliestQualityWeek: 1, allowsConsecutiveHard: false,
            absoluteMinWeekly: 25, absoluteMaxWeekly: 75)
    }
}
