import Foundation

// MARK: - ICS Calendar Exporter
// Produces a standard .ics file compatible with Apple Calendar and Google Calendar.

struct ICSExporter {

    static func exportPlan(_ plan: SavedPlan) -> URL {
        var lines: [String] = []

        // Calendar header
        lines.append("BEGIN:VCALENDAR")
        lines.append("VERSION:2.0")
        lines.append("PRODID:-//MarathonTrainer//TrainingPlan//EN")
        lines.append("CALSCALE:GREGORIAN")
        lines.append("METHOD:PUBLISH")
        lines.append("X-WR-CALNAME:\(plan.name)")
        lines.append("X-WR-TIMEZONE:UTC")

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay]

        let stampFormatter        = ISO8601DateFormatter()
        stampFormatter.formatOptions = [.withYear, .withMonth, .withDay,
                                        .withTime, .withColonSeparatorInTime]
        let stamp = stampFormatter.string(from: Date()).replacingOccurrences(of: "-", with: "")
                                                      .replacingOccurrences(of: ":", with: "")

        for week in plan.weeks {
            for day in week.days {
                guard day.workoutType != "Rest" else { continue }

                let dateStr = formatter.string(from: day.date)
                    .replacingOccurrences(of: "-", with: "")

                // Next day for DTEND (all-day event needs day+1)
                let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: day.date) ?? day.date
                let endStr  = formatter.string(from: nextDay)
                    .replacingOccurrences(of: "-", with: "")

                let uid     = UUID().uuidString
                let title   = eventTitle(day: day)
                let desc    = icsEscape(day.description + " | Pace: " + day.paceNote)
                let summary = icsEscape(title)

                lines.append("BEGIN:VEVENT")
                lines.append("UID:\(uid)@marathontrainer")
                lines.append("DTSTAMP:\(stamp)")
                lines.append("DTSTART;VALUE=DATE:\(dateStr)")
                lines.append("DTEND;VALUE=DATE:\(endStr)")
                lines.append("SUMMARY:\(summary)")
                lines.append("DESCRIPTION:\(desc)")
                lines.append("CATEGORIES:Training,Running,Marathon")

                // Color hint (not universally supported but helps in Apple Calendar)
                let colorLabel = calendarColor(for: day.workoutType)
                if !colorLabel.isEmpty {
                    lines.append("X-APPLE-CALENDAR-COLOR:\(colorLabel)")
                }

                lines.append("END:VEVENT")
            }
        }

        // Race day event
        let raceDateStr = formatter.string(from: plan.raceDate)
            .replacingOccurrences(of: "-", with: "")
        let raceNextDay = Calendar.current.date(byAdding: .day, value: 1, to: plan.raceDate) ?? plan.raceDate
        let raceEndStr  = formatter.string(from: raceNextDay)
            .replacingOccurrences(of: "-", with: "")

        lines.append("BEGIN:VEVENT")
        lines.append("UID:\(UUID().uuidString)@marathontrainer")
        lines.append("DTSTAMP:\(stamp)")
        lines.append("DTSTART;VALUE=DATE:\(raceDateStr)")
        lines.append("DTEND;VALUE=DATE:\(raceEndStr)")
        lines.append("SUMMARY:🏁 RACE DAY — \(plan.name)")
        lines.append("DESCRIPTION:Marathon Race Day. You are ready.")
        lines.append("CATEGORIES:Race,Running,Marathon")
        lines.append("END:VEVENT")

        lines.append("END:VCALENDAR")

        let content = lines.joined(separator: "\r\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(plan.name.replacingOccurrences(of: " ", with: "_"))_TrainingPlan.ics")

        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: Helpers

    static func eventTitle(day: SavedDay) -> String {
        if day.miles > 0 {
            return String(format: "%@ — %.1f mi", day.workoutType, day.miles)
        }
        return day.workoutType
    }

    // Escape special characters per RFC 5545
    static func icsEscape(_ str: String) -> String {
        str
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";",  with: "\\;")
            .replacingOccurrences(of: ",",  with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    static func calendarColor(for workoutType: String) -> String {
        switch workoutType {
        case "Easy Run", "Recovery Run", "Easy + Strides": return "#30D158"
        case "Long Run", "Medium-Long Run":                return "#0A84FF"
        case "Long Run w/ MP Finish":                      return "#5E5CE6"
        case "Tempo Run", "Strength (MP)", "Marathon Pace": return "#FF9F0A"
        case "Lactate Threshold", "Cruise Intervals",
             "Speed Work", "Interval Work", "Repetition Work": return "#FF453A"
        default: return ""
        }
    }
}
