import SwiftUI

// MARK: - Weekly Summary View

struct WeeklySummaryView: View {
    let plan: SavedPlan
    @Environment(\.dismiss) var dismiss

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()

    // MARK: - Derived Data

    private var currentWeek: SavedWeek? {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        return plan.weeks.first { week in
            week.days.contains {
                cal.isDate($0.date, inSameDayAs: today)
            }
        }
    }

    private var nextWeek: SavedWeek? {
        guard let cw = currentWeek else { return nil }
        return plan.weeks.first { $0.weekNumber == cw.weekNumber + 1 }
    }

    private var longRunCompleted: Bool {
        currentWeek?.days.contains {
            let isLong = $0.workoutType == "Long Run"
                || $0.workoutType == "Long Run w/ MP Finish"
            let isDone = $0.completionStatus == .completed
                || $0.completionStatus == .modified
            return isLong && isDone
        } ?? false
    }

    private var nextLongRunMiles: Double {
        nextWeek?.days
            .filter {
                $0.workoutType == "Long Run"
                    || $0.workoutType == "Long Run w/ MP Finish"
            }
            .map { $0.miles }
            .max() ?? 0
    }

    private var motivationLine: String {
        guard let cw = currentWeek else {
            return "Keep building."
        }
        let pct = cw.completionPercentage
        switch pct {
        case 1.0:
            return "Perfect week. Every session banked."
        case 0.8...:
            return "Strong week. Consistency compounds."
        case 0.6...:
            return "Solid effort. Keep the rhythm going."
        case 0.4...:
            return "Partial week. Next week is a fresh start."
        default:
            return "Show up next week. That is all that matters."
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection

                        if let cw = currentWeek {
                            // This week stats
                            thisWeekSection(cw)

                            // Next week preview
                            if let nw = nextWeek {
                                nextWeekSection(nw)
                            } else {
                                raceWeekSection
                            }
                        }

                        // Motivation
                        motivationSection

                        Spacer().frame(height: 32)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("WEEKLY SUMMARY")
                        .font(.system(size: 11, weight: .semibold,
                                      design: .monospaced))
                        .foregroundColor(.secondary)
                        .kerning(3)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(weekRangeLabel)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .kerning(2)
            Text(plan.name)
                .font(.system(size: 26, weight: .light, design: .serif))
                .foregroundColor(.primary)
            if let cw = currentWeek {
                Text("Week \(cw.weekNumber) of \(plan.weeks.count)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weekRangeLabel: String {
        guard let cw = currentWeek else { return "THIS WEEK" }
        let sorted = cw.days.sorted { $0.date < $1.date }
        guard let first = sorted.first?.date,
              let last  = sorted.last?.date else { return "THIS WEEK" }
        return "\(dateFormatter.string(from: first).uppercased()) — "
            + dateFormatter.string(from: last).uppercased()
    }

    // MARK: - This Week

    private func thisWeekSection(_ week: SavedWeek) -> some View {
        VStack(spacing: 12) {

            // Hero miles
            VStack(spacing: 4) {
                Text(String(format: "%.0f", week.actualTotalMiles))
                    .font(.system(size: 72, weight: .thin,
                                  design: .monospaced))
                    .foregroundColor(.primary)
                Text("miles completed")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                    .kerning(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)

            // Stats row
            HStack(spacing: 8) {
                statCell(
                    value: "\(Int(week.completionPercentage * 100))%",
                    label: "COMPLETE"
                )
                statCell(
                    value: "\(week.completedDayCount)/\(week.trackableDayCount)",
                    label: "WORKOUTS"
                )
                statCell(
                    value: longRunCompleted ? "✓" : "✗",
                    label: "LONG RUN",
                    valueColor: longRunCompleted
                        ? Color(hex: "30D158")
                        : Color(hex: "FF453A")
                )
            }

            // Day dots
            dayDotsRow(week)
        }
    }

    private func statCell(value: String, label: String,
                           valueColor: Color = .primary) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .thin,
                              design: .monospaced))
                .foregroundColor(valueColor)
            Text(label)
                .font(.system(size: 9, weight: .semibold,
                              design: .monospaced))
                .foregroundColor(.secondary)
                .kerning(1.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func dayDotsRow(_ week: SavedWeek) -> some View {
        let order = ["Monday","Tuesday","Wednesday",
                     "Thursday","Friday","Saturday","Sunday"]
        let sorted = week.days.sorted {
            let i0 = order.firstIndex(of: $0.weekday) ?? 7
            let i1 = order.firstIndex(of: $1.weekday) ?? 7
            return i0 < i1
        }

        return HStack(spacing: 6) {
            ForEach(sorted) { day in
                VStack(spacing: 5) {
                    Circle()
                        .fill(dotColor(day))
                        .frame(width: 30, height: 30)
                        .overlay(dotIcon(day))
                    Text(String(day.weekday.prefix(1)))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func dotColor(_ day: SavedDay) -> Color {
        switch day.completionStatus {
        case .completed:  return Color(hex: "30D158")
        case .skipped:    return Color(hex: "FF453A")
        case .modified:   return Color(hex: "0A84FF")
        case .notStarted:
            return day.workoutType == "Rest"
                ? Color(.tertiarySystemFill)
                : Color(.systemFill)
        }
    }

    @ViewBuilder
    private func dotIcon(_ day: SavedDay) -> some View {
        switch day.completionStatus {
        case .completed:
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.black)
        case .skipped:
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        case .modified:
            Image(systemName: "pencil")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.black)
        case .notStarted:
            EmptyView()
        }
    }

    // MARK: - Next Week

    private func nextWeekSection(_ week: SavedWeek) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NEXT WEEK")
                .font(.system(size: 10, weight: .semibold,
                              design: .monospaced))
                .foregroundColor(.secondary)
                .kerning(2)

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.0f", week.totalMiles))
                            .font(.system(size: 36, weight: .thin,
                                          design: .monospaced))
                            .foregroundColor(.primary)
                        Text("mi planned")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                    }
                    Text(week.phaseLabel)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if nextLongRunMiles > 0 {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(format: "%.0f mi", nextLongRunMiles))
                            .font(.system(size: 20, weight: .thin,
                                          design: .monospaced))
                            .foregroundColor(Color(hex: "0A84FF"))
                        Text("long run")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)
        }
    }

    // MARK: - Race Week

    private var raceWeekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NEXT WEEK")
                .font(.system(size: 10, weight: .semibold,
                              design: .monospaced))
                .foregroundColor(.secondary)
                .kerning(2)

            HStack(spacing: 12) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(.yellow)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Race Week")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("Protect your legs. Trust your training.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(Color.yellow.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
            )
            .cornerRadius(14)
        }
    }

    // MARK: - Motivation

    private var motivationSection: some View {
        Text(motivationLine)
            .font(.system(size: 14, weight: .light, design: .serif))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }
}
