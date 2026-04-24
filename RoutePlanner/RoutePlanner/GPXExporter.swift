import CoreLocation

struct GPXExporter {
    static func generate(from points: [CLLocationCoordinate2D]) -> String {
        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="RoutePlanner">
        <trk><name>Route</name><trkseg>
        """

        for point in points {
            gpx += """
            <trkpt lat="\(point.latitude)" lon="\(point.longitude)"></trkpt>
            """
        }

        gpx += """
        </trkseg></trk></gpx>
        """

        return gpx
    }
}
