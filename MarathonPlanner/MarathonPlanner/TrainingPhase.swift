import SwiftUI

// MARK: - Training Phase
// The single canonical representation of training phase in Mile Zero.
// Every system — generators, engine, charts, UI — uses this type only.
// No other phase representation should exist anywhere in the codebase.

enum TrainingPhase: String, Codable, CaseIterable, Equatable, Hashable {
    case base  = "base"
    case build = "build"
    case peak  = "peak"
    case taper = "taper"
    case race  = "race"

    // MARK: - Priority
    // Race > Taper > Peak > Build > Base
    // Used to resolve conflicts — only one phase is allowed per week.
    var priority: Int {
        switch self {
        case .base:  return 1
        case .build: return 2
        case .peak:  return 3
        case .taper: return 4
        case .race:  return 5
        }
    }

    // MARK: - Display

    /// Default display name. Methodology-specific labels (e.g. "Speed Phase",
    /// "Aerobic Base") are stored separately in TrainingWeek.phaseLabel.
    var displayName: String {
        switch self {
        case .base:  return "Base Building"
        case .build: return "Building Fitness"
        case .peak:  return "Peak Week"
        case .taper: return "Taper"
        case .race:  return "Race Week 🏁"
        }
    }

    var badgeLabel: String {
        switch self {
        case .base:  return "BASE"
        case .build: return "BUILD"
        case .peak:  return "PEAK"
        case .taper: return "TAPER"
        case .race:  return "RACE"
        }
    }

    // MARK: - Chart Styling

    var chartColor: Color {
        switch self {
        case .base:  return Color(hex: "30D158").opacity(0.35)
        case .build: return Color(.systemFill)
        case .peak:  return Color(hex: "FF453A")
        case .taper: return Color(hex: "FF9F0A")
        case .race:  return Color.yellow
        }
    }

    var accentColor: Color {
        switch self {
        case .base:  return Color(hex: "30D158")
        case .build: return Color(hex: "0A84FF")
        case .peak:  return Color(hex: "FF453A")
        case .taper: return Color(hex: "FF9F0A")
        case .race:  return Color.yellow
        }
    }

    var badgeForeground: Color {
        switch self {
        case .taper, .race: return .black
        default:            return .white
        }
    }

    var badgeBackground: Color { accentColor }

    // MARK: - Legacy Migration

    /// Converts an old String phase value to TrainingPhase.
    /// Used when decoding existing SavedPlan data from UserDefaults.
    static func from(legacyString s: String) -> TrainingPhase {
        let l = s.lowercased()
        if l.contains("race")                            { return .race  }
        if l.contains("taper")                           { return .taper }
        if l.contains("peak")                            { return .peak  }
        if l.contains("speed")     || l.contains("strength")   ||
           l.contains("threshold") || l.contains("specific")   ||
           l.contains("build")     || l.contains("lactate")    ||
           l.contains("aerobic")   || l.contains("phase ii")   ||
           l.contains("phase iii")                       { return .build }
        return .base
    }
}
