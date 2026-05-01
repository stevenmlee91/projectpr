import SwiftUI
import Charts

// MARK: - Elevation Chart View

struct ElevationChartView: View {
    let profile: ElevationProfile

    // Convert km to miles for all points
    private var pointsInMiles: [(distanceMi: Double, altitudeFt: Double)] {
        profile.points.map {
            (distanceMi: $0.distanceKm * 0.621371,
             altitudeFt: $0.altitudeM * 3.28084)
        }
    }

    private var highestPointMiles: (distanceMi: Double, altitudeFt: Double)? {
        pointsInMiles.max { $0.altitudeFt < $1.altitudeFt }
    }

    private var yMinFt: Double {
        let lowest = pointsInMiles.map { $0.altitudeFt }.min() ?? 0
        return max(0, (floor((lowest - 50) / 50)) * 50)    }

    private var yMaxFt: Double {
        let highest = pointsInMiles.map { $0.altitudeFt }.max() ?? 0
        return ceil((highest + 50) / 50) * 50    }

    var body: some View {
        Chart {
            // Filled area
            ForEach(pointsInMiles.indices, id: \.self) { i in
                let point = pointsInMiles[i]

                AreaMark(
                    x: .value("Distance", point.distanceMi),
                    yStart: .value("Base", yMinFt),
                    yEnd:   .value("Elevation", point.altitudeFt)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(hex: "0A84FF").opacity(0.50),
                            Color(hex: "0A84FF").opacity(0.08)
                        ],
                        startPoint: .top,
                        endPoint:   .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                // Line on top of fill
                LineMark(
                    x: .value("Distance", point.distanceMi),
                    y: .value("Elevation", point.altitudeFt)
                )
                .foregroundStyle(Color(hex: "0A84FF"))
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }

            // Highest point marker
            if let peak = highestPointMiles {
                PointMark(
                    x: .value("Distance", peak.distanceMi),
                    y: .value("Elevation", peak.altitudeFt)
                )
                .foregroundStyle(Color(hex: "FF9F0A"))
                .symbolSize(55)
                .annotation(position: .top, spacing: 5) {
                    Text(String(format: "%.0f ft", peak.altitudeFt))
                        .font(.system(size: 9, weight: .semibold,
                                      design: .monospaced))
                        .foregroundColor(Color(hex: "FF9F0A"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Color(.systemBackground)
                                .opacity(0.88)
                                .cornerRadius(5)
                        )
                }
            }
        }
        .chartYScale(domain: yMinFt...yMaxFt)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(
                    stroke: StrokeStyle(lineWidth: 0.3)
                )
                .foregroundStyle(Color(.separator))
                AxisValueLabel {
                    if let mi = value.as(Double.self) {
                        Text(String(format: "%.1f mi", mi))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(
                    stroke: StrokeStyle(lineWidth: 0.3)
                )
                .foregroundStyle(Color(.separator))
                AxisValueLabel {
                    if let ft = value.as(Double.self) {
                        Text(String(format: "%.0f ft", ft))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(height: 160)
    }
}
