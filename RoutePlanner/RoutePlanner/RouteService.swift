import MapKit

class RouteService {
    static func fetchRoute(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        completion: @escaping ([CLLocationCoordinate2D]) -> Void
    ) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        request.transportType = .walking   // 👈 best for runners
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)

        directions.calculate { response, error in
            guard let route = response?.routes.first else {
                print("Routing error:", error?.localizedDescription ?? "Unknown")
                completion([])
                return
            }

            let coords = route.polyline.coordinates()
            completion(coords)
        }
    }
}
import MapKit

extension MKPolyline {
    func coordinates() -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
