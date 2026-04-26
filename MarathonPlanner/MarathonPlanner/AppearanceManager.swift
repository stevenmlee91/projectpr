import SwiftUI

// MARK: - App Appearance

enum AppAppearance: String, CaseIterable, Codable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var displayName: String {
        switch self {
        case .system: return "System Default"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon"
        }
    }

    // Maps to SwiftUI ColorScheme for use in .preferredColorScheme()
    // nil means follow the system — SwiftUI's default behavior
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - Appearance Manager

class AppearanceManager: ObservableObject {
    @Published var appearance: AppAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue,
                                      forKey: "app_appearance")
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "app_appearance")
        self.appearance = AppAppearance(rawValue: saved ?? "") ?? .dark
        // Default to dark since your existing design is dark-first
    }
}
