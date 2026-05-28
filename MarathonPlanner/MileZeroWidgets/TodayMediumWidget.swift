import WidgetKit
import SwiftUI

// MARK: - Medium Widget View (4×2)
//
// Left column: today's workout (what to do)
// Right column: week progress (where you stand)
// Divided by a hairline separator.

struct TodayMediumWidgetView: View {
    let entry: WidgetEntry

    private var s: WidgetPlanSnapshot { entry.snapshot }

    private var phase: TrainingPhase {
        TrainingPhase(rawValue: s.phase) ?? .build
    }

    private var accent: Color { phase.accentColor }

    var body: some View {
        if !s.hasPlan {
            noPlanView
        } else {
            HStack(alignment: .top, spacing: 0) {
                todayColumn
                Rectangle()
                    .fill(Color(.separator).opacity(0.4))
                    .frame(width: 0.5)
                    .padding(.vertical, 14)
                weekColumn
            }
        }
    }

    // MARK: - Today Column

    private var todayColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(currentWeekday()) · WEEK \(s.weekNumber)")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .kerning(1.5)
                .lineLimit(1)

            Spacer()

            if s.isRaceDay {
                Text("Race day\nis here.")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(.primary)
                    .lineSpacing(3)
            } else if s.todayIsRest {
                Text("Rest Today")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(s.insightMessage)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 3)
            } else {
                Text(s.todayDisplayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(milesText(s.todayMiles))
                        .font(.system(size: 28, weight: .thin, design: .monospaced))
                        .foregroundStyle(.primary)
                    Text("mi")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }

            Spacer()

            // Footer: pace note on training days, countdown in race week
            if !s.todayIsRest && !s.isRaceDay && !s.todayPaceNote.isEmpty {
                Text(s.todayPaceNote)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else if s.daysToRace > 0 && s.daysToRace <= 14 && !s.isRaceDay {
                Text("\(s.daysToRace) days to race")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: - Week Column

    private var weekColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("THIS WEEK")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .kerning(1.5)

            Spacer()

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(s.weekWorkoutsCompleted)")
                    .font(.system(size: 26, weight: .thin, design: .monospaced))
                    .foregroundStyle(.primary)
                Text("/ \(s.weekWorkoutsTotal)")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Text("runs done")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.tertiary)
                .padding(.top, 1)

            Spacer()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemFill))
                        .frame(height: 3)
                    Capsule()
                        .fill(accent)
                        .frame(width: geo.size.width * weekFraction, height: 3)
                }
            }
            .frame(height: 3)

            Text("\(milesText(s.weekMilesPlanned)) mi planned")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: - No Plan

    private var noPlanView: some View {
        VStack(alignment: .leading) {
            Spacer()
            Text("Add a training plan to get started.")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
    }

    private var weekFraction: Double {
        guard s.weekWorkoutsTotal > 0 else { return 0 }
        return min(1.0, Double(s.weekWorkoutsCompleted) / Double(s.weekWorkoutsTotal))
    }

    private func milesText(_ m: Double) -> String {
        m.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", m)
            : String(format: "%.1f", m)
    }

    private func currentWeekday() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: Date()).uppercased()
    }
}

// MARK: - Widget Declaration

struct TodayMediumWidget: Widget {
    let kind = "TodayMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind,
                            provider: MileZeroTimelineProvider()) { entry in
            TodayMediumWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
                .widgetURL(URL(string: "milezero://today"))
        }
        .configurationDisplayName("Today + Week")
        .description("Today's workout and weekly progress.")
        .supportedFamilies([.systemMedium])
    }
}
