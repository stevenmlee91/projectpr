import SwiftUI
import CoreLocation

struct ContentView: View {
    @State private var points: [CLLocationCoordinate2D] = []
    @State private var drawnPoints: [CLLocationCoordinate2D] = []   // taps
    @State private var routePoints: [CLLocationCoordinate2D] = []   // snapped path

    var distance: Double {
        DistanceCalculator.totalMiles(from: routePoints)
    }

    var body: some View {
        ZStack {
            MapView(points: $points, routePoints: $routePoints)
                .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 12) {
                    Text(String(format: "%.2f miles", distance))
                        .font(.title)
                        .bold()

                    HStack {
                        Button("Undo") {
                            if !points.isEmpty {
                                points.removeLast()
                            }
                        }

                        Button("Clear") {
                            points.removeAll()
                        }

                        Button("Export GPX") {
                            let gpx = GPXExporter.generate(from: points)
                            FileShareHelper.shareGPX(gpx)
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            }
            .padding()
        }
    }
}
