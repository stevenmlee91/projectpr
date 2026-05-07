import SwiftUI

// MARK: - Off-Season Card

struct OffSeasonCard: View {
    let workout: SuggestedWorkout

    @State private var showGuidance  = false
    @State private var showReasoning = false

    var body: some View {
        VStack(spacing: 0) {
            typeBar
            VStack(alignment: .leading, spacing: 16) {
                distanceRow
                descriptionText

                if let addOn = workout.optionalAddOn {
                    addOnRow(addOn)
                }

                if let intensity = workout.intensityNote {
                    intensityRow(intensity)
                }

                // Reasoning — always visible, subtle
                reasoningRow

                if showGuidance {
                    guidanceText
                        .transition(.move(edge: .top)
                            .combined(with: .opacity))
                }

                bottomRow
            }
            .padding(20)
        }
        .background(Color(.secondarySystemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 1.5)
        )
        .cornerRadius(16)
        .animation(.spring(response: 0.35,
                            dampingFraction: 0.75),
                   value: showGuidance)
    }

    // MARK: - Type Bar

    private var typeBar: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(accentColor)
                .frame(width: 8, height: 8)
            Text(workout.type.rawValue.uppercased())
                .font(.system(size: 10, weight: .bold,
                              design: .monospaced))
                .foregroundColor(accentColor)
                .kerning(2)
            Spacer()
            Text(workout.phaseLabel.uppercased())
                .font(.system(size: 9, weight: .semibold,
                              design: .monospaced))
                .foregroundColor(.secondary)
                .kerning(1.5)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.tertiarySystemBackground))
    }

    // MARK: - Distance Row

    private var distanceRow: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if workout.type == .rest {
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: workout.type.icon)
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundColor(accentColor)
                    Text(workout.title)
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(.primary)
                }
            } else if workout.type == .crossTrain {
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: workout.type.icon)
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundColor(accentColor)
                    Text(workout.distance)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.distance)
                        .font(.system(size: 38, weight: .thin,
                                      design: .monospaced))
                        .foregroundColor(.primary)
                    Text("suggested")
                        .font(.system(size: 12,
                                      design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Image(systemName: workout.type.icon)
                .font(.system(size: 22, weight: .ultraLight))
                .foregroundColor(accentColor.opacity(0.4))
        }
    }

    // MARK: - Description

    private var descriptionText: some View {
        Text(workout.description)
            .font(.system(size: 13))
            .foregroundColor(Color(hex: "7A7A7A"))
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(3)
    }

    // MARK: - Add-On Row

    private func addOnRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "plus.circle")
                .font(.system(size: 11))
                .foregroundColor(accentColor.opacity(0.7))
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 12, weight: .light))
                .foregroundColor(Color(hex: "6A6A6A"))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(accentColor.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(accentColor.opacity(0.15), lineWidth: 1)
        )
        .cornerRadius(9)
    }

    // MARK: - Intensity Row

    private func intensityRow(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "speedometer")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(text)
                .font(.system(size: 11, weight: .medium,
                              design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Reasoning Row (always shown, subtle)

    private var reasoningRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb")
                .font(.system(size: 10))
                .foregroundColor(accentColor.opacity(0.6))
                .padding(.top, 1)
            Text(workout.reasoning)
                .font(.system(size: 11, weight: .light))
                .foregroundColor(Color(hex: "6A6A6A"))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        }
    }

    // MARK: - Guidance Text

    private var guidanceText: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "quote.opening")
                .font(.system(size: 10))
                .foregroundColor(accentColor)
                .padding(.top, 2)
            Text(workout.guidance)
                .font(.system(size: 12, weight: .light))
                .foregroundColor(Color(hex: "6A6A6A"))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(accentColor.opacity(0.06))
        .cornerRadius(10)
    }

    // MARK: - Bottom Row (countdown + toggle)

    private var bottomRow: some View {
        HStack(alignment: .center, spacing: 0) {

            // Countdown pill
            if let countdown = workout.countdownText {
                HStack(spacing: 5) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 9))
                        .foregroundColor(accentColor)
                    Text(countdown)
                        .font(.system(size: 10, weight: .medium,
                                      design: .monospaced))
                        .foregroundColor(accentColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(accentColor.opacity(0.08))
                .cornerRadius(20)
            }

            Spacer()

            // Weekly target
            if let target = workout.weeklyTarget {
                Text(target)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 4)

        // Guidance toggle below
        .overlay(alignment: .topLeading) {
            EmptyView()
        }
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35,
                                       dampingFraction: 0.75)) {
                    showGuidance.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: showGuidance
                          ? "chevron.up" : "info.circle")
                        .font(.system(size: 11))
                    Text(showGuidance ? "Less" : "Coach's note")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
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
