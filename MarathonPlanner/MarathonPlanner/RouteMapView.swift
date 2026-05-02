import SwiftUI
import MapKit

// MARK: - Route Map View

struct RouteMapView: UIViewRepresentable {

    @ObservedObject var vm  : RouteBuilderViewModel
    var mapLayer             : MapLayer
    var poiMode              : MapPOIMode
    var showsCompass         : Bool
    var showsScale           : Bool

    init(vm: RouteBuilderViewModel,
         mapLayer: MapLayer = .standard,
         poiMode: MapPOIMode = .runnerFocused,
         showsCompass: Bool = true,
         showsScale: Bool = true) {
        self.vm           = vm
        self.mapLayer     = mapLayer
        self.poiMode      = poiMode
        self.showsCompass = showsCompass
        self.showsScale   = showsScale
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

        // Only move camera when explicitly requested
        if vm.shouldMoveCamera {
            map.setRegion(vm.cameraRegion, animated: true)
            DispatchQueue.main.async {
                vm.shouldMoveCamera = false
            }
        }

        // Map style + POI
        applyMapLayer(map, layer: mapLayer)
        map.pointOfInterestFilter = poiMode.filter
        map.showsCompass          = showsCompass
        map.showsScale            = showsScale

        // Remove old overlays and annotations
        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations.filter {
            !($0 is MKUserLocation)
        })

        // Draw route with casing effect for contrast
        for segment in vm.segments {
            // Casing — wider line underneath
            let casing       = CasingPolyline(
                points: segment.polyline.points(),
                count:  segment.polyline.pointCount
            )
            casing.layer = mapLayer
            map.addOverlay(casing, level: .aboveRoads)

            // Main route line on top
            let route        = RoutePolyline(
                points: segment.polyline.points(),
                count:  segment.polyline.pointCount
            )
            route.layer = mapLayer
            map.addOverlay(route, level: .aboveRoads)
        }

        // Waypoint pins
        for (i, wp) in vm.waypoints.enumerated() {
            let pin          = WaypointAnnotation()
            pin.coordinate   = wp.coordinate
            pin.title        = i == 0
                ? "Start"
                : i == vm.waypoints.count - 1
                    ? "End"
                    : "Point \(i + 1)"
            pin.index        = i
            pin.isLast       = i == vm.waypoints.count - 1
            map.addAnnotation(pin)
        }
    }

    // MARK: Coordinator

    func makeCoordinator() -> Coordinator {
        Coordinator(vm: vm)
    }

    // MARK: - Apply Map Layer

    private func applyMapLayer(_ map: MKMapView, layer: MapLayer) {
        switch layer {
        case .standard:
            let config                   = MKStandardMapConfiguration()
            config.emphasisStyle         = .default
            config.pointOfInterestFilter = poiMode.filter
            map.preferredConfiguration   = config
            map.overrideUserInterfaceStyle = .unspecified

        case .muted:
            let config                   = MKStandardMapConfiguration()
            config.emphasisStyle         = .muted
            config.pointOfInterestFilter = poiMode.filter
            map.preferredConfiguration   = config
            map.overrideUserInterfaceStyle = .unspecified

        case .satellite:
            let config                 = MKImageryMapConfiguration()
            map.preferredConfiguration = config
            map.overrideUserInterfaceStyle = .unspecified

        case .hybrid:
            let config                   = MKHybridMapConfiguration()
            config.pointOfInterestFilter = poiMode.filter
            map.preferredConfiguration   = config
            map.overrideUserInterfaceStyle = .unspecified

        case .dark:
            let config                   = MKStandardMapConfiguration()
            config.emphasisStyle         = .muted
            config.pointOfInterestFilter = poiMode.filter
            map.preferredConfiguration   = config
            map.overrideUserInterfaceStyle = .dark
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        let vm: RouteBuilderViewModel

        init(vm: RouteBuilderViewModel) { self.vm = vm }

        // MARK: Tap

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let map = gesture.view as? MKMapView else { return }
            let point      = gesture.location(in: map)
            let coordinate = map.convert(point, toCoordinateFrom: map)
            Task { @MainActor in
                self.vm.handleTap(at: coordinate)
            }
        }

        // MARK: Overlay Renderer

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

        // MARK: Annotation View

        func mapView(_ mapView: MKMapView,
                     viewFor annotation: MKAnnotation) -> MKAnnotationView? {

            guard !(annotation is MKUserLocation) else { return nil }

            guard let wp = annotation as? WaypointAnnotation else {
                return nil
            }

            let id   = "waypoint"
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: id
            ) as? MKMarkerAnnotationView
            ?? MKMarkerAnnotationView(annotation: annotation,
                                      reuseIdentifier: id)

            view.annotation      = wp
            view.canShowCallout  = true
            view.displayPriority = .required

            if wp.title == "Start" {
                view.markerTintColor = UIColor(Color(hex: "30D158"))
                view.glyphImage      = UIImage(systemName: "figure.run")
            } else if wp.isLast && vm.waypoints.count > 1 {
                view.markerTintColor = UIColor(Color(hex: "FF453A"))
                view.glyphImage      = UIImage(
                    systemName: "flag.checkered")
            } else {
                view.markerTintColor = UIColor(Color(hex: "0A84FF"))
                view.glyphText       = "\(wp.index + 1)"
            }

            return view
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
