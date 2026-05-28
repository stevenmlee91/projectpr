import WidgetKit
import SwiftUI

// MARK: - Small Widget View (2×2)
//
// States: normal training day, rest day, race week (≤6 days), race day, no plan.
// Visual anchor: the miles metric number — everything else defers to it.

struct TodaySmallWidgetView: View {
    let entry: WidgetEntry

    private var s: WidgetPlanSnapshot { entry.snapshot }

    private var phase: TrainingPhase {
        TrainingPhase(rawValue: s.phase) ?? .build
    }

    private var accent: Color { phase.accentColor }

    var body: some View {
        Group {
            if !s.hasPlan            { noPlanState   }
            else if s.isRaceDay      { raceDayState   }
            else if s.daysToRace <= 6 { raceWeekState }
            else if s.todayIsRest    { restState      }
            else                     { workoutState   }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
    }

    // MARK: - Training Day

    private var workoutState: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(s.todayDisplayName.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(accent)
                .kerning(1.5)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(milesText(s.todayMiles))
                    .font(.system(size: 38, weight: .thin, design: .monospaced))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.7)
                Text("mi")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Week \(s.weekNumber) · \(s.phaseLabel)")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    // MARK: - Rest Day

    private var restState: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("REST")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .kerning(1.5)

            Spacer()

            Text(s.insightMessage)
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Text("Week \(s.weekNumber) of \(s.totalWeeks)")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Race Week

    private var raceWeekState: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("RACE IN")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(hex: "FFD60A"))
                .kerning(1.5)

            Spacer()

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text("\(s.daysToRace)")
                    .font(.system(size: 44, weight: .thin, design: .monospaced))
                    .foregroundStyle(.primary)
                Text(s.daysToRace == 1 ? "day" : "days")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Trust the work.")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Race Day

    private var raceDayState: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Text("Race day\nis here.")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.primary)
                .lineSpacing(4)
            Spacer()
            Text(s.planName)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    // MARK: - No Plan

    private var noPlanState: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Text("Add a\ntraining plan.")
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
            Spacer()
        }
    }

    private func milesText(_ m: Double) -> String {
        m.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", m)
            : String(format: "%.1f", m)
    }
}

// MARK: - Widget Declaration

struct TodaySmallWidget: Widget {
    let kind = "TodaySmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind,
                            provider: MileZeroTimelineProvider()) { entry in
            TodaySmallWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
                .widgetURL(URL(string: "milezero://today"))
        }
        .configurationDisplayName("Today's Run")
        .description("Today's workout at a glance.")
        .supportedFamilies([.systemSmall])
    }
}
