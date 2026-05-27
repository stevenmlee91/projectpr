import SwiftUI

// MARK: - Off-Season Card

struct OffSeasonCard: View {
    let workout : SuggestedWorkout
    let goal    : OffSeasonWeeklyGoal
    let store   : OffSeasonStore

    @State private var showGuidance = false
    @State private var showMiles    = false
    @State private var milesInput   = ""

    private var daysCompleted  : Int    { store.daysCompletedThisWeek() }
    private var milesCompleted : Double { store.milesThisWeek() }
    private var daysPct        : Double {
        min(1.0, Double(daysCompleted) / Double(max(1, goal.daysTarget)))
    }
    private var milesPct       : Double {
        min(1.0, milesCompleted / max(1, goal.milesTarget))
    }
    private var overallPct     : Double { (daysPct + milesPct) / 2.0 }
    private var isToday        : Bool   { store.todayIsCompleted }

    var body: some View {
        VStack(spacing: 0) {
            // Type bar — compact
            typeBar

            VStack(alignment: .leading, spacing: 12) {

                // 1. Workout — primary answer to "what today?"
                workoutHeader

                // 2. Upcoming plan + countdown (if exists)
                if let countdown = workout.countdownText {
                    countdownRow(countdown)
                }

                // 3. Reasoning — one line, subtle
                reasoningRow

                // 4. Guidance — hidden behind toggle
                if showGuidance {
                    guidanceText
                        .transition(.move(edge: .top)
                            .combined(with: .opacity))
                }

                // 5. Add-on (optional)
                if let addOn = workout.optionalAddOn {
                    addOnRow(addOn)
                }

                Divider()
                    .opacity(0.5)

                // 6. Weekly goal progress
                weeklyGoalSection

                // 7. Log button
                if workout.type != .rest {
                    completeTodayButton
                }

                if showMiles {
                    milesInputRow
                        .transition(.move(edge: .top)
                            .combined(with: .opacity))
                }

                // 8. Coach's note toggle
                coachToggle
            }
            .padding(Spacing.lg)
        }
        .background(Color(.secondarySystemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 1)
        )
        .cornerRadius(16)
        .animation(.spring(response: 0.35, dampingFraction: 0.75),
                   value: showGuidance)
        .animation(.spring(response: 0.35, dampingFraction: 0.75),
                   value: showMiles)
        .animation(.spring(response: 0.35, dampingFraction: 0.75),
                   value: isToday)
    }

    // MARK: - Type Bar

    private var typeBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 7, height: 7)
                Text(workout.type.rawValue.uppercased())
                    .font(.label())
                    .foregroundColor(accentColor)
                    .kerning(1.5)
                Spacer()
                Text(workout.phaseLabel.uppercased())
                    .font(.label())
                    .foregroundColor(.secondary)
                    .kerning(1.5)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 13)

            Divider()
                .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Workout Header

    private var workoutHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: workout.type.icon)
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundColor(accentColor)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                if workout.type == .rest {
                    Text(workout.title)
                        .font(.displayTitle(20))
                        .foregroundColor(.primary)
                } else {
                    Text(workout.distance)
                        .font(.metric(22))
                        .foregroundColor(.primary)
                    Text(workout.title)
                        .font(.caption())
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Intensity badge
            if let intensity = workout.intensityNote,
               workout.type != .rest {
                Text(intensity)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.1))
                    .cornerRadius(6)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 90, alignment: .trailing)
            }
        }
    }

    // MARK: - Countdown Row

    private func countdownRow(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 9))
                .foregroundColor(accentColor)
            Text(text)
                .font(.system(size: 11, weight: .medium,
                              design: .monospaced))
                .foregroundColor(accentColor)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(accentColor.opacity(0.07))
        .cornerRadius(8)
    }

    // MARK: - Reasoning Row

    private var reasoningRow: some View {
        Text(workout.reasoning)
            .font(.appBody(12))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(3)
    }

    // MARK: - Guidance Text

    private var guidanceText: some View {
        Text(workout.guidance)
            .font(.appBody(12))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(4)
            .padding(Spacing.md)
            .background(accentColor.opacity(0.05))
            .cornerRadius(Radius.sm)
    }

    // MARK: - Add-On Row

    private func addOnRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "plus.circle")
                .font(.system(size: 10))
                .foregroundColor(accentColor.opacity(0.6))
                .padding(.top, 1)
            Text(text)
                .font(.appBody(12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Weekly Goal Section

    private var weeklyGoalSection: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack {
                Text("THIS WEEK")
                    .font(.system(size: 9, weight: .semibold,
                                  design: .monospaced))
                    .foregroundColor(.secondary)
                    .kerning(1.5)
                Spacer()
                if overallPct >= 1.0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "30D158"))
                        Text("Goal complete")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(hex: "30D158"))
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Text("\(Int(overallPct * 100))%")
                        .font(.system(size: 10, weight: .semibold,
                                      design: .monospaced))
                        .foregroundColor(.secondary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4,
                                            dampingFraction: 0.8),
                                   value: overallPct)
                }
            }

            // Days + Miles in one compact row
            HStack(spacing: 12) {
                // Days
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("Days")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(daysCompleted)/\(goal.daysTarget)")
                            .font(.system(size: 9, weight: .medium,
                                          design: .monospaced))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                    }
                    thinBar(pct: daysPct,
                            color: Color(hex: "30D158"))
                }

                // Miles
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("Miles")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.0f/%.0f",
                                    milesCompleted, goal.milesTarget))
                            .font(.system(size: 9, weight: .medium,
                                          design: .monospaced))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                    }
                    thinBar(pct: milesPct,
                            color: Color(hex: "0A84FF"))
                }
            }

            Text(goal.subLabel)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    private func thinBar(pct: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(.systemFill))
                    .frame(height: 4)
                RoundedRectangle(cornerRadius: 2)
                    .fill(pct >= 1.0 ? Color(hex: "30D158") : color)
                    .frame(width: geo.size.width * pct, height: 4)
                    .animation(.spring(response: 0.5,
                                        dampingFraction: 0.75),
                               value: pct)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Complete Today Button

    private var completeTodayButton: some View {
        Button {
            if isToday {
                store.unmarkToday()
                milesInput = ""
                showMiles  = false
            } else {
                withAnimation { showMiles = true }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: isToday
                      ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .symbolEffect(.bounce, value: isToday)
                Text(isToday ? "Logged" : "Log today's run")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(isToday ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                isToday ? Color(hex: "30D158") : Color(.systemFill)
            )
            .cornerRadius(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.65),
                   value: isToday)
    }

    // MARK: - Miles Input Row

    private var milesInputRow: some View {
        HStack(spacing: 10) {
            Text("Miles:")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            TextField("0.0", text: $milesInput)
                .keyboardType(.decimalPad)
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 52)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(Color(.systemBackground))
                .cornerRadius(6)
            Button("Save") {
                store.markToday(miles: Double(milesInput) ?? 0)
                milesInput = ""
                withAnimation { showMiles = false }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Color(hex: "30D158"))
            .buttonStyle(.plain)
            Spacer()
            Button("Skip") {
                store.markToday(miles: 0)
                milesInput = ""
                withAnimation { showMiles = false }
            }
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }

    // MARK: - Coach Toggle

    private var coachToggle: some View {
        Button {
            withAnimation(.spring(response: 0.35,
                                   dampingFraction: 0.75)) {
                showGuidance.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: showGuidance
                      ? "chevron.up" : "info.circle")
                    .font(.system(size: 10))
                Text(showGuidance ? "Less" : "Coach's note")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Color

    private var accentColor: Color {
        switch workout.type {
        case .easy, .strides:  return Color(hex: "30D158")
        case .recovery:        return Color(hex: "34C759")
        case .tempo:           return Color(hex: "FF9F0A")
        case .longRun:         return Color(hex: "0A84FF")
        case .crossTrain:      return Color(hex: "BF5AF2")
        case .rest:            return Color(hex: "3A3A3A")
        }
    }
}
