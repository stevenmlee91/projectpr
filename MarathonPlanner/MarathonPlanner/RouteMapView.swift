import SwiftUI
import MapKit

struct RouteMapView: UIViewRepresentable {

    @ObservedObject var vm: RouteBuilderViewModel

    // MARK: Make

    func makeUIView(context: Context) -> MKMapView {
        let map                = MKMapView()
        map.delegate           = context.coordinator
        map.showsUserLocation  = true
        map.showsCompass       = true
        map.showsScale         = true
        map.isRotateEnabled    = false
        map.setRegion(vm.cameraRegion, animated: false)

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        map.addGestureRecognizer(tap)
        return map
    }

    // MARK: Update

    func updateUIView(_ map: MKMapView, context: Context) {

        // Only move the camera when explicitly requested.
        // This prevents the map jumping back when the user pans.
        if vm.shouldMoveCamera {
            map.setRegion(vm.cameraRegion, animated: true)
            DispatchQueue.main.async {
                vm.shouldMoveCamera = false
            }
        }

        // Remove old overlays and annotations
        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations.filter {
            !($0 is MKUserLocation)
        })

        // Add polylines
        for segment in vm.segments {
            map.addOverlay(segment.polyline, level: .aboveRoads)
        }

        // Add waypoint pins
        for (i, wp) in vm.waypoints.enumerated() {
            let pin        = MKPointAnnotation()
            pin.coordinate = wp.coordinate
            pin.title      = i == 0
                ? "Start"
                : i == vm.waypoints.count - 1
                    ? "End"
                    : "Point \(i + 1)"
            map.addAnnotation(pin)
        }
    }

    // MARK: Coordinator

    func makeCoordinator() -> Coordinator {
        Coordinator(vm: vm)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        let vm: RouteBuilderViewModel

        init(vm: RouteBuilderViewModel) { self.vm = vm }

        // MARK: Tap handler

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let map = gesture.view as? MKMapView else { return }
            let point      = gesture.location(in: map)
            let coordinate = map.convert(point, toCoordinateFrom: map)
            Task { @MainActor in
                self.vm.handleTap(at: coordinate)
            }
        }

        // MARK: Polyline renderer

        func mapView(_ mapView: MKMapView,
                     rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let r         = MKPolylineRenderer(polyline: polyline)
            r.strokeColor = UIColor(Color(hex: "0A84FF"))
            r.lineWidth   = 4
            r.lineCap     = .round
            r.lineJoin    = .round
            return r
        }

        // MARK: Annotation view

        func mapView(_ mapView: MKMapView,
                     viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            let id   = "waypoint"
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: id
            ) as? MKMarkerAnnotationView
            ?? MKMarkerAnnotationView(annotation: annotation,
                                      reuseIdentifier: id)

            view.annotation     = annotation
            view.canShowCallout = true

            if annotation.title == "Start" {
                view.markerTintColor = UIColor(Color(hex: "30D158"))
                view.glyphImage      = UIImage(systemName: "figure.run")
            } else if annotation.title == "End" {
                view.markerTintColor = UIColor(Color(hex: "FF453A"))
                view.glyphImage      = UIImage(systemName: "flag.checkered")
            } else {
                view.markerTintColor = UIColor(Color(hex: "0A84FF"))
                view.glyphImage      = nil
            }
            return view
        }
    }
}
