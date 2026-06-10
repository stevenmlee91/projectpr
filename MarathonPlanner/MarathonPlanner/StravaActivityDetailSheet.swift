import SwiftUI

// MARK: - Strava Activity Detail Sheet
//
// Lightweight sheet presented when a runner taps a pace-verdict row.
// All data comes from the StravaActivity stored on SavedDay at log-time,
// so no live Strava connection is required.

struct StravaActivityDetailSheet: View {
    let activity : StravaActivity
    let verdict  : String?

    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    activityHeader
                    statsGrid
                    if let verdict { verdictCard(verdict) }
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    stravaBrand
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(Color(.secondaryLabel))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }

    // MARK: - Strava Brand (toolbar centre)

    private var stravaBrand: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color(hex: "FC4C02"))
                .frame(width: 7, height: 7)
            Text("STRAVA")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "FC4C02"))
                .kerning(2)
        }
    }

    // MARK: - Activity Header

    private var activityHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(activity.name)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.primary)

            HStack(spacing: 8) {
                Text(activity.startDate, style: .date)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                Text("·")
                    .foregroundColor(Color(.tertiaryLabel))

                Text(activityTypeLabel)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var activityTypeLabel: String {
        switch activity.type {
        case "TrailRun":   return "Trail Run"
        case "VirtualRun": return "Virtual Run"
        default:           return activity.type
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        let stats = buildStats()

        return LazyVGrid(
            columns: [
                GridItem(.flexible(), alignment: .leading),
                GridItem(.flexible(), alignment: .leading),
            ],
            alignment: .leading,
            spacing: 0
        ) {
            ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                StatCell(value: stat.value,
                         unit:  stat.unit,
                         label: stat.label)
                    // Horizontal divider between rows
                    .overlay(alignment: .bottom) {
                        if index / 2 < (stats.count - 1) / 2 {
                            Divider()
                                .padding(.trailing, index.isMultiple(of: 2) ? 0 : -16)
                        }
                    }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private func buildStats() -> [(value: String, unit: String, label: String)] {
        var result: [(value: String, unit: String, label: String)] = []

        // Distance
        result.append((
            String(format: "%.2f", activity.distanceMiles),
            "mi",
            "distance"
        ))

        // Moving time
        result.append((
            activity.formattedDuration,
            "",
            "moving time"
        ))

        // Pace
        if let pace = activity.pacePerMile {
            // Split "7:35/mi" into value "7:35" and unit "/mi"
            let parts = pace.components(separatedBy: "/")
            result.append((
                parts.first ?? pace,
                parts.count > 1 ? "/\(parts[1])" : "",
                "avg pace"
            ))
        }

        // Elevation gain
        if let gainMeters = activity.totalElevationGain {
            let feet = gainMeters * 3.28084
            result.append((
                String(format: "%.0f", feet),
                "ft",
                "elevation gain"
            ))
        }

        // Heart rate
        if let avgHR = activity.averageHeartrate {
            result.append((
                String(format: "%.0f", avgHR),
                "bpm",
                "avg heart rate"
            ))
        }
        if let maxHR = activity.maxHeartrate {
            result.append((
                String(format: "%.0f", maxHR),
                "bpm",
                "max heart rate"
            ))
        }

        return result
    }

    // MARK: - Verdict Card

    private func verdictCard(_ verdict: String) -> some View {
        let isGood = verdict.hasPrefix("✓")
        let color  = isGood
            ? Color(hex: "30D158")
            : Color(hex: "FF9F0A")

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: isGood
                  ? "checkmark.circle.fill"
                  : "info.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(color)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 6) {
                Text(verdict)
                    .font(.system(size: 14))
                    .foregroundColor(isGood ? .primary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)

                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(hex: "FC4C02"))
                        .frame(width: 5, height: 5)
                    Text("Pace analysis via Strava")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(color.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(14)
    }
}

// MARK: - Stat Cell

private struct StatCell: View {
    let value : String
    let unit  : String
    let label : String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 26, weight: .medium,
                                  design: .monospaced))
                    .foregroundColor(.primary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 13, weight: .regular,
                                      design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .padding(.horizontal, 4)
    }
}
