import MapKit

extension MapView {
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView

        init(_ parent: MapView) {
            self.parent = parent
        }

        @objc func handleTap(gesture: UITapGestureRecognizer) {
            let mapView = gesture.view as! MKMapView
            let location = gesture.location(in: mapView)
            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)

            if let last = parent.points.last {
                RouteService.fetchRoute(from: last, to: coordinate) { coords in
                    DispatchQueue.main.async {
                        self.parent.points.append(coordinate)
                        parent.routePoints.append(contentsOf: coords)
                    }
                }
            } else {
                parent.points.append(coordinate)
                parent.routePoints.append(coordinate)
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.lineWidth = 4
            return renderer
        }
    }
}
