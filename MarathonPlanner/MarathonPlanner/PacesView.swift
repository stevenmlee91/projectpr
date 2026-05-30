import SwiftUI

// MARK: - Paces View
//
// Plan-specific pace reference card. Shown in the context of a saved plan
// where settings (goal time, plan type) are already known.
// For the standalone calculator, see PaceCalculatorView.

struct PacesView: View {
    let settings: UserSettings

    private var engine: PaceEngine {
        PaceEngine(goalMinutes: settings.goalTimeMinutes,
                   distance: settings.raceType.distance)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {

                // Goal hero
                VStack(spacing: 4) {
                    Text(settings.goalTimeFormatted)
                        .font(.metric(48))
                        .foregroundColor(.primary)
                    Text("goal · \(PaceEngine.format(engine.MP))/mi marathon pace")
                        .font(.metricCaption(12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(Radius.xl)

                // Pace cards
                VStack(spacing: Spacing.sm) {
                    paceCard(
                        eyebrow: "MARATHON PACE",
                        pace:    PaceEngine.format(engine.MP) + "/mi",
                        detail:  "Your race day goal. Train around this number.",
                        color:   Color(hex: "0A84FF"),
                        isHero:  true
                    )

                    HStack(spacing: Spacing.sm) {
                        paceCard(
                            eyebrow: "EASY",
                            pace:    engine.rangeString(engine.easy),
                            detail:  "Conversational. Most of your miles.",
                            color:   Color(hex: "30D158")
                        )
                        paceCard(
                            eyebrow: "LONG RUN",
                            pace:    engine.rangeString(engine.longRun),
                            detail:  "60–90 sec/mi slower than MP.",
                            color:   Color(hex: "0A84FF")
                        )
                    }

                    HStack(spacing: Spacing.sm) {
                        paceCard(
                            eyebrow: "TEMPO",
                            pace:    PaceEngine.format(engine.pfitzLT) + "/mi",
                            detail:  "Comfortably hard. 4–8 mile efforts.",
                            color:   Color(hex: "FF9F0A")
                        )
                        paceCard(
                            eyebrow: "INTERVALS",
                            pace:    PaceEngine.format(engine.dInterval) + "/mi",
                            detail:  "~5K effort. Short repeats.",
                            color:   Color(hex: "FF453A")
                        )
                    }

                    paceCard(
                        eyebrow: "RECOVERY",
                        pace:    PaceEngine.format(engine.recovery) + "/mi",
                        detail:  "Very easy. The day after hard workouts.",
                        color:   Color(.tertiaryLabel)
                    )
                }

                // Coaching note
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("REMEMBER")
                        .eyebrow()
                    Text("Paces are targets, not rules. Run easy days genuinely easy — most runners run them 30–45 sec/mi too fast. Hard sessions are hard; easy sessions are easy. Nothing in between.")
                        .font(.appBody(12))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }
                .padding(Spacing.lg)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(Radius.xl)

                Spacer().frame(height: Spacing.section)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.xl)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Pace Card

    private func paceCard(eyebrow: String, pace: String,
                           detail: String, color: Color,
                           isHero: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(eyebrow)
                .font(.label(9))
                .foregroundColor(color)
                .kerning(1.5)
            Text(pace)
                .font(isHero ? .metric(28) : .metric(20))
                .foregroundColor(.primary)
            Text(detail)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(2)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg)
                .stroke(isHero ? color.opacity(0.2) : Color.clear,
                        lineWidth: 1)
        )
        .cornerRadius(Radius.lg)
    }
}
