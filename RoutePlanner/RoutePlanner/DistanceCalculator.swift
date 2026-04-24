import CoreLocation

struct DistanceCalculator {
    static func totalMiles(from points: [CLLocationCoordinate2D]) -> Double {
        guard points.count > 1 else { return 0 }

        var distance: Double = 0

        for i in 0..<points.count - 1 {
            let start = CLLocation(latitude: points[i].latitude, longitude: points[i].longitude)
            let end = CLLocation(latitude: points[i+1].latitude, longitude: points[i+1].longitude)
            distance += start.distance(from: end)
        }

        return distance / 1609.34
    }
}
