import SwiftUI

// MARK: - Workout Completion Button

struct WorkoutCompletionButton: View {
    let status    : CompletionStatus
    let isRestDay : Bool
    let onComplete: () -> Void
    let onSkip    : () -> Void

    var body: some View {
        VStack(spacing: 6) {
            completeButton
            skipButton
        }
    }

    // MARK: - Complete Button

    private var completeButton: some View {
        Button(action: onComplete) {
            ZStack {
                // Track ring — always visible
                Circle()
                    .stroke(
                        status == .completed
                            ? Color(hex: "30D158")
                            : Color(.systemFill),
                        lineWidth: 2
                    )
                    .frame(width: 36, height: 36)

                // Fill — only when complete
                if status == .completed || status == .modified {
                    Circle()
                        .fill(Color(hex: "30D158"))
                        .frame(width: 36, height: 36)
                        .transition(.scale(scale: 0.4)
                            .combined(with: .opacity))
                }

                // Icon
                if status == .completed || status == .modified {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .transition(.scale(scale: 0.5)
                            .combined(with: .opacity))
                } else {
                    // Subtle affordance dot when incomplete
                    Circle()
                        .fill(Color(.tertiaryLabel))
                        .frame(width: 8, height: 8)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(CompletionButtonStyle())
        .disabled(isRestDay)
        .animation(.spring(response: 0.28,
                            dampingFraction: 0.72),
                   value: status)
    }

    // MARK: - Skip Button

    private var skipButton: some View {
        Button(action: onSkip) {
            ZStack {
                Circle()
                    .stroke(
                        status == .skipped
                            ? Color(hex: "FF453A").opacity(0.6)
                            : Color(.systemFill),
                        lineWidth: 1.5
                    )
                    .frame(width: 26, height: 26)

                if status == .skipped {
                    Circle()
                        .fill(Color(hex: "FF453A").opacity(0.15))
                        .frame(width: 26, height: 26)
                        .transition(.scale(scale: 0.4)
                            .combined(with: .opacity))
                }

                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(status == .skipped
                                     ? Color(hex: "FF453A")
                                     : Color(.tertiaryLabel))
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(CompletionButtonStyle())
        .disabled(isRestDay)
        .animation(.spring(response: 0.28,
                            dampingFraction: 0.72),
                   value: status)
    }
}

// MARK: - Rest Day Marker

struct RestDayMarker: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemFill), lineWidth: 1.5)
                .frame(width: 36, height: 36)
            Image(systemName: "moon.fill")
                .font(.system(size: 12, weight: .light))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .frame(width: 44, height: 44)
    }
}

// MARK: - Button Style (scale on press)

struct CompletionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.2,
                                dampingFraction: 0.65),
                       value: configuration.isPressed)
    }
}

// MARK: - Haptics

enum CompletionHaptics {
    static func complete() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func uncomplete() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func skip() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }
}
