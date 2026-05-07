import SwiftUI

// MARK: - Off-Season Card

struct OffSeasonCard: View {
    let workout: SuggestedWorkout

    @State private var showGuidance = false

    var body: some View {
        VStack(spacing: 0) {
            // Type bar — matches TodayWorkoutCard exactly
            typeBar

            // Content
            VStack(alignment: .leading, spacing: 16) {
                distanceRow
                descriptionText

                if showGuidance {
                    guidanceText
                        .transition(.move(edge: .top)
                            .combined(with: .opacity))
                }

                guidanceToggle
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
            Text("OFF-SEASON")
                .font(.system(size: 10, weight: .semibold,
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
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Image(systemName: workout.type.icon)
                .font(.system(size: 22, weight: .ultraLight))
                .foregroundColor(accentColor.opacity(0.5))
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

    // MARK: - Guidance

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

    // MARK: - Guidance Toggle

    private var guidanceToggle: some View {
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
                Text(showGuidance ? "Less" : "Why this run?")
                    .font(.system(size: 12, weight: .medium))
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
