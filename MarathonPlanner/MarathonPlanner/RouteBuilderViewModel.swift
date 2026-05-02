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
    let ascentM   : Double
}

// MARK: - Route Builder ViewModel

@MainActor
class RouteBuilderViewModel: NSObject, ObservableObject,
                              CLLocationManagerDelegate {

    // MARK: Published

    @Published var waypoints       : [RouteWaypoint]  = []
    @Published var segments        : [RouteSegment]   = []
    @Published var isRouting       : Bool             = false
    @Published var errorMessage    : String?          = nil
    @Published var cameraRegion    : MKCoordinateRegion
    @Published var shouldMoveCamera: Bool             = false

    // Tracks whether this is an out-and-back so UI can reflect it
    @Published var isOutAndBack    : Bool             = false

    // MARK: Computed stats

    var totalMeters: Double {
        segments.reduce(0) { $0 + $1.distanceM }
    }

    var totalMiles : Double { totalMeters / 1609.344 }
    var totalKm    : Double { totalMeters / 1000.0   }

    var totalAscentMeters: Double {
        segments.reduce(0) { $0 + $1.ascentM }
    }

    var totalAscentFeet: Double { totalAscentMeters * 3.28084 }

    var canUndo  : Bool { !waypoints.isEmpty }
    var canExport: Bool { waypoints.count >= 2 && segments.count >= 1 }

    // Half the total distance — useful label for out-and-back
    var outDistanceMiles: Double { totalMiles / 2 }

    // MARK: Private

    private let locationManager  = CLLocationManager()
    private var userCoordinate   : CLLocationCoordinate2D?
    private var didCenterOnUser  = false

    // Snapshot of segments before out-and-back was applied
    // so we can undo it cleanly
    private var outSegmentsSnapshot : [RouteSegment] = []
    private var outWaypointsSnapshot: [RouteWaypoint] = []

    // MARK: Init

    override init() {
        cameraRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude:  -33.8688,
                longitude: 151.2093
            ),
            latitudinalMeters:  3000,
            longitudinalMeters: 3000
        )
        super.init()
        locationManager.delegate        = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    // MARK: - Location Delegate

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locs: [CLLocation]
    ) {
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
                self.shouldMoveCamera = true
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didChangeAuthorization status: CLAuthorizationStatus
    ) {
        if status == .authorizedWhenInUse
            || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    // MARK: - Public Actions

    func handleTap(at coordinate: CLLocationCoordinate2D) {
        // Tapping while out-and-back is active cancels it first
        if isOutAndBack { cancelOutAndBack() }

        let wp       = RouteWaypoint(coordinate: coordinate,
                                     index: waypoints.count)
        let previous = waypoints.last
        waypoints.append(wp)
        guard let prev = previous else { return }
        Task {
            await fetchRoute(from: prev.coordinate, to: coordinate)
        }
    }

    @MainActor
    func appendWaypoint(at coordinate: CLLocationCoordinate2D) async {
        let wp       = RouteWaypoint(coordinate: coordinate,
                                     index: waypoints.count)
        let previous = waypoints.last
        waypoints.append(wp)
        guard let prev = previous else { return }
        await fetchRoute(from: prev.coordinate, to: coordinate)
    }

    func undoLast() {
        if isOutAndBack {
            cancelOutAndBack()
            return
        }
        guard !waypoints.isEmpty else { return }
        waypoints.removeLast()
        if !segments.isEmpty { segments.removeLast() }
        errorMessage = nil
    }

    func clearAll() {
        waypoints             = []
        segments              = []
        errorMessage          = nil
        isOutAndBack          = false
        outSegmentsSnapshot   = []
        outWaypointsSnapshot  = []
    }

    func centerOnUser() {
        guard let c = userCoordinate else { return }
        cameraRegion = MKCoordinateRegion(
            center:             c,
            latitudinalMeters:  2000,
            longitudinalMeters: 2000
        )
        shouldMoveCamera = true
    }

    // MARK: - Out-and-Back

    /// Mirrors the exact polyline of every existing segment in reverse
    /// and appends it as new segments. No new network calls.
    /// The return path follows pixel-perfect the same road taken out.
    func applyOutAndBack() {
        guard !segments.isEmpty else { return }

        // Save snapshot so we can undo
        outSegmentsSnapshot  = segments
        outWaypointsSnapshot = waypoints

        // Build reversed segments from the existing polylines.
        // We reverse the segment array AND reverse the coordinates
        // within each segment so the path traces back exactly.
        let returnSegments: [RouteSegment] = segments
            .reversed()
            .map { seg in
                let count  = seg.polyline.pointCount
                var coords = [CLLocationCoordinate2D](
                    repeating: kCLLocationCoordinate2DInvalid,
                    count: count
                )
                seg.polyline.getCoordinates(
                    &coords,
                    range: NSRange(location: 0, length: count)
                )

                // Reverse the coordinate order so we trace back
                let reversed  = coords.reversed()
                let polyline  = MKPolyline(
                    coordinates: Array(reversed),
                    count: count
                )

                // Ascent on the return = original descent
                // We approximate: same distance, descent becomes ascent
                return RouteSegment(
                    polyline:  polyline,
                    distanceM: seg.distanceM,
                    ascentM:   0   // returning downhill what we climbed
                )
            }

        // Add a return-start waypoint at the turnaround point
        // and a final waypoint back at the original start
        if let turnaround = waypoints.last,
           let origin     = waypoints.first {
            let returnWP = RouteWaypoint(
                coordinate: turnaround.coordinate,
                index:      waypoints.count
            )
            let endWP = RouteWaypoint(
                coordinate: origin.coordinate,
                index:      waypoints.count + 1
            )
            waypoints.append(returnWP)
            waypoints.append(endWP)
        }

        segments += returnSegments
        isOutAndBack = true
    }

    /// Removes the return half and restores the original out route.
    func cancelOutAndBack() {
        guard isOutAndBack else { return }
        segments     = outSegmentsSnapshot
        waypoints    = outWaypointsSnapshot
        isOutAndBack = false
        outSegmentsSnapshot  = []
        outWaypointsSnapshot = []
    }

    // MARK: - Route Fetching

    func fetchRoute(
        from: CLLocationCoordinate2D,
        to:   CLLocationCoordinate2D
    ) async {
        isRouting    = true
        errorMessage = nil

        let req           = MKDirections.Request()
        req.source        = MKMapItem(
            placemark: MKPlacemark(coordinate: from))
        req.destination   = MKMapItem(
            placemark: MKPlacemark(coordinate: to))
        req.transportType = .walking
        req.requestsAlternateRoutes = false

        do {
            let response = try await MKDirections(request: req).calculate()
            if let route = response.routes.first {
                var ascent = 0.0
                let steps  = route.steps
                for i in 1..<steps.count {
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
        lines.append(
            #"<gpx version="1.1" creator="Mile Zero" "#
            + #"xmlns="http://www.topografix.com/GPX/1/1">"#
        )
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
                    #"    <trkpt lat="\#(coord.latitude)" "#
                    + #"lon="\#(coord.longitude)"></trkpt>"#
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
