import Foundation
import MapKit
import CoreLocation

// MARK: - Route Waypoint

struct RouteWaypoint: Identifiable {
    let id         : UUID = UUID()
    let coordinate : CLLocationCoordinate2D
    let label      : String

    init(coordinate: CLLocationCoordinate2D, index: Int) {
        self.coordinate = coordinate
        self.label      = "Point \(index + 1)"
    }
}

// MARK: - Route Segment

struct RouteSegment: Identifiable {
    let id        : UUID     = UUID()
    let polyline  : MKPolyline
    let distanceM : Double
    let ascentM   : Double   // estimated elevation gain
}

// MARK: - Route Builder ViewModel

@MainActor
class RouteBuilderViewModel: NSObject, ObservableObject,
                              CLLocationManagerDelegate {

    // MARK: Published

    @Published var waypoints    : [RouteWaypoint]  = []
    @Published var segments     : [RouteSegment]   = []
    @Published var isRouting    : Bool             = false
    @Published var errorMessage : String?          = nil
    @Published var cameraRegion : MKCoordinateRegion

    // MARK: Computed stats

    var totalMeters: Double {
        segments.reduce(0) { $0 + $1.distanceM }
    }

    var totalMiles: Double { totalMeters / 1609.344 }
    var totalKm   : Double { totalMeters / 1000.0   }

    var totalAscentMeters: Double {
        segments.reduce(0) { $0 + $1.ascentM }
    }

    var totalAscentFeet: Double { totalAscentMeters * 3.28084 }

    var canUndo   : Bool { !waypoints.isEmpty }
    var canExport : Bool { waypoints.count >= 2 && segments.count >= 1 }

    // MARK: Private

    private let locationManager = CLLocationManager()
    private var userCoordinate  : CLLocationCoordinate2D?
    private var didCenterOnUser = false

    // MARK: Init

    override init() {
        // Default camera — Sydney CBD. Will move to user location on first fix.
        cameraRegion = MKCoordinateRegion(
            center:     CLLocationCoordinate2D(latitude: -33.8688,
                                               longitude: 151.2093),
            latitudinalMeters:  3000,
            longitudinalMeters: 3000
        )
        super.init()
        locationManager.delegate        = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    // MARK: - Location delegate

    nonisolated func locationManager(_ manager: CLLocationManager,
                                      didUpdateLocations locs: [CLLocation]) {
        guard let loc = locs.last else { return }
        Task { @MainActor in
            self.userCoordinate = loc.coordinate
            if !self.didCenterOnUser {
                self.didCenterOnUser = true
                self.cameraRegion = MKCoordinateRegion(
                    center:             loc.coordinate,
                    latitudinalMeters:  2000,
                    longitudinalMeters: 2000
                )
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                      didChangeAuthorization s: CLAuthorizationStatus) {
        if s == .authorizedWhenInUse || s == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    // MARK: - Public actions

    func handleTap(at coordinate: CLLocationCoordinate2D) {
        let wp = RouteWaypoint(coordinate: coordinate,
                               index: waypoints.count)
        let previous = waypoints.last
        waypoints.append(wp)
        guard let prev = previous else { return }
        Task { await fetchRoute(from: prev.coordinate, to: coordinate) }
    }

    func undoLast() {
        guard !waypoints.isEmpty else { return }
        waypoints.removeLast()
        if !segments.isEmpty { segments.removeLast() }
        errorMessage = nil
    }

    func clearAll() {
        waypoints    = []
        segments     = []
        errorMessage = nil
    }

    func centerOnUser() {
        guard let c = userCoordinate else { return }
        cameraRegion = MKCoordinateRegion(
            center:             c,
            latitudinalMeters:  2000,
            longitudinalMeters: 2000
        )
    }

    // MARK: - Route fetching

    private func fetchRoute(from: CLLocationCoordinate2D,
                             to:   CLLocationCoordinate2D) async {
        isRouting    = true
        errorMessage = nil

        let req               = MKDirections.Request()
        req.source            = MKMapItem(placemark: MKPlacemark(coordinate: from))
        req.destination       = MKMapItem(placemark: MKPlacemark(coordinate: to))
        req.transportType     = .walking
        req.requestsAlternateRoutes = false

        do {
            let response = try await MKDirections(request: req).calculate()
            if let route = response.routes.first {
                // Estimate ascent: sum positive altitude deltas across steps
                var ascent = 0.0
                let steps  = route.steps
                for i in 1..<steps.count {
                    // MKRoute.Step doesn't give elevation directly.
                    // We use a conservative 1.5% average grade estimate
                    // on any step whose distance is non-trivial.
                    let d = steps[i].distance
                    if d > 10 { ascent += d * 0.015 }
                }
                let seg = RouteSegment(
                    polyline:  route.polyline,
                    distanceM: route.distance,
                    ascentM:   ascent
                )
                segments.append(seg)
            }
        } catch {
            // Route failed — remove the waypoint we just added
            if !waypoints.isEmpty { waypoints.removeLast() }
            errorMessage = "No walkable route found here. Try tapping closer to a road or path."
        }

        isRouting = false
    }

    // MARK: - GPX Export

    func buildGPX() -> URL? {
        guard canExport else { return nil }

        var lines: [String] = []
        lines.append(#"<?xml version="1.0" encoding="UTF-8"?>"#)
        lines.append(#"<gpx version="1.1" creator="Mile Zero" xmlns="http://www.topografix.com/GPX/1/1">"#)
        lines.append(#"  <trk><name>Mile Zero Route</name><trkseg>"#)

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
                lines.append(
                    #"    <trkpt lat="\#(coord.latitude)" lon="\#(coord.longitude)"></trkpt>"#
                )
            }
        }

        lines.append(#"  </trkseg></trk>"#)
        lines.append(#"</gpx>"#)

        let gpx = lines.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MileZeroRoute.gpx")
        try? gpx.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
