import WidgetKit
import SwiftUI

// MARK: - Lock Screen Rectangular (below clock)
// Two lines: workout type + miles on line 1, week context on line 2.

private struct LockRectangularView: View {
    let s: WidgetPlanSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !s.hasPlan {
                Text("MILE ZERO")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .kerning(1)
                Text("Add a training plan")
                    .font(.system(size: 11, weight: .regular))
            } else if s.isRaceDay {
                Text("RACE DAY")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .kerning(1)
                Text("Everything you trained for.")
                    .font(.system(size: 11, weight: .regular))
            } else if s.daysToRace <= 6 {
                Text("RACE IN \(s.daysToRace) \(s.daysToRace == 1 ? "DAY" : "DAYS")")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .kerning(1)
                Text("Protect your legs. Trust the work.")
                    .font(.system(size: 11, weight: .regular))
                    .lineLimit(1)
            } else if s.todayIsRest {
                Text("REST DAY · WEEK \(s.weekNumber) OF \(s.totalWeeks)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .kerning(1)
                Text(s.insightMessage)
                    .font(.system(size: 11, weight: .regular))
                    .lineLimit(1)
            } else {
                Text("\(s.todayDisplayName.uppercased()) · \(milesText) MI")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .kerning(1)
                    .lineLimit(1)
                Text("Week \(s.weekNumber) of \(s.totalWeeks) · \(s.phaseLabel)")
                    .font(.system(size: 11, weight: .regular))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var milesText: String {
        let m = s.todayMiles
        return m.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", m)
            : String(format: "%.1f", m)
    }
}

// MARK: - Lock Screen Circular (corner slot)
// Shows miles on training days, days-to-race in race week, icons for rest/race.

private struct LockCircularView: View {
    let s: WidgetPlanSnapshot

    var body: some View {
        if s.isRaceDay {
            Image(systemName: "flag.checkered")
                .font(.system(size: 16, weight: .light))
        } else if !s.hasPlan || s.todayIsRest {
            Image(systemName: "bed.double")
                .font(.system(size: 14, weight: .light))
        } else if s.daysToRace <= 6 {
            VStack(spacing: 0) {
                Text("\(s.daysToRace)")
                    .font(.system(size: 16, weight: .thin, design: .monospaced))
                Text("days")
                    .font(.system(size: 8, weight: .regular))
            }
        } else {
            let m = s.todayMiles
            let txt = m.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", m)
                : String(format: "%.1f", m)
            VStack(spacing: 0) {
                Text(txt)
                    .font(.system(size: 16, weight: .thin, design: .monospaced))
                Text("mi")
                    .font(.system(size: 8, weight: .regular))
            }
        }
    }
}

// MARK: - Lock Screen Inline (above clock)
// Single line: workout type and miles, or rest/race day context.

private struct LockInlineView: View {
    let s: WidgetPlanSnapshot

    var body: some View {
        Group {
            if !s.hasPlan {
                Text("Add a training plan")
            } else if s.isRaceDay {
                Label("Race day", systemImage: "flag.checkered")
            } else if s.todayIsRest {
                Label("Rest · Wk \(s.weekNumber) of \(s.totalWeeks)",
                      systemImage: "bed.double")
            } else {
                let m = s.todayMiles
                let txt = m.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", m)
                    : String(format: "%.1f", m)
                Label("\(s.todayDisplayName) · \(txt) mi",
                      systemImage: "figure.run")
            }
        }
    }
}

// MARK: - Combined View (switches on widget family)

struct LockScreenWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: WidgetEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            LockRectangularView(s: entry.snapshot)
        case .accessoryCircular:
            LockCircularView(s: entry.snapshot)
        case .accessoryInline:
            LockInlineView(s: entry.snapshot)
        default:
            EmptyView()
        }
    }
}

// MARK: - Widget Declaration

struct LockScreenWidget: Widget {
    let kind = "LockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind,
                            provider: MileZeroTimelineProvider()) { entry in
            LockScreenWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
                .widgetURL(URL(string: "milezero://today"))
        }
        .configurationDisplayName("Today's Run")
        .description("Today's workout on your lock screen.")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline
        ])
    }
}
