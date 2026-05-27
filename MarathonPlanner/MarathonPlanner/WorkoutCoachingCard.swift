import SwiftUI

// MARK: - Workout Coaching Card
//
// Collapsible coaching card that appears in the Today View workout card.
// Shows methodology-aware, phase-aware coaching for every key workout.
// Collapsed by default — runner taps to expand.

struct WorkoutCoachingCard: View {
    let content    : WorkoutCoachingContent
    let accentColor: Color

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: Header (always visible)
            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                    expanded.toggle()
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(accentColor)

                    Text("COACH'S NOTE")
                        .font(.system(size: 10, weight: .semibold,
                                      design: .monospaced))
                        .foregroundColor(accentColor)
                        .kerning(1.5)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(accentColor.opacity(0.5))
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .animation(.spring(response: 0.35,
                                           dampingFraction: 0.75),
                                   value: expanded)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // MARK: Expanded content
            if expanded {
                VStack(alignment: .leading, spacing: 14) {
                    Divider()
                        .padding(.horizontal, 14)

                    // Why this workout
                    coachingSection(
                        label:   "WHY THIS WORKOUT",
                        content: content.objective
                    )

                    // Focus
                    coachingSection(
                        label:   "FOCUS ON",
                        content: content.focus
                    )

                    // Phase context — only shown when present
                    if let ctx = content.context {
                        coachingSection(
                            label:   "THIS WEEK",
                            content: ctx
                        )
                    }
                }
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(accentColor.opacity(0.07))
        .cornerRadius(10)
        .animation(.spring(response: 0.38, dampingFraction: 0.78),
                   value: expanded)
    }

    private func coachingSection(label: String,
                                  content: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .eyebrow()
                .padding(.horizontal, 14)

            Text(content)
                .font(.appBody())
                .foregroundColor(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
        }
    }
}

// MARK: - Coaching Card Builder
// Convenience function that constructs coaching content from a SavedDay
// and the plan context. Handles WorkoutType string → enum conversion.

struct CoachingCardBuilder {

    static func card(
        for day     : SavedDay,
        plan        : SavedPlan,
        week        : SavedWeek,
        totalWeeks  : Int,
        accentColor : Color = Color(hex: "0A84FF")
    ) -> WorkoutCoachingCard? {

        guard
            let workoutType = WorkoutType(rawValue: day.workoutType),
            workoutType != .rest,
            workoutType != .raceDay
        else { return nil }

        guard let content = WorkoutCoachingEngine.content(
            workoutType: workoutType,
            planType:    plan.settings.planType,
            phase:       week.phase,
            weekNumber:  week.weekNumber,
            totalWeeks:  totalWeeks,
            raceType:    plan.settings.raceType
        ) else { return nil }

        return WorkoutCoachingCard(
            content:     content,
            accentColor: accentColor
        )
    }
}

// MARK: - Accent Color for Workout Type
// Matches the coaching card accent to the workout's existing color system.

extension WorkoutType {
    var coachingAccentColor: Color {
        switch self {
        case .longRun, .longRunWithMP, .mediumLong, .midweekLong:
            return Color(hex: "0A84FF")
        case .lactateThreshold, .cruiseIntervals, .speedWork,
             .intervalWork, .repetitionWork:
            return Color(hex: "FF453A")
        case .strengthMP, .marathonPace, .tempoRun:
            return Color(hex: "FF9F0A")
        case .easy, .recovery, .generalAerobic, .strides, .steadyRun:
            return Color(hex: "30D158")
        case .shakeout:
            return Color(hex: "30D158")
        default:
            return Color(hex: "0A84FF")
        }
    }
}
