import MapKit
import SwiftUI

// MARK: - Map Layer

enum MapLayer: String, CaseIterable, Identifiable {
    case standard  = "Standard"
    case muted     = "Muted"
    case satellite = "Satellite"
    case hybrid    = "Hybrid"
    case dark      = "Dark"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .standard:  return "map"
        case .muted:     return "map.fill"
        case .satellite: return "globe.americas.fill"
        case .hybrid:    return "square.2.layers.3d"
        case .dark:      return "moon.fill"
        }
    }

    var label: String { rawValue }

    var description: String {
        switch self {
        case .standard:  return "Default Apple Maps"
        case .muted:     return "Subtle, low-contrast"
        case .satellite: return "Aerial imagery"
        case .hybrid:    return "Aerial + road labels"
        case .dark:      return "Dark mode optimised"
        }
    }

    // The polyline color that reads best on each layer
    var routeColor: UIColor {
        switch self {
        case .standard:  return UIColor(Color(hex: "0A84FF"))
        case .muted:     return UIColor(Color(hex: "0A84FF"))
        case .satellite: return UIColor(Color(hex: "FFD60A"))
        case .hybrid:    return UIColor(Color(hex: "FFD60A"))
        case .dark:      return UIColor(Color(hex: "30D158"))
        }
    }

    var routeCasingColor: UIColor {
        switch self {
        case .standard:  return UIColor.white
        case .muted:     return UIColor.white
        case .satellite: return UIColor.black.withAlphaComponent(0.6)
        case .hybrid:    return UIColor.black.withAlphaComponent(0.6)
        case .dark:      return UIColor.black.withAlphaComponent(0.8)
        }
    }
}

// MARK: - Map POI Filter

enum MapPOIMode: String, CaseIterable, Identifiable {
    case runnerFocused = "Runner"
    case all           = "All"
    case minimal       = "Minimal"
    case none          = "None"

    var id: String { rawValue }

    var filter: MKPointOfInterestFilter {
        switch self {
        case .runnerFocused:
            return MKPointOfInterestFilter(including: [
                .park,
                .beach,
                .nationalPark,
                .marina,
                .restroom,
                .fitnessCenter,
                .stadium,
                .publicTransport,
            ])
        case .all:
            return .includingAll
        case .minimal:
            return MKPointOfInterestFilter(including: [
                .park,
                .restroom,
            ])
        case .none:
            return .excludingAll
        }
    }

    var icon: String {
        switch self {
        case .runnerFocused: return "figure.run"
        case .all:           return "mappin.and.ellipse"
        case .minimal:       return "leaf"
        case .none:          return "mappin.slash"
        }
    }
}
