import SwiftUI

// Full implementation — paste WorkoutCompletionView.swift contents here
// Minimum needed to unblock TodayView:

struct CompletionContext {
    let workoutType : String
    let miles       : Double
    let isLongRun   : Bool
    let isRaceDay   : Bool
    let isQuality   : Bool

    var headline: String {
        if isRaceDay { return "Race complete." }
        if isLongRun { return "Long run done." }
        if isQuality { return "Strong work." }
        return "Done."
    }

    var subline: String {
        if isRaceDay { return "Everything you trained for. Done." }
        if isLongRun { return "The hay is going in the barn." }
        if isQuality { return "Hard sessions make race day feel easy." }
        return "Consistency wins."
    }

    var accentColor: Color {
        if isRaceDay { return Color(hex: "FFD60A") }
        if isLongRun { return Color(hex: "0A84FF") }
        if isQuality { return Color(hex: "FF9F0A") }
        return Color(hex: "30D158")
    }

    var hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        if isRaceDay || isLongRun { return .heavy }
        if isQuality              { return .medium }
        return .light
    }

    static func make(from day: SavedDay) -> CompletionContext {
        let type      = day.workoutType
        let miles     = day.actualMiles ?? day.miles
        let isRaceDay = type == "Race Day 🏁"
        let isLongRun = type.contains("Long Run")
        let isQuality = type.contains("Tempo")
            || type.contains("Threshold")
            || type.contains("Interval")
            || type.contains("Repetition")
            || type.contains("Speed")
            || type.contains("Cruise")
            || type.contains("Lactate")
            || type.contains("Marathon Pace")
            || type.contains("Strength")
        return CompletionContext(
            workoutType: type,
            miles:       miles,
            isLongRun:   isLongRun,
            isRaceDay:   isRaceDay,
            isQuality:   isQuality
        )
    }
}

struct WorkoutHaptics {
    static func fire(for context: CompletionContext) {
        UIImpactFeedbackGenerator(style: context.hapticStyle)
            .impactOccurred()
        if context.isLongRun || context.isRaceDay {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                UINotificationFeedbackGenerator()
                    .notificationOccurred(.success)
            }
        }
    }
}

struct WorkoutCompletionView: View {
    let context  : CompletionContext
    let onDismiss: () -> Void

    @State private var appeared    = false
    @State private var ringScale   : CGFloat = 0.6
    @State private var ringOpacity : Double  = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .stroke(context.accentColor.opacity(0.25),
                                lineWidth: 2)
                        .frame(width: 140, height: 140)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)
                    Circle()
                        .fill(context.accentColor.opacity(0.10))
                        .frame(width: 100, height: 100)
                    Image(systemName: iconName)
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(context.accentColor)
                }
                .padding(.top, 40)
                .padding(.bottom, 24)

                if context.miles > 0 && !context.isRaceDay {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(String(format: "%.1f", context.miles))
                            .font(.system(size: 56, weight: .thin,
                                          design: .monospaced))
                            .foregroundColor(.primary)
                        Text("mi")
                            .font(.system(size: 20, weight: .light,
                                          design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 6)
                    }
                    .padding(.bottom, 8)
                }

                Text(context.headline)
                    .font(.system(size: 22, weight: .bold,
                                  design: .serif))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)

                Text(context.subline)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 36)

                Button(action: dismiss) {
                    Text("DONE")
                        .font(.system(size: 12, weight: .semibold,
                                      design: .monospaced))
                        .foregroundColor(.secondary)
                        .kerning(3)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground))
                }
                .buttonStyle(.plain)
            }
            .background(Color(.systemBackground))
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.2), radius: 30, y: 10)
            .padding(.horizontal, 36)
            .scaleEffect(appeared ? 1.0 : 0.85)
            .opacity(appeared ? 1.0 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45,
                                   dampingFraction: 0.72)) {
                appeared = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                ringScale   = 1.2
                ringOpacity = 1
            }
            withAnimation(.easeIn(duration: 0.5).delay(0.8)) {
                ringOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                dismiss()
            }
        }
    }

    private var iconName: String {
        if context.isRaceDay { return "flag.checkered" }
        if context.isLongRun { return "arrow.left.and.right" }
        if context.isQuality { return "bolt.fill" }
        return "checkmark"
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.25)) { appeared = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismiss()
        }
    }
}
