import Foundation

// MARK: - Race Type

enum RaceType: String, Codable, CaseIterable {
    case marathon     = "Marathon"
    case halfMarathon = "Half Marathon"

    var distance: Double {
        switch self {
        case .marathon:     return 26.2
        case .halfMarathon: return 13.1
        }
    }

    var displayDistance: String {
        switch self {
        case .marathon:     return "26.2 mi"
        case .halfMarathon: return "13.1 mi"
        }
    }

    var icon: String {
        switch self {
        case .marathon:     return "figure.run"
        case .halfMarathon: return "figure.run.circle"
        }
    }
}

// MARK: - Taper Duration

enum TaperDuration: Int, Codable, CaseIterable, Identifiable {
    case twoWeeks   = 2
    case threeWeeks = 3

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .twoWeeks:   return "2 Weeks"
        case .threeWeeks: return "3 Weeks"
        }
    }

    var description: String {
        switch self {
        case .twoWeeks:
            return "Standard taper. More peak training time."
        case .threeWeeks:
            return "Classic taper. More recovery before race day."
        }
    }

    static func defaultFor(_ planType: PlanType) -> TaperDuration {
        switch planType {
        case .pfitz: return .threeWeeks
        default:     return .twoWeeks
        }
    }

    static func options(for planType: PlanType) -> [TaperDuration] {
        [.twoWeeks, .threeWeeks]
    }
}

// MARK: - Plan Type

enum PlanType: String, CaseIterable, Identifiable, Codable {

    case pfitz              = "Pfitz"
    case hansons            = "Hansons"
    case higdon             = "Higdon Novice"
    case higdonIntermediate = "Higdon Intermediate"

    case higdonHalfNovice       = "Higdon Half Novice"
    case higdonHalfIntermediate = "Higdon Half Intermediate"
    case hansonsHalf            = "Hansons Half"
    case firstHalf              = "First Half Marathon"

    var id: String { rawValue }

    var raceType: RaceType {
        switch self {
        case .higdonHalfNovice, .higdonHalfIntermediate,
             .hansonsHalf, .firstHalf:
            return .halfMarathon
        default:
            return .marathon
        }
    }

    var isHalfMarathon: Bool { raceType == .halfMarathon }

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
        case .higdonHalfNovice:
            return "Three days of running per week. Long run builds to 10 miles. Perfect for your first half marathon."
        case .higdonHalfIntermediate:
            return "Four to five days running with a midweek tempo. Long run to 12 miles. For runners with race experience."
        case .hansonsHalf:
            return "Six days running with cumulative fatigue. Speed and strength workouts. Race day will feel controlled."
        case .firstHalf:
            return "Built for first-time half marathoners. Conservative progression, four days of running, and confidence-building long runs. Finish strong."
        }
    }

    var requiresTwoWorkoutDays: Bool {
        switch self {
        case .hansons, .pfitz,
             .higdonIntermediate, .hansonsHalf,
             .higdonHalfIntermediate:
            return true
        case .higdon, .higdonHalfNovice, .firstHalf:
            return false
        }
    }

    var usesMidweekLongRun: Bool {
        switch self {
        case .higdon, .higdonIntermediate,
             .pfitz, .higdonHalfIntermediate:
            return true
        default:
            return false
        }
    }

    var usesCrossTraining: Bool {
        self == .higdonIntermediate || self == .higdonHalfIntermediate
    }

    var minimumRestDays: Int {
        switch self {
        case .higdon, .higdonHalfNovice, .firstHalf: return 2
        default:                                      return 1
        }
    }

    var allowsZeroRestDays: Bool {
        switch self {
        case .hansons, .pfitz, .hansonsHalf: return true
        default:                             return false
        }
    }

    /// Methodology-canonical taper length. Not user-configurable.
    /// Each methodology has a physiologically correct taper built into its design.
    var canonicalTaperWeeks: Int {
        switch self {
        case .hansons:               return 2  // cumulative fatigue preserved longer
        case .pfitz:                 return 3  // high peak mileage needs more clearance
        case .higdon:                return 3  // book standard, connective tissue recovery
        case .higdonIntermediate:    return 3  // book standard
        case .higdonHalfNovice:      return 2  // half marathon needs less recovery time
        case .higdonHalfIntermediate:return 2
        case .hansonsHalf:           return 2
        case .firstHalf:             return 2
        }
    }

    static func options(for raceType: RaceType) -> [PlanType] {
        switch raceType {
        case .halfMarathon:
            return [.firstHalf, .higdonHalfNovice,
                    .higdonHalfIntermediate, .hansonsHalf]
        case .marathon:
            return [.higdon, .higdonIntermediate,
                    .hansons, .pfitz]
        }
    }
}

// MARK: - Plan Length

enum PlanLength: Int, CaseIterable, Identifiable, Codable {
    case eightWeek    = 8
    case tenWeek      = 10
    case twelveWeek   = 12
    case sixteenWeek  = 16
    case eighteenWeek = 18

    var id: Int    { rawValue }
    var label: String { "\(rawValue) Weeks" }

    static func options(for raceType: RaceType) -> [PlanLength] {
        switch raceType {
        case .halfMarathon: return [.tenWeek,
                                    .twelveWeek, .sixteenWeek]
        case .marathon:     return [.twelveWeek, .sixteenWeek,
                                    .eighteenWeek]
        }
    }
}

// MARK: - Weekday

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

    var calendarOffset: Int { rawValue - 1 }

    var next: Weekday {
        Weekday(rawValue: (rawValue % 7) + 1) ?? .sunday
    }

    static var displayOrder: [Weekday] {
        [.monday, .tuesday, .wednesday,
         .thursday, .friday, .saturday, .sunday]
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
    case raceDay          = "Race Day 🏁"
    case shakeout         = "Shakeout Run"
    case steadyRun        = "Steady Run"

    var effortLevel: Int {
        switch self {
        case .rest:                                             return 0
        case .recovery:                                         return 1
        case .easy, .strides, .crossTrain, .shakeout:         return 2
        case .generalAerobic, .mediumLong, .midweekLong,
             .steadyRun:                                        return 3
        case .longRun, .marathonPace, .tempoRun, .strengthMP: return 4
        case .lactateThreshold, .cruiseIntervals, .speedWork,
             .intervalWork, .repetitionWork, .longRunWithMP:   return 5
        case .raceDay:                                         return 5
        }
    }

    var colorName: String {
        switch self {
        case .rest:                             return "gray"
        case .recovery:                         return "mint"
        case .easy, .strides, .crossTrain,
             .shakeout:                         return "green"
        case .generalAerobic, .mediumLong,
             .midweekLong, .steadyRun:          return "teal"
        case .longRun, .marathonPace,
             .tempoRun, .strengthMP:            return "orange"
        case .lactateThreshold, .cruiseIntervals,
             .speedWork, .intervalWork,
             .repetitionWork, .longRunWithMP:   return "red"
        case .raceDay:                          return "yellow"
        }
    }

    var isQualityWorkout: Bool {
        switch self {
        case .speedWork, .strengthMP, .lactateThreshold,
             .cruiseIntervals, .intervalWork, .repetitionWork,
             .tempoRun, .longRunWithMP:
            return true
        default:
            return false
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

    init(id: UUID = UUID(), weekday: Weekday,
         workoutType: WorkoutType,
         miles: Double, description: String,
         paceNote: String) {
        self.id          = id
        self.weekday     = weekday
        self.workoutType = workoutType
        self.miles       = miles
        self.description = description
        self.paceNote    = paceNote
    }
}

// MARK: - Training Week

struct TrainingWeek: Identifiable, Codable {
    let id         : UUID
    let weekNumber : Int
    let phase      : TrainingPhase   // canonical phase enum
    let phaseLabel : String          // methodology-specific display label
    let days       : [TrainingDay]

    init(id: UUID = UUID(),
         weekNumber: Int,
         phase: TrainingPhase,
         phaseLabel: String? = nil,
         days: [TrainingDay]) {
        self.id         = id
        self.weekNumber = weekNumber
        self.phase      = phase
        self.phaseLabel = phaseLabel ?? phase.displayName
        self.days       = days
    }

    var totalMiles: Double { days.reduce(0) { $0 + $1.miles } }
    var label: String      { "Week \(weekNumber)" }

    /// Returns a copy of this week with a new phase (and updated default label).
    func settingPhase(_ newPhase: TrainingPhase) -> TrainingWeek {
        TrainingWeek(id:         id,
                     weekNumber: weekNumber,
                     phase:      newPhase,
                     phaseLabel: newPhase.displayName,
                     days:       days)
    }
}

// MARK: - User Schedule

struct UserSchedule: Codable, Equatable {
    var longRunDay     : Weekday
    var workoutDay1    : Weekday
    var workoutDay2    : Weekday
    var restDays       : [Weekday]
    var crossTrainDay  : Weekday?
    var midweekLongDay : Weekday

    static func defaultFor(_ planType: PlanType) -> UserSchedule {
        switch planType {
        case .higdon, .higdonHalfNovice:
            return UserSchedule(
                longRunDay: .sunday, workoutDay1: .tuesday,
                workoutDay2: .thursday, restDays: [.monday, .friday],
                crossTrainDay: nil, midweekLongDay: .wednesday)
        case .higdonIntermediate, .higdonHalfIntermediate:
            return UserSchedule(
                longRunDay: .sunday, workoutDay1: .tuesday,
                workoutDay2: .thursday, restDays: [.monday],
                crossTrainDay: .saturday, midweekLongDay: .wednesday)
        case .hansons, .hansonsHalf:
            return UserSchedule(
                longRunDay: .sunday, workoutDay1: .tuesday,
                workoutDay2: .thursday, restDays: [.monday],
                crossTrainDay: nil, midweekLongDay: .wednesday)
        case .pfitz:
            return UserSchedule(
                longRunDay: .saturday, workoutDay1: .tuesday,
                workoutDay2: .thursday, restDays: [.friday],
                crossTrainDay: nil, midweekLongDay: .wednesday)
        case .firstHalf:
            return UserSchedule(
                longRunDay: .saturday, workoutDay1: .tuesday,
                workoutDay2: .thursday, restDays: [.monday, .friday],
                crossTrainDay: nil, midweekLongDay: .wednesday)
        }
    }

    func validated(for planType: PlanType) -> UserSchedule {
        var s     = self
        var taken = Set<Weekday>()

        taken.insert(s.longRunDay)
        if taken.contains(s.workoutDay1) {
            s.workoutDay1 = firstFree(taken)
        }
        taken.insert(s.workoutDay1)

        if planType.requiresTwoWorkoutDays {
            if taken.contains(s.workoutDay2) {
                s.workoutDay2 = firstFree(taken)
            }
            taken.insert(s.workoutDay2)
        }

        if planType.usesMidweekLongRun {
            if taken.contains(s.midweekLongDay) {
                s.midweekLongDay = firstFree(taken)
            }
            taken.insert(s.midweekLongDay)
        }

        if planType.usesCrossTraining {
            if let ct = s.crossTrainDay {
                if taken.contains(ct) {
                    s.crossTrainDay = firstFreeOptional(taken)
                }
                if let c = s.crossTrainDay { taken.insert(c) }
            }
        } else {
            s.crossTrainDay = nil
        }

        s.restDays = Array(Set(s.restDays.filter { !taken.contains($0) }))
        return s
    }

    private func firstFree(_ taken: Set<Weekday>) -> Weekday {
        Weekday.displayOrder.first { !taken.contains($0) } ?? .monday
    }

    private func firstFreeOptional(_ taken: Set<Weekday>) -> Weekday? {
        Weekday.displayOrder.first { !taken.contains($0) }
    }
}

// MARK: - User Settings

struct UserSettings: Codable {
    var goalTimeMinutes : Int           = 210
    var baseMileage     : Double        = 25
    var planType        : PlanType      = .higdon
    var planLength      : PlanLength    = .sixteenWeek
    var schedule        : UserSchedule  = UserSchedule.defaultFor(.higdon)
    // taperDuration removed — taper length is now canonical per methodology.
    // See PlanType.canonicalTaperWeeks.

    var raceType: RaceType { planType.raceType }

    var goalTimeFormatted: String {
        let h = goalTimeMinutes / 60
        let m = goalTimeMinutes % 60
        return String(format: "%d:%02d:00", h, m)
    }

    mutating func resetScheduleForNewPlanType() {
        schedule = UserSchedule.defaultFor(planType)
    }

    func onlyScheduleDiffers(from other: UserSettings) -> Bool {
        goalTimeMinutes == other.goalTimeMinutes
            && baseMileage == other.baseMileage
            && planType    == other.planType
            && planLength  == other.planLength
            && schedule    != other.schedule
    }
}

extension UserSettings: Equatable {
    static func == (lhs: UserSettings, rhs: UserSettings) -> Bool {
        lhs.goalTimeMinutes == rhs.goalTimeMinutes
            && lhs.baseMileage == rhs.baseMileage
            && lhs.planType    == rhs.planType
            && lhs.planLength  == rhs.planLength
            && lhs.schedule    == rhs.schedule
    }
}

// MARK: - Pace Engine

struct PaceEngine {
    let goalMinutes : Int
    let distance    : Double

    init(goalMinutes: Int, distance: Double = 26.2) {
        self.goalMinutes = goalMinutes
        self.distance    = distance
    }

    var MP: Int {
        guard distance > 0 else { return 480 }
        return Int(Double(goalMinutes * 60) / distance)
    }

    var easy            : (low: Int, high: Int) { (MP + 90,  MP + 120) }
    var longRun         : (low: Int, high: Int) { (MP + 60,  MP + 90)  }
    var generalAero     : (low: Int, high: Int) { (MP + 45,  MP + 75)  }
    var recovery        : Int                   { MP + 150 }
    var pfitzLT         : Int                   { MP - 20  }
    // Hansons-specific paces
    var hansonsStrengthPace : Int               { MP - 10  }  // 10 sec/mi faster than goal MP
    var hansonsStrength : (low: Int, high: Int) { (MP - 12, MP - 8)    }  // ±2 sec tolerance around MP-10
    var hansonsTempo    : Int                   { MP       }  // marathon pace
    var hansonsSpeed    : Int                   { MP - 80  }  // goal 5K pace (~80 sec/mi faster than MP)
    var dThreshold      : Int                   { MP - 28  }
    var dInterval       : Int                   { MP - 55  }
    var dRepetition     : Int                   { MP - 80  }
    var higdonTempo     : Int                   { MP - 15  }

    static func format(_ s: Int) -> String {
        let safe = max(s, 60)
        return String(format: "%d:%02d", safe / 60, safe % 60)
    }

    func rangeString(_ r: (low: Int, high: Int)) -> String {
        "\(PaceEngine.format(r.high))–\(PaceEngine.format(r.low))/mi"
    }

    func singleString(_ s: Int) -> String {
        "\(PaceEngine.format(s))/mi"
    }
}

// MARK: - Training Paces

struct TrainingPaces {
    let easy     : (min: Int, max: Int)
    let longRun  : (min: Int, max: Int)
    let marathon : Int
    let tempo    : Int
    let interval : Int
    let recovery : Int

    static func calculate(goalMinutes: Int,
                          distance: Double = 26.2) -> TrainingPaces {
        let e = PaceEngine(goalMinutes: goalMinutes, distance: distance)
        return TrainingPaces(
            easy:     (e.easy.high, e.easy.low),
            longRun:  (e.longRun.high, e.longRun.low),
            marathon: e.MP,
            tempo:    e.pfitzLT,
            interval: e.dInterval,
            recovery: e.recovery
        )
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

func calculatePeakTargets(method: PlanType,
                           planLength: Int) -> PeakTargets {
    let pw = planLength - method.canonicalTaperWeeks
    let tw = method.canonicalTaperWeeks

    switch method {
    case .hansons:
        return PeakTargets(peakLongRun: 16, peakWeeklyMiles: 55,
                           peakWeekNumber: pw, taperWeeks: tw)
    case .pfitz:
        return PeakTargets(peakLongRun: 22, peakWeeklyMiles: 70,
                           peakWeekNumber: pw, taperWeeks: tw)
    case .higdon:
        return PeakTargets(peakLongRun: 20, peakWeeklyMiles: 40,
                           peakWeekNumber: pw, taperWeeks: tw)
    case .higdonIntermediate:
        return PeakTargets(peakLongRun: 22, peakWeeklyMiles: 48,
                           peakWeekNumber: pw, taperWeeks: tw)
    case .higdonHalfNovice:
        return PeakTargets(peakLongRun: 10, peakWeeklyMiles: 28,
                           peakWeekNumber: pw, taperWeeks: tw)
    case .higdonHalfIntermediate:
        return PeakTargets(peakLongRun: 12, peakWeeklyMiles: 35,
                           peakWeekNumber: pw, taperWeeks: tw)
    case .hansonsHalf:
        return PeakTargets(peakLongRun: 10, peakWeeklyMiles: 45,
                           peakWeekNumber: pw, taperWeeks: tw)
    case .firstHalf:
        return PeakTargets(peakLongRun: 11, peakWeeklyMiles: 28,
                           peakWeekNumber: pw, taperWeeks: tw)
    }
}

// MARK: - Method Constraints

enum ProgressionStyle {
    case cumulativeFatigue, periodicCutback
}

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
        return MethodConstraints(
            maxLongRunMiles: 16, minLongRunMiles: 8,
            longRunAsPercentage: 0.30, minRunDays: 5, maxRunDays: 6,
            requiredWorkouts: [.speedWork, .strengthMP, .longRun],
            progressionStyle: .cumulativeFatigue,
            requiresMediumLong: false, earliestQualityWeek: 1,
            allowsConsecutiveHard: false,
            absoluteMinWeekly: 25, absoluteMaxWeekly: 65)
    case .pfitz:
        return MethodConstraints(
            maxLongRunMiles: 23, minLongRunMiles: 12,
            longRunAsPercentage: 0.35, minRunDays: 5, maxRunDays: 6,
            requiredWorkouts: [.lactateThreshold, .mediumLong, .longRun],
            progressionStyle: .periodicCutback,
            requiresMediumLong: true, earliestQualityWeek: 1,
            allowsConsecutiveHard: false,
            absoluteMinWeekly: 35, absoluteMaxWeekly: 85)
    case .higdon:
        return MethodConstraints(
            maxLongRunMiles: 20, minLongRunMiles: 6,
            longRunAsPercentage: 0.40, minRunDays: 4, maxRunDays: 5,
            requiredWorkouts: [.longRun, .midweekLong],
            progressionStyle: .periodicCutback,
            requiresMediumLong: false, earliestQualityWeek: 99,
            allowsConsecutiveHard: false,
            absoluteMinWeekly: 15, absoluteMaxWeekly: 45)
    case .higdonIntermediate:
        return MethodConstraints(
            maxLongRunMiles: 22, minLongRunMiles: 8,
            longRunAsPercentage: 0.40, minRunDays: 4, maxRunDays: 6,
            requiredWorkouts: [.tempoRun, .longRun, .midweekLong, .crossTrain],
            progressionStyle: .periodicCutback,
            requiresMediumLong: false, earliestQualityWeek: 3,
            allowsConsecutiveHard: false,
            absoluteMinWeekly: 20, absoluteMaxWeekly: 55)
    case .higdonHalfNovice:
        return MethodConstraints(
            maxLongRunMiles: 10, minLongRunMiles: 4,
            longRunAsPercentage: 0.40, minRunDays: 3, maxRunDays: 4,
            requiredWorkouts: [.longRun],
            progressionStyle: .periodicCutback,
            requiresMediumLong: false, earliestQualityWeek: 99,
            allowsConsecutiveHard: false,
            absoluteMinWeekly: 12, absoluteMaxWeekly: 32)
    case .higdonHalfIntermediate:
        return MethodConstraints(
            maxLongRunMiles: 12, minLongRunMiles: 5,
            longRunAsPercentage: 0.40, minRunDays: 4, maxRunDays: 5,
            requiredWorkouts: [.tempoRun, .longRun],
            progressionStyle: .periodicCutback,
            requiresMediumLong: false, earliestQualityWeek: 3,
            allowsConsecutiveHard: false,
            absoluteMinWeekly: 15, absoluteMaxWeekly: 40)
    case .hansonsHalf:
        return MethodConstraints(
            maxLongRunMiles: 10, minLongRunMiles: 5,
            longRunAsPercentage: 0.30, minRunDays: 5, maxRunDays: 6,
            requiredWorkouts: [.speedWork, .strengthMP, .longRun],
            progressionStyle: .cumulativeFatigue,
            requiresMediumLong: false, earliestQualityWeek: 1,
            allowsConsecutiveHard: false,
            absoluteMinWeekly: 20, absoluteMaxWeekly: 50)
    case .firstHalf:
        return MethodConstraints(
            maxLongRunMiles: 11, minLongRunMiles: 3,
            longRunAsPercentage: 0.40, minRunDays: 3, maxRunDays: 4,
            requiredWorkouts: [.longRun],
            progressionStyle: .periodicCutback,
            requiresMediumLong: false, earliestQualityWeek: 99,
            allowsConsecutiveHard: false,
            absoluteMinWeekly: 10, absoluteMaxWeekly: 30)
    }
}
