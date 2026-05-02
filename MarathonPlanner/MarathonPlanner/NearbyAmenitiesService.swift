import Foundation
import SwiftUI
import MapKit
import CoreLocation

// MARK: - Amenity Type

enum AmenityType: String, CaseIterable, Identifiable {
    case water    = "Water"
    case restroom = "Restroom"
    case park     = "Park"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .water:    return "drop.fill"
        case .restroom: return "figure.dress.line.vertical.figure"
        case .park:     return "leaf.fill"
        }
    }

    var color: UIColor {
        switch self {
        case .water:    return UIColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 1.0)
        case .restroom: return UIColor(red: 0.48, green: 0.30, blue: 0.95, alpha: 1.0)
        case .park:     return UIColor(red: 0.19, green: 0.82, blue: 0.35, alpha: 1.0)
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .water:    return Color(hex: "0A84FF")
        case .restroom: return Color(hex: "BF5AF2")
        case .park:     return Color(hex: "30D158")
        }
    }

    var pointOfInterestCategory: MKPointOfInterestCategory? {
        switch self {
        case .water:    return nil           // no native category — use keyword search
        case .restroom: return .restroom
        case .park:     return .park
        }
    }

    var searchTerms: [String] {
        switch self {
        case .water:
            return ["drinking water fountain", "water fountain"]
        case .restroom:
            return ["public restroom", "public toilet", "bathroom"]
        case .park:
            return ["park", "nature reserve", "recreation area"]
        }
    }
}

// MARK: - Amenity Result

struct AmenityResult: Identifiable {
    let id          : UUID = UUID()
    let name        : String
    let coordinate  : CLLocationCoordinate2D
    let type        : AmenityType
    let mapItem     : MKMapItem

    var distanceFromRoute: Double? // metres, set after search
}

// MARK: - Amenity Annotation

class AmenityAnnotation: MKPointAnnotation {
    var amenityType : AmenityType = .water
    var amenityName : String      = ""
    var amenityID   : UUID        = UUID()
}

// MARK: - Nearby Amenities Service

actor NearbyAmenitiesService {

    static let shared = NearbyAmenitiesService()

    // Simple cache keyed by region fingerprint + type
    private var cache: [String: [AmenityResult]] = [:]

    // MARK: - Search

    func search(
        in region       : MKCoordinateRegion,
        types           : [AmenityType],
        routeCoords     : [CLLocationCoordinate2D]
    ) async -> [AmenityResult] {

        let key = cacheKey(region: region, types: types)
        if let cached = cache[key] { return cached }

        var results: [AmenityResult] = []

        await withTaskGroup(of: [AmenityResult].self) { group in
            for type in types {
                group.addTask {
                    await self.searchType(type, in: region)
                }
            }
            for await typeResults in group {
                results.append(contentsOf: typeResults)
            }
        }

        // Remove duplicates by proximity (within 30m = same place)
        results = deduplicated(results)

        // Calculate distance from route for each result
        if !routeCoords.isEmpty {
            results = results.map { result in
                var r = result
                r.distanceFromRoute = minDistance(
                    from: result.coordinate,
                    to:   routeCoords
                )
                return r
            }
            // Filter to only show amenities within 300m of the route
            results = results.filter {
                ($0.distanceFromRoute ?? Double.infinity) < 300
            }
        }

        cache[key] = results
        return results
    }

    func clearCache() {
        cache = [:]
    }

    // MARK: - Private

    private func searchType(
        _ type   : AmenityType,
        in region: MKCoordinateRegion
    ) async -> [AmenityResult] {
        var allResults: [AmenityResult] = []

        // Search by POI category first
        let categoryRequest            = MKLocalSearch.Request()
        categoryRequest.region         = region
        categoryRequest.resultTypes    = .pointOfInterest
        if let category = type.pointOfInterestCategory {
            categoryRequest.pointOfInterestFilter = MKPointOfInterestFilter(
                including: [category]
            )
        }

        do {
            let response = try await MKLocalSearch(
                request: categoryRequest).start()
            let mapped   = response.mapItems.map { item in
                AmenityResult(
                    name:       item.name ?? type.rawValue,
                    coordinate: item.placemark.coordinate,
                    type:       type,
                    mapItem:    item
                )
            }
            allResults.append(contentsOf: mapped)
        } catch { }

        // Supplement with keyword search if category returns few results
        if allResults.count < 3 {
            for term in type.searchTerms.prefix(1) {
                let kwRequest                  = MKLocalSearch.Request()
                kwRequest.region               = region
                kwRequest.naturalLanguageQuery = term
                kwRequest.resultTypes          = .pointOfInterest
                do {
                    let response = try await MKLocalSearch(
                        request: kwRequest).start()
                    let mapped   = response.mapItems.map { item in
                        AmenityResult(
                            name:       item.name ?? type.rawValue,
                            coordinate: item.placemark.coordinate,
                            type:       type,
                            mapItem:    item
                        )
                    }
                    allResults.append(contentsOf: mapped)
                } catch { }
            }
        }

        return allResults
    }

    // MARK: - Deduplication

    private func deduplicated(
        _ results: [AmenityResult]
    ) -> [AmenityResult] {
        var kept: [AmenityResult] = []
        for result in results {
            let isDuplicate = kept.contains { existing in
                let a = CLLocation(
                    latitude:  existing.coordinate.latitude,
                    longitude: existing.coordinate.longitude)
                let b = CLLocation(
                    latitude:  result.coordinate.latitude,
                    longitude: result.coordinate.longitude)
                return a.distance(from: b) < 30
            }
            if !isDuplicate { kept.append(result) }
        }
        return kept
    }

    // MARK: - Distance from Route

    private func minDistance(
        from point  : CLLocationCoordinate2D,
        to coords   : [CLLocationCoordinate2D]
    ) -> Double {
        let loc = CLLocation(latitude:  point.latitude,
                             longitude: point.longitude)
        return coords.reduce(Double.infinity) { minDist, coord in
            let routeLoc = CLLocation(latitude:  coord.latitude,
                                      longitude: coord.longitude)
            return min(minDist, loc.distance(from: routeLoc))
        }
    }

    // MARK: - Cache Key

    private func cacheKey(
        region : MKCoordinateRegion,
        types  : [AmenityType]
    ) -> String {
        let lat   = String(format: "%.3f", region.center.latitude)
        let lon   = String(format: "%.3f", region.center.longitude)
        let span  = String(format: "%.3f", region.span.latitudeDelta)
        let typeStr = types.map { $0.rawValue }.sorted().joined()
        return "\(lat)_\(lon)_\(span)_\(typeStr)"
    }
}
