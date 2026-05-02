import Foundation
import MapKit
import SwiftUI

// MARK: - Saved Route Model

struct SavedRoute: Identifiable, Codable {
    let id            : UUID
    var name          : String
    var distanceMeters: Double
    var ascentMeters  : Double
    var difficulty    : String        // "Flat" | "Rolling" | "Hilly" | "Very Hilly"
    var dateCreated   : Date
    var isFavorite    : Bool
    var coordinateData: [RouteCoordinateData]  // encoded waypoint path
    var thumbnailData : Data?                  // PNG snapshot

    init(id: UUID = UUID(),
         name: String,
         distanceMeters: Double,
         ascentMeters: Double,
         difficulty: String,
         dateCreated: Date = Date(),
         isFavorite: Bool = false,
         coordinateData: [RouteCoordinateData],
         thumbnailData: Data? = nil) {
        self.id             = id
        self.name           = name
        self.distanceMeters = distanceMeters
        self.ascentMeters   = ascentMeters
        self.difficulty     = difficulty
        self.dateCreated    = dateCreated
        self.isFavorite     = isFavorite
        self.coordinateData = coordinateData
        self.thumbnailData  = thumbnailData
    }

    // MARK: Computed display values

    var distanceMiles: Double { distanceMeters / 1609.344 }
    var distanceKm   : Double { distanceMeters / 1000.0   }
    var ascentFeet   : Double { ascentMeters   * 3.28084  }

    var difficultyColor: Color {
        switch difficulty {
        case "Flat":       return Color(hex: "30D158")
        case "Rolling":    return Color(hex: "FFD60A")
        case "Hilly":      return Color(hex: "FF9F0A")
        case "Very Hilly": return Color(hex: "FF453A")
        default:           return Color(hex: "30D158")
        }
    }

    var thumbnail: UIImage? {
        guard let data = thumbnailData else { return nil }
        return UIImage(data: data)
    }

    var formattedDate: String {
        let f          = DateFormatter()
        f.dateStyle    = .medium
        f.timeStyle    = .none
        return f.string(from: dateCreated)
    }
}

// MARK: - Coordinate Data (Codable wrapper for CLLocationCoordinate2D)

struct RouteCoordinateData: Codable {
    let latitude : Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.latitude  = coordinate.latitude
        self.longitude = coordinate.longitude
    }
}

// MARK: - Route Store

@MainActor
class SavedRouteStore: ObservableObject {

    @Published var routes: [SavedRoute] = []

    private let key = "saved_routes_v1"

    init() { load() }

    // MARK: - CRUD

    func save(_ route: SavedRoute) {
        routes.removeAll { $0.id == route.id }
        if route.isFavorite {
            routes.insert(route, at: 0)
        } else {
            // Insert after favorites
            let firstNonFav = routes.firstIndex { !$0.isFavorite } ?? routes.endIndex
            routes.insert(route, at: firstNonFav)
        }
        persist()
    }

    func delete(_ route: SavedRoute) {
        routes.removeAll { $0.id == route.id }
        persist()
    }

    func delete(at offsets: IndexSet) {
        routes.remove(atOffsets: offsets)
        persist()
    }

    func rename(_ route: SavedRoute, to newName: String) {
        guard let i = routes.firstIndex(where: { $0.id == route.id })
        else { return }
        routes[i].name = newName
        persist()
    }

    func toggleFavorite(_ route: SavedRoute) {
        guard let i = routes.firstIndex(where: { $0.id == route.id })
        else { return }
        routes[i].isFavorite.toggle()
        // Re-sort so favorites stay at top
        routes.sort {
            if $0.isFavorite != $1.isFavorite { return $0.isFavorite }
            return $0.dateCreated > $1.dateCreated
        }
        persist()
    }

    func duplicate(_ route: SavedRoute) {
        var copy      = route
        copy = SavedRoute(
            name:           "\(route.name) Copy",
            distanceMeters: route.distanceMeters,
            ascentMeters:   route.ascentMeters,
            difficulty:     route.difficulty,
            dateCreated:    Date(),
            isFavorite:     false,
            coordinateData: route.coordinateData,
            thumbnailData:  route.thumbnailData
        )
        save(copy)
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(routes) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load() {
        guard
            let data   = UserDefaults.standard.data(forKey: key),
            let decoded = try? JSONDecoder().decode([SavedRoute].self,
                                                    from: data)
        else { return }
        routes = decoded
    }
}
