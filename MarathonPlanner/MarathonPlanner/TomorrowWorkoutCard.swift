import SwiftUI

// MARK: - Tomorrow Workout Card

struct TomorrowWorkoutCard: View {
    let day       : SavedDay?
    let offSeason : SuggestedWorkout?   // fallback when no plan day exists

    init(day: SavedDay?, offSeason: SuggestedWorkout? = nil) {
        self.day       = day
        self.offSeason = offSeason
    }

    var body: some View {
        VStack(spacing: 0) {
            labelRow
            if let day = day {
                contentRow(day: day)
            } else if let os = offSeason {
                offSeasonContentRow(workout: os)
            } else {
                emptyRow
            }
        }
        .background(Color(.secondarySystemBackground).opacity(0.7))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
        )
        .cornerRadius(12)
    }

    // MARK: - Label Row

    private var labelRow: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "sunrise")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                Text("TOMORROW")
                    .font(.label())
                    .foregroundColor(.secondary)
                    .kerning(1.5)
                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)

            Divider()
                .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Plan Day Row

    private func contentRow(day: SavedDay) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Circle()
                .fill(workoutColor(day.workoutType))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(day.workoutType)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                if day.miles > 0 {
                    Text(String(format: "%.1f miles", day.miles))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                } else if day.workoutType == "Cross-Training" {
                    Text("45–60 minutes")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(!day.paceNote.isEmpty && day.paceNote != "—"
                 ? day.paceNote
                 : effortLabel(day.workoutType))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .frame(maxWidth: 110, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Off-Season Fallback Row

    private func offSeasonContentRow(workout: SuggestedWorkout) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Circle()
                .fill(offSeasonColor(workout.type))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(workout.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                if workout.distance != "—" {
                    Text(workout.distance)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(workout.intensityNote ?? workout.phaseLabel)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .frame(maxWidth: 110, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Empty Row

    private var emptyRow: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(.tertiaryLabel))
                .frame(width: 8, height: 8)
            Text("No active plan")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func effortLabel(_ workoutType: String) -> String {
        switch workoutType {
        case "Rest":               return "Recovery is part of training."
        case "Cross-Training":     return "Low impact aerobic"
        case "Recovery Run":       return "Slower than easy"
        case "Easy Run",
             "Easy + Strides",
             "Shakeout Run":       return "Conversational effort"
        case "Steady Run":         return "Comfortably steady"
        case "Long Run",
             "Long Run w/ MP Finish": return "Easy throughout"
        case "Race Day 🏁":        return "Everything you have. Run free."
        default:                   return "Structured effort"
        }
    }

    private func workoutColor(_ type: String) -> Color {
        switch type {
        case "Rest":               return Color(.tertiaryLabel)
        case "Recovery Run":       return Color(hex: "34C759")
        case "Easy Run",
             "Easy + Strides",
             "Shakeout Run",
             "Steady Run":         return Color(hex: "30D158")
        case "Long Run",
             "Long Run w/ MP Finish",
             "Medium-Long Run",
             "Midweek Longer Run": return Color(hex: "0A84FF")
        case "Tempo Run",
             "Strength (MP)",
             "Marathon Pace":      return Color(hex: "FF9F0A")
        case "Lactate Threshold",
             "Cruise Intervals",
             "Speed Work",
             "Interval Work",
             "Repetition Work":    return Color(hex: "FF453A")
        case "Cross-Training":     return Color(hex: "BF5AF2")
        case "Race Day 🏁":        return .yellow
        default:                   return Color(hex: "5E5E5E")
        }
    }

    private func offSeasonColor(_ type: OffSeasonRunType) -> Color {
        switch type {
        case .easy, .strides:  return Color(hex: "30D158")
        case .recovery:        return Color(hex: "34C759")
        case .tempo:           return Color(hex: "FF9F0A")
        case .longRun:         return Color(hex: "0A84FF")
        case .crossTrain:      return Color(hex: "BF5AF2")
        case .rest:            return Color(.tertiaryLabel)
        }
    }
}
