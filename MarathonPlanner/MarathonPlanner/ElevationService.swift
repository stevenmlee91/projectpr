import Foundation
import MapKit
import CoreLocation

// MARK: - Elevation Models

struct ElevationPoint: Identifiable {
    let id          : UUID    = UUID()
    let distanceKm  : Double  // cumulative distance along route
    let altitudeM   : Double  // metres above sea level
}

struct ElevationProfile {
    let points       : [ElevationPoint]
    let gainM        : Double   // total ascent in metres
    let lossM        : Double   // total descent in metres
    let highestM     : Double   // peak altitude in metres
    let lowestM      : Double   // lowest altitude in metres
    let distanceKm   : Double   // total route distance

    var gainFeet     : Double { gainM  * 3.28084 }
    var lossFeet     : Double { lossM  * 3.28084 }
    var highestFeet  : Double { highestM  * 3.28084 }

    var difficulty: RouteDifficulty {
        guard distanceKm > 0 else { return .flat }
        let gainPer100m = gainM / (distanceKm * 10)
        switch gainPer100m {
        case ..<8:   return .flat
        case 8..<15: return .rolling
        case 15..<25: return .hilly
        default:     return .veryHilly
        }
    }
}

enum RouteDifficulty: String {
    case flat      = "Flat"
    case rolling   = "Rolling"
    case hilly     = "Hilly"
    case veryHilly = "Very Hilly"

    var color: String {
        switch self {
        case .flat:      return "30D158"
        case .rolling:   return "FFD60A"
        case .hilly:     return "FF9F0A"
        case .veryHilly: return "FF453A"
        }
    }

    var icon: String {
        switch self {
        case .flat:      return "minus"
        case .rolling:   return "arrow.up.right"
        case .hilly:     return "arrow.up.right.circle"
        case .veryHilly: return "mountain.2.fill"
        }
    }
}

// MARK: - Open-Elevation Response Models

private struct OpenElevationRequest: Encodable {
    struct Location: Encodable {
        let latitude  : Double
        let longitude : Double
    }
    let locations: [Location]
}

private struct OpenElevationResponse: Decodable {
    struct Result: Decodable {
        let latitude  : Double
        let longitude : Double
        let elevation : Double
    }
    let results: [Result]
}

// MARK: - Elevation Service

actor ElevationService {

    static let shared = ElevationService()

    // MARK: Cache — keyed by route fingerprint
    private var cache: [String: ElevationProfile] = [:]

    // MARK: - Public API

    func fetchProfile(for segments: [RouteSegment]) async throws -> ElevationProfile {

        let sampled    = sampleCoordinates(from: segments, intervalMetres: 50)
        guard !sampled.isEmpty else {
            throw ElevationError.noCoordinates
        }

        let fingerprint = cacheKey(for: sampled)
        if let cached = cache[fingerprint] { return cached }

        let altitudes  = try await fetchAltitudes(for: sampled)
        let distances  = cumulativeDistances(for: sampled)
        let profile    = buildProfile(altitudes: altitudes,
                                      distances: distances,
                                      totalKm: distances.last ?? 0)

        cache[fingerprint] = profile
        return profile
    }

    // MARK: - Coordinate Sampling

    /// Walks every polyline and samples a coordinate every ~intervalMetres.
    private func sampleCoordinates(from segments: [RouteSegment],
                                    intervalMetres: Double) -> [CLLocationCoordinate2D] {
        var result        : [CLLocationCoordinate2D] = []
        var accumulated   : Double = 0
        var lastSampled   : CLLocationCoordinate2D?

        for segment in segments {
            let count  = segment.polyline.pointCount
            var coords = [CLLocationCoordinate2D](
                repeating: kCLLocationCoordinate2DInvalid,
                count: count
            )
            segment.polyline.getCoordinates(
                &coords,
                range: NSRange(location: 0, length: count)
            )

            for coord in coords {
                guard CLLocationCoordinate2DIsValid(coord) else { continue }

                if let last = lastSampled {
                    let a   = CLLocation(latitude: last.latitude,
                                         longitude: last.longitude)
                    let b   = CLLocation(latitude: coord.latitude,
                                         longitude: coord.longitude)
                    accumulated += a.distance(from: b)
                } else {
                    // Always include the first point
                    result.append(coord)
                    lastSampled = coord
                    continue
                }

                if accumulated >= intervalMetres {
                    result.append(coord)
                    lastSampled  = coord
                    accumulated  = 0
                }
            }
        }

        // Always include the very last coordinate
        if let last = segments.last?.polyline,
           last.pointCount > 0 {
            var finalCoords = [CLLocationCoordinate2D](
                repeating: kCLLocationCoordinate2DInvalid,
                count: last.pointCount
            )
            last.getCoordinates(
                &finalCoords,
                range: NSRange(location: 0, length: last.pointCount)
            )
            if let finalCoord = finalCoords.last,
               CLLocationCoordinate2DIsValid(finalCoord) {
                result.append(finalCoord)
            }
        }

        // Cap at 500 points to stay inside Open-Elevation limits
        if result.count > 500 {
            let step = Double(result.count) / 500.0
            result   = (0..<500).map { i in
                result[min(Int(Double(i) * step), result.count - 1)]
            }
        }

        return result
    }

    // MARK: - Open-Elevation API Call

    private func fetchAltitudes(
        for coords: [CLLocationCoordinate2D]
    ) async throws -> [Double] {
        let url = URL(string: "https://api.open-elevation.com/api/v1/lookup")!
        var request        = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json",
                         forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20

        let body = OpenElevationRequest(
            locations: coords.map {
                .init(latitude: $0.latitude, longitude: $0.longitude)
            }
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw ElevationError.badResponse
        }

        let decoded = try JSONDecoder().decode(
            OpenElevationResponse.self, from: data)
        return decoded.results.map { $0.elevation }
    }

    // MARK: - Cumulative Distances

    private func cumulativeDistances(
        for coords: [CLLocationCoordinate2D]
    ) -> [Double] {
        var distances : [Double] = [0]
        var total     : Double   = 0

        for i in 1..<coords.count {
            let a = CLLocation(latitude:  coords[i - 1].latitude,
                               longitude: coords[i - 1].longitude)
            let b = CLLocation(latitude:  coords[i].latitude,
                               longitude: coords[i].longitude)
            total += a.distance(from: b) / 1000.0   // metres → km
            distances.append(total)
        }
        return distances
    }

    // MARK: - Profile Builder

    private func buildProfile(altitudes : [Double],
                               distances : [Double],
                               totalKm   : Double) -> ElevationProfile {
        guard altitudes.count == distances.count,
              !altitudes.isEmpty else {
            return ElevationProfile(points: [], gainM: 0, lossM: 0,
                                    highestM: 0, lowestM: 0, distanceKm: 0)
        }

        var points  : [ElevationPoint] = []
        var gainM   : Double = 0
        var lossM   : Double = 0

        for i in 0..<altitudes.count {
            points.append(ElevationPoint(
                distanceKm: distances[i],
                altitudeM:  altitudes[i]
            ))
            if i > 0 {
                let delta = altitudes[i] - altitudes[i - 1]
                if delta > 0 { gainM += delta }
                else         { lossM += abs(delta) }
            }
        }

        let highestM = altitudes.max() ?? 0
        let lowestM  = altitudes.min() ?? 0

        return ElevationProfile(
            points:     points,
            gainM:      gainM,
            lossM:      lossM,
            highestM:   highestM,
            lowestM:    lowestM,
            distanceKm: totalKm
        )
    }

    // MARK: - Cache Key

    private func cacheKey(for coords: [CLLocationCoordinate2D]) -> String {
        // Use first, middle, last coord + count as fingerprint
        let n     = coords.count
        let first = coords.first
        let mid   = coords[n / 2]
        let last  = coords.last
        return "\(n)_\(first?.latitude ?? 0)_\(mid.latitude)_\(last?.latitude ?? 0)"
    }
}

// MARK: - Errors

enum ElevationError: LocalizedError {
    case noCoordinates
    case badResponse
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .noCoordinates:  return "No route coordinates to analyse."
        case .badResponse:    return "Elevation service returned an error."
        case .decodingFailed: return "Could not read elevation data."
        }
    }
}
