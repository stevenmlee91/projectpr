import SwiftUI
import MapKit

// MARK: - Route Map View

struct RouteMapView: UIViewRepresentable {

    @ObservedObject var vm  : RouteBuilderViewModel
    var mapLayer             : MapLayer
    var poiMode              : MapPOIMode
    var showsCompass         : Bool
    var showsScale           : Bool
    var useMetric            : Bool
    var isEditing            : Bool          // ← NEW: controls tap-to-place
    var amenities            : [AmenityResult]
    var selectedAmenity      : AmenityResult?

    init(vm: RouteBuilderViewModel,
         mapLayer: MapLayer = .standard,
         poiMode: MapPOIMode = .runnerFocused,
         showsCompass: Bool = true,
         showsScale: Bool = true,
         useMetric: Bool = false,
         isEditing: Bool = true,            // ← NEW
         amenities: [AmenityResult] = [],
         selectedAmenity: AmenityResult? = nil) {
        self.vm              = vm
        self.mapLayer        = mapLayer
        self.poiMode         = poiMode
        self.showsCompass    = showsCompass
        self.showsScale      = showsScale
        self.useMetric       = useMetric
        self.isEditing       = isEditing    // ← NEW
        self.amenities       = amenities
        self.selectedAmenity = selectedAmenity
    }

    // MARK: Make

    func makeUIView(context: Context) -> MKMapView {
        let map                = MKMapView()
        map.delegate           = context.coordinator
        map.showsUserLocation  = true
        map.showsCompass       = showsCompass
        map.showsScale         = showsScale
        map.isRotateEnabled    = true
        map.isPitchEnabled     = false
        map.userTrackingMode   = .none
        map.setRegion(vm.cameraRegion, animated: false)

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        map.addGestureRecognizer(tap)

        applyMapLayer(map, layer: mapLayer)
        map.pointOfInterestFilter = poiMode.filter
        return map
    }

    // MARK: Update

    func updateUIView(_ map: MKMapView, context: Context) {

        // Keep coordinator in sync with current editing state
        context.coordinator.isEditing = isEditing   // ← NEW

        if vm.shouldMoveCamera {
            map.setRegion(vm.cameraRegion, animated: true)
            DispatchQueue.main.async { vm.shouldMoveCamera = false }
        }

        applyMapLayer(map, layer: mapLayer)
        map.pointOfInterestFilter = poiMode.filter
        map.showsCompass          = showsCompass
        map.showsScale            = showsScale

        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations.filter {
            !($0 is MKUserLocation)
        })

        // Route polylines
        for segment in vm.segments {
            let casing       = CasingPolyline(
                points: segment.polyline.points(),
                count:  segment.polyline.pointCount
            )
            casing.layer = mapLayer
            map.addOverlay(casing, level: .aboveRoads)

            let route        = RoutePolyline(
                points: segment.polyline.points(),
                count:  segment.polyline.pointCount
            )
            route.layer = mapLayer
            map.addOverlay(route, level: .aboveRoads)
        }

        // Distance markers
        let markers = buildDistanceMarkers(
            from: vm.segments, useMetric: useMetric)
        map.addAnnotations(markers)

        // Amenity annotations
        for amenity in amenities {
            let ann            = AmenityAnnotation()
            ann.coordinate     = amenity.coordinate
            ann.amenityType    = amenity.type
            ann.amenityName    = amenity.name
            ann.amenityID      = amenity.id
            ann.title          = amenity.name
            map.addAnnotation(ann)
        }

        // Waypoint pins
        for (i, wp) in vm.waypoints.enumerated() {
            let pin        = WaypointAnnotation()
            pin.coordinate = wp.coordinate
            pin.title      = i == 0 ? "Start"
                           : i == vm.waypoints.count - 1 ? "End"
                           : "•"
            pin.index      = i
            pin.isLast     = i == vm.waypoints.count - 1
            map.addAnnotation(pin)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(vm: vm) }

    // MARK: - Apply Map Layer

    private func applyMapLayer(_ map: MKMapView, layer: MapLayer) {
        if #available(iOS 16.0, *) {
            switch layer {
            case .standard:
                let c = MKStandardMapConfiguration()
                c.emphasisStyle         = .default
                c.pointOfInterestFilter = poiMode.filter
                map.preferredConfiguration    = c
                map.overrideUserInterfaceStyle = .unspecified
            case .muted:
                let c = MKStandardMapConfiguration()
                c.emphasisStyle         = .muted
                c.pointOfInterestFilter = poiMode.filter
                map.preferredConfiguration    = c
                map.overrideUserInterfaceStyle = .unspecified
            case .satellite:
                map.preferredConfiguration    = MKImageryMapConfiguration()
                map.overrideUserInterfaceStyle = .unspecified
            case .hybrid:
                let c = MKHybridMapConfiguration()
                c.pointOfInterestFilter       = poiMode.filter
                map.preferredConfiguration    = c
                map.overrideUserInterfaceStyle = .unspecified
            case .dark:
                let c = MKStandardMapConfiguration()
                c.emphasisStyle         = .muted
                c.pointOfInterestFilter = poiMode.filter
                map.preferredConfiguration    = c
                map.overrideUserInterfaceStyle = .dark
            }
        } else {
            switch layer {
            case .satellite: map.mapType = .satellite
            case .hybrid:    map.mapType = .hybrid
            default:         map.mapType = .standard
            }
        }
    }

    // MARK: - Distance Markers

    private func buildDistanceMarkers(
        from segments : [RouteSegment],
        useMetric     : Bool
    ) -> [DistanceMarkerAnnotation] {
        guard !segments.isEmpty else { return [] }

        let intervalMeters : Double = useMetric ? 1000.0 : 1609.344
        var annotations    : [DistanceMarkerAnnotation] = []
        var accumulated    : Double = 0
        var markerCount    : Int    = 0
        var lastCoord      : CLLocationCoordinate2D?

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

                if let last = lastCoord {
                    let a = CLLocation(latitude:  last.latitude,
                                       longitude: last.longitude)
                    let b = CLLocation(latitude:  coord.latitude,
                                       longitude: coord.longitude)
                    accumulated += a.distance(from: b)

                    while accumulated >= intervalMeters {
                        accumulated -= intervalMeters
                        markerCount += 1

                        let overshoot = accumulated
                        let segDist   = a.distance(from: b)
                        let fraction  = max(0, min(1,
                            (segDist - overshoot) / segDist))
                        let lat       = last.latitude
                            + (coord.latitude  - last.latitude)  * fraction
                        let lon       = last.longitude
                            + (coord.longitude - last.longitude) * fraction

                        let ann             = DistanceMarkerAnnotation()
                        ann.coordinate      = CLLocationCoordinate2D(
                            latitude: lat, longitude: lon)
                        ann.markerNumber    = markerCount
                        ann.useMetric       = useMetric
                        annotations.append(ann)
                    }
                }
                lastCoord = coord
            }
        }
        return annotations
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        let vm        : RouteBuilderViewModel
        var isEditing : Bool = true      // ← NEW: updated by updateUIView

        init(vm: RouteBuilderViewModel) { self.vm = vm }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            // ← NEW: bail immediately if not in editing mode
            guard isEditing else { return }

            guard let map = gesture.view as? MKMapView else { return }

            // Check if tap hit an amenity annotation view
            let point = gesture.location(in: map)
            for annotation in map.annotations {
                guard let ann = annotation as? AmenityAnnotation else { continue }
                if let annView = map.view(for: ann) {
                    if annView.frame.contains(point) { return }
                }
            }

            let coordinate = map.convert(point, toCoordinateFrom: map)
            Task { @MainActor in self.vm.handleTap(at: coordinate) }
        }

        func mapView(_ mapView: MKMapView,
                     rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let casing = overlay as? CasingPolyline {
                let r         = MKPolylineRenderer(polyline: casing)
                r.strokeColor = casing.layer.routeCasingColor
                r.lineWidth   = 8
                r.lineCap     = .round
                r.lineJoin    = .round
                return r
            }
            if let route = overlay as? RoutePolyline {
                let r         = MKPolylineRenderer(polyline: route)
                r.strokeColor = route.layer.routeColor
                r.lineWidth   = 5
                r.lineCap     = .round
                r.lineJoin    = .round
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView,
                     viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            // Amenity annotation
            if let amenity = annotation as? AmenityAnnotation {
                let id   = "amenity_\(amenity.amenityType.rawValue)"
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: id
                ) ?? MKAnnotationView(annotation: annotation,
                                      reuseIdentifier: id)
                view.annotation     = amenity
                view.canShowCallout = true
                view.image          = amenityImage(type: amenity.amenityType)
                view.centerOffset   = CGPoint(x: 0, y: -16)

                let btn = UIButton(type: .detailDisclosure)
                view.rightCalloutAccessoryView = btn
                return view
            }

            // Distance marker
            if let marker = annotation as? DistanceMarkerAnnotation {
                let id   = "distanceMarker"
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: id
                ) ?? MKAnnotationView(annotation: annotation,
                                      reuseIdentifier: id)
                view.annotation     = marker
                view.canShowCallout = false
                view.image          = markerImage(
                    number:    marker.markerNumber,
                    useMetric: marker.useMetric
                )
                view.centerOffset   = CGPoint(x: 0, y: -14)
                return view
            }

            // Waypoint pin
            if let wp = annotation as? WaypointAnnotation {
                let id   = "waypoint"
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: id
                ) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation,
                                          reuseIdentifier: id)
                view.annotation      = wp
                view.canShowCallout  = false
                view.displayPriority = .required
                if wp.title == "Start" {
                    view.markerTintColor = UIColor(Color(hex: "30D158"))
                    view.glyphImage      = UIImage(systemName: "figure.run")
                } else if wp.isLast && vm.waypoints.count > 1 {
                    view.markerTintColor = UIColor(Color(hex: "FF453A"))
                    view.glyphImage      = UIImage(systemName: "flag.checkered")
                } else {
                    view.alpha = 0
                }
                return view
            }

            return nil
        }

        // MARK: - Amenity Image

        private func amenityImage(type: AmenityType) -> UIImage {
            let size = CGSize(width: 32, height: 32)
            UIGraphicsBeginImageContextWithOptions(size, false, 0)
            defer { UIGraphicsEndImageContext() }

            let ctx = UIGraphicsGetCurrentContext()!

            ctx.setShadow(offset: CGSize(width: 0, height: 1),
                          blur: 3,
                          color: UIColor.black.withAlphaComponent(0.3).cgColor)
            ctx.setFillColor(type.color.cgColor)
            ctx.fillEllipse(in: CGRect(origin: .zero, size: size)
                .insetBy(dx: 1, dy: 1))

            ctx.setShadow(offset: .zero, blur: 0, color: nil)
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(1.5)
            ctx.strokeEllipse(in: CGRect(origin: .zero, size: size)
                .insetBy(dx: 2, dy: 2))

            let config = UIImage.SymbolConfiguration(
                pointSize: 13, weight: .bold)
            if let icon = UIImage(systemName: type.icon,
                                   withConfiguration: config)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                let iconSize = icon.size
                let iconRect = CGRect(
                    x: (size.width  - iconSize.width)  / 2,
                    y: (size.height - iconSize.height) / 2,
                    width:  iconSize.width,
                    height: iconSize.height
                )
                icon.draw(in: iconRect)
            }

            return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        }

        // MARK: - Distance Marker Image

        private func markerImage(number: Int, useMetric: Bool) -> UIImage {
            let unit  = useMetric ? "K" : ""
            let label = "\(number)\(unit)"
            let size  = CGSize(width: 28, height: 28)

            UIGraphicsBeginImageContextWithOptions(size, false, 0)
            defer { UIGraphicsEndImageContext() }

            let ctx = UIGraphicsGetCurrentContext()!

            ctx.setFillColor(UIColor.white.cgColor)
            ctx.setShadow(offset: CGSize(width: 0, height: 1),
                          blur: 3,
                          color: UIColor.black.withAlphaComponent(0.3).cgColor)
            ctx.fillEllipse(in: CGRect(origin: .zero, size: size)
                .insetBy(dx: 1, dy: 1))

            ctx.setShadow(offset: .zero, blur: 0, color: nil)
            ctx.setStrokeColor(
                UIColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 1.0).cgColor)
            ctx.setLineWidth(1.5)
            ctx.strokeEllipse(in: CGRect(origin: .zero, size: size)
                .insetBy(dx: 2, dy: 2))

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(
                    ofSize: label.count > 2 ? 9 : 11,
                    weight: .bold),
                .foregroundColor: UIColor(red: 0.04, green: 0.52,
                                           blue: 1.0, alpha: 1.0)
            ]
            let str     = NSString(string: label)
            let strSize = str.size(withAttributes: attrs)
            let strRect = CGRect(
                x: (size.width  - strSize.width)  / 2,
                y: (size.height - strSize.height) / 2,
                width:  strSize.width,
                height: strSize.height
            )
            str.draw(in: strRect, withAttributes: attrs)

            return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        }
    }
}

// MARK: - Custom Polyline Subclasses

class RoutePolyline: MKPolyline {
    var layer: MapLayer = .standard
}

class CasingPolyline: MKPolyline {
    var layer: MapLayer = .standard
}

// MARK: - Custom Annotations

class WaypointAnnotation: MKPointAnnotation {
    var index  : Int  = 0
    var isLast : Bool = false
}

class DistanceMarkerAnnotation: MKPointAnnotation {
    var markerNumber : Int  = 0
    var useMetric    : Bool = false
}
