import SwiftUI
import MapKit

struct MapView: UIViewRepresentable {
    @Binding var points: [CLLocationCoordinate2D]
    @Binding var routePoints: [CLLocationCoordinate2D] // 👈 ADD THIS

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator

        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap)
        )

        map.addGestureRecognizer(tapGesture)
        return map
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)

        guard routePoints.count > 1 else { return }

        let polyline = MKPolyline(coordinates: routePoints, count: routePoints.count)
        mapView.addOverlay(polyline)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}
