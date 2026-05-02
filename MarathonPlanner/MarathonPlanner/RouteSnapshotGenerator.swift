import MapKit
import UIKit

// MARK: - Route Snapshot Generator

struct RouteSnapshotGenerator {

    static func generate(
        segments : [RouteSegment],
        size     : CGSize = CGSize(width: 600, height: 400),
        mapLayer : MapLayer = .standard
    ) async -> Data? {

        guard !segments.isEmpty else { return nil }

        // Collect all coordinates
        var allCoords: [CLLocationCoordinate2D] = []
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
            allCoords.append(contentsOf: coords.filter {
                CLLocationCoordinate2DIsValid($0)
            })
        }

        guard !allCoords.isEmpty else { return nil }

        let region  = boundingRegion(for: allCoords, padding: 1.3)
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size   = size
        options.scale  = UIScreen.main.scale

        // Apply map style — preferredConfiguration requires iOS 16+
        // mapType is the safe fallback for older targets
        if #available(iOS 16.0, *) {
            switch mapLayer {
            case .muted, .dark:
                let config           = MKStandardMapConfiguration()
                config.emphasisStyle = .muted
                options.preferredConfiguration = config
            case .satellite:
                options.preferredConfiguration = MKImageryMapConfiguration()
            case .hybrid:
                options.preferredConfiguration = MKHybridMapConfiguration()
            default:
                options.preferredConfiguration = MKStandardMapConfiguration()
            }
        } else {
            // Fallback for iOS 15 and earlier
            switch mapLayer {
            case .satellite:
                options.mapType = .satellite
            case .hybrid:
                options.mapType = .hybrid
            default:
                options.mapType = .standard
            }
        }

        do {
            let snapshotter = MKMapSnapshotter(options: options)
            let snapshot    = try await snapshotter.start()
            let image       = drawRoute(on: snapshot,
                                        segments: segments,
                                        size: size)
            return image?.pngData()
        } catch {
            return nil
        }
    }

    // MARK: - Draw Route on Snapshot

    private static func drawRoute(
        on snapshot : MKMapSnapshotter.Snapshot,
        segments    : [RouteSegment],
        size        : CGSize
    ) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, true, 0)
        defer { UIGraphicsEndImageContext() }

        snapshot.image.draw(at: .zero)

        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }

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

            let points = coords
                .filter { CLLocationCoordinate2DIsValid($0) }
                .map    { snapshot.point(for: $0) }

            guard points.count > 1 else { continue }

            // Casing — white outline
            ctx.setStrokeColor(
                UIColor.white.withAlphaComponent(0.9).cgColor)
            ctx.setLineWidth(6)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.move(to: points[0])
            for pt in points.dropFirst() { ctx.addLine(to: pt) }
            ctx.strokePath()

            // Main route line
            ctx.setStrokeColor(
                UIColor(red: 0.04, green: 0.52,
                        blue: 1.0,  alpha: 1.0).cgColor)
            ctx.setLineWidth(3.5)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.move(to: points[0])
            for pt in points.dropFirst() { ctx.addLine(to: pt) }
            ctx.strokePath()

            // Start dot — green
            if let first = points.first {
                ctx.setFillColor(
                    UIColor(red: 0.19, green: 0.82,
                            blue: 0.35, alpha: 1.0).cgColor)
                ctx.addArc(center: first, radius: 6,
                           startAngle: 0, endAngle: .pi * 2,
                           clockwise: false)
                ctx.fillPath()
            }

            // End dot — red
            if let last = points.last {
                ctx.setFillColor(
                    UIColor(red: 1.0,  green: 0.27,
                            blue: 0.23, alpha: 1.0).cgColor)
                ctx.addArc(center: last, radius: 6,
                           startAngle: 0, endAngle: .pi * 2,
                           clockwise: false)
                ctx.fillPath()
            }
        }

        return UIGraphicsGetImageFromCurrentImageContext()
    }

    // MARK: - Bounding Region

    private static func boundingRegion(
        for coords : [CLLocationCoordinate2D],
        padding    : Double = 1.25
    ) -> MKCoordinateRegion {
        var minLat =  90.0, maxLat = -90.0
        var minLon = 180.0, maxLon = -180.0

        for c in coords {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude)
            maxLon = max(maxLon, c.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude:  (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta:  (maxLat - minLat) * padding,
            longitudeDelta: (maxLon - minLon) * padding
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}
