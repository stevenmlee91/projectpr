import Foundation

// MARK: - Enums

enum PlanType: String, CaseIterable, Identifiable {
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
            return "Cumulative fatigue model. You always train tired. Long run capped at 16 mi. Race day feels easy by comparison."
        case .higdon:
            return "Gentle build-up. Mostly easy running. Long run is the main event. Best for first-timers."
        case .higdonIntermediate:
            return "Adds a midweek tempo run. Slightly higher mileage. For runners with 1–2 marathons completed."
        case .jackDaniels:
            return "VDOT-based precision. Two structured quality days (Q1 + Q2). Every pace is mathematically derived."
        }
    }
}

enum PlanLength: Int, CaseIterable, Identifiable {
    case twelveWeek   = 12
    case sixteenWeek  = 16
    case eighteenWeek = 18

    var id: Int { rawValue }
    var label: String { "\(rawValue) Weeks" }
}

enum Weekday: Int, CaseIterable, Identifiable {
    case monday = 0, tuesday, wednesday, thursday, friday, saturday, sunday

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .monday:    return "Mon"
        case .tuesday:   return "Tue"
        case .wednesday: return "Wed"
        case .thursday:  return "Thu"
        case .friday:    return "Fri"
        case .saturday:  return "Sat"
        case .sunday:    return "Sun"
        }
    }

    var fullName: String {
        switch self {
        case .monday:    return "Monday"
        case .tuesday:   return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday:  return "Thursday"
        case .friday:    return "Friday"
        case .saturday:  return "Saturday"
        case .sunday:    return "Sunday"
        }
    }
}

enum WorkoutType: String {
    case rest             = "Rest"
    case easy             = "Easy Run"
    case recovery         = "Recovery Run"
    case generalAerobic   = "General Aerobic"
    case mediumLong       = "Medium-Long Run"
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

    var effortLevel: Int {
        switch self {
        case .rest:                                            return 0
        case .recovery:                                        return 1
        case .easy, .strides:                                 return 2
        case .generalAerobic, .mediumLong:                    return 3
        case .longRun, .marathonPace, .tempoRun, .strengthMP: return 4
        case .lactateThreshold, .cruiseIntervals, .speedWork,
             .intervalWork, .repetitionWork, .longRunWithMP:  return 5
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

// MARK: - Core Data Models

struct TrainingDay: Identifiable {
    let id          = UUID()
    let weekday     : Weekday
    let workoutType : WorkoutType
    let miles       : Double
    let description : String
    let paceNote    : String
}

struct TrainingWeek: Identifiable {
    let id         = UUID()
    let weekNumber : Int
    let phase      : String
    let days       : [TrainingDay]

    var totalMiles: Double {
        days.reduce(0) { $0 + $1.miles }
    }
    var label: String { "Week \(weekNumber)" }
}

// MARK: - User Settings

struct UserSettings {
    var goalTimeMinutes : Int    = 210
    var baseMileage     : Double = 25
    var planType        : PlanType   = .higdon
    var planLength      : PlanLength = .sixteenWeek
    var longRunDay      : Weekday = .saturday
    var workoutDay1     : Weekday = .tuesday
    var workoutDay2     : Weekday = .thursday
    var restDays        : [Weekday] = [.friday]

    var goalTimeFormatted: String {
        let h = goalTimeMinutes / 60
        let m = goalTimeMinutes % 60
        return String(format: "%d:%02d:00", h, m)
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
    var hansonsStrength : (low: Int, high: Int) { (MP - 5,  MP + 5)   }
    var hansonsSpeed    : Int                   { MP - 55  }
    var dThreshold      : Int                   { MP - 28  }
    var dInterval       : Int                   { MP - 55  }
    var dRepetition     : Int                   { MP - 80  }
    var higdonTempo     : Int                   { MP - 15  }

    static func format(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    func rangeString(_ range: (low: Int, high: Int)) -> String {
        "\(PaceEngine.format(range.high))–\(PaceEngine.format(range.low))/mi"
    }

    func singleString(_ seconds: Int) -> String {
        "\(PaceEngine.format(seconds))/mi"
    }
}

// MARK: - Training Paces (Paces tab)

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
            easy:     (e.easy.high,    e.easy.low),
            longRun:  (e.longRun.high, e.longRun.low),
            marathon: e.MP,
            tempo:    e.pfitzLT,
            interval: e.dInterval,
            recovery: e.recovery
        )
    }

    static func format(_ seconds: Int) -> String { PaceEngine.format(seconds) }
}

// MARK: - Peak Targets
// NON-NEGOTIABLE method peaks.
// These are the numbers every user MUST reach by peak week,
// regardless of base mileage. Base mileage only controls
// how fast they get there, not where they end up.

struct PeakTargets {
    let peakLongRun     : Double   // Miles. Hard ceiling AND hard floor for peak week.
    let peakWeeklyMiles : Double   // Total miles in peak week.
    let peakWeekNumber  : Int      // Which week is the peak (typically week 13–14).
    let taperWeeks      : Int      // How many weeks of taper after peak.
}

func calculatePeakTargets(method: PlanType, planLength: Int) -> PeakTargets {
    let peakWeek = planLength - 4   // Peak is always 4 weeks from race day

    switch method {
    case .hansons:
        // Hansons: long run hard-capped at 16. Always. Non-negotiable.
        // Weekly mileage peaks at 55–60 depending on runner level.
        return PeakTargets(
            peakLongRun:     16,
            peakWeeklyMiles: 55,
            peakWeekNumber:  peakWeek,
            taperWeeks:      2
        )
    case .pfitz:
        // Pfitz: long runs up to 22 miles. High weekly mileage.
        return PeakTargets(
            peakLongRun:     22,
            peakWeeklyMiles: 70,
            peakWeekNumber:  peakWeek,
            taperWeeks:      3
        )
    case .higdon:
        // Higdon: long run peaks at 20. Lower overall mileage.
        return PeakTargets(
            peakLongRun:     20,
            peakWeeklyMiles: 40,
            peakWeekNumber:  peakWeek,
            taperWeeks:      2
        )
    case .higdonIntermediate:
        return PeakTargets(
            peakLongRun:     22,
            peakWeeklyMiles: 48,
            peakWeekNumber:  peakWeek,
            taperWeeks:      2
        )
    case .jackDaniels:
        // Daniels: long run capped at 25% of weekly miles, so peak long
        // run follows from peak weekly mileage.
        return PeakTargets(
            peakLongRun:     18,
            peakWeeklyMiles: 60,
            peakWeekNumber:  peakWeek,
            taperWeeks:      2
        )
    }
}

// MARK: - Method Constraints

enum ProgressionStyle {
    case cumulativeFatigue
    case periodicCutback
    case phasedQuality
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
            progressionStyle: .cumulativeFatigue, requiresMediumLong: false,
            earliestQualityWeek: 1, allowsConsecutiveHard: false,
            absoluteMinWeekly: 25, absoluteMaxWeekly: 65
        )
    case .pfitz:
        return MethodConstraints(
            maxLongRunMiles: 23, minLongRunMiles: 12,
            longRunAsPercentage: 0.35, minRunDays: 5, maxRunDays: 6,
            requiredWorkouts: [.lactateThreshold, .mediumLong, .longRun],
            progressionStyle: .periodicCutback, requiresMediumLong: true,
            earliestQualityWeek: 1, allowsConsecutiveHard: false,
            absoluteMinWeekly: 35, absoluteMaxWeekly: 85
        )
    case .higdon:
        return MethodConstraints(
            maxLongRunMiles: 20, minLongRunMiles: 6,
            longRunAsPercentage: 0.40, minRunDays: 3, maxRunDays: 5,
            requiredWorkouts: [.longRun],
            progressionStyle: .periodicCutback, requiresMediumLong: false,
            earliestQualityWeek: 99, allowsConsecutiveHard: false,
            absoluteMinWeekly: 15, absoluteMaxWeekly: 45
        )
    case .higdonIntermediate:
        return MethodConstraints(
            maxLongRunMiles: 22, minLongRunMiles: 8,
            longRunAsPercentage: 0.40, minRunDays: 4, maxRunDays: 5,
            requiredWorkouts: [.tempoRun, .longRun],
            progressionStyle: .periodicCutback, requiresMediumLong: false,
            earliestQualityWeek: 3, allowsConsecutiveHard: false,
            absoluteMinWeekly: 20, absoluteMaxWeekly: 55
        )
    case .jackDaniels:
        return MethodConstraints(
            maxLongRunMiles: 22, minLongRunMiles: 8,
            longRunAsPercentage: 0.25, minRunDays: 4, maxRunDays: 6,
            requiredWorkouts: [.repetitionWork, .cruiseIntervals, .intervalWork],
            progressionStyle: .phasedQuality, requiresMediumLong: false,
            earliestQualityWeek: 1, allowsConsecutiveHard: false,
            absoluteMinWeekly: 25, absoluteMaxWeekly: 75
        )
    }
}
