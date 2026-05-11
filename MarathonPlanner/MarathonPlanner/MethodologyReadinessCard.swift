import SwiftUI

// MARK: - Methodology Readiness Card
//
// Surfaces coaching-aware readiness guidance before plan confirmation.
// Placed in the plan creation/confirmation screen, above the generate button.
//
// USAGE in plan confirmation view:
//   if let readiness = MethodologyReadinessEngine.evaluate(
//       planType: settings.planType,
//       baseMileage: settings.baseMileage) {
//       MethodologyReadinessCard(readiness: readiness, settings: settings)
//   }
//
// DESIGN PRINCIPLES:
//   - No red. No "warning." No "not recommended."
//   - Supportive realism: what the methodology expects, what adapts, why.
//   - Expander for adaptation points — doesn't overwhelm at first glance.
//   - Alternative methodology suggestion is gentle, never commanding.

struct MethodologyReadinessCard: View {

    let readiness : MethodologyReadinessMatch
    let settings  : UserSettings

    @State private var adaptationsExpanded : Bool = false
    @State private var appeared            : Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Tier Pill ────────────────────────────────────────────────
            HStack(spacing: 6) {
                Image(systemName: readiness.tier.iconName)
                    .font(.system(size: 11, weight: .semibold))
                Text(readiness.tier.label.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .kerning(0.5)
            }
            .foregroundColor(readiness.tier.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(readiness.tier.color.opacity(0.12), in: Capsule())
            .padding(.bottom, 12)

            // ── Headline ─────────────────────────────────────────────────
            Text(readiness.headline)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)

            // ── Body ─────────────────────────────────────────────────────
            Text(readiness.body)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            // ── Week 1 Preview ───────────────────────────────────────────
            if let preview = readiness.openingWeekPreview {
                Divider()
                    .padding(.vertical, 14)

                Label {
                    Text(preview)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 13))
                        .foregroundColor(readiness.tier.color)
                }
            }

            // ── Adaptation Points (expandable) ───────────────────────────
            if !readiness.adaptationPoints.isEmpty {
                Divider()
                    .padding(.vertical, 14)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        adaptationsExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text("How your plan adapts")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: adaptationsExpanded
                              ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if adaptationsExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(readiness.adaptationPoints, id: \.self) { point in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(readiness.tier.color)
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 5)
                                Text(point)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            // ── Alternative Methodology Suggestion ───────────────────────
            if let alternative = readiness.alternativeMethodology,
               let rationale   = readiness.alternativeRationale {
                Divider()
                    .padding(.vertical, 14)

                AlternativeMethodologyRow(
                    alternative: alternative,
                    rationale:   rationale,
                    currentBase: settings.baseMileage
                )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(readiness.tier.color.opacity(0.25), lineWidth: 1)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 6)
        .onAppear {
            withAnimation(.easeOut(duration: 0.28).delay(0.05)) {
                appeared = true
            }
        }
    }
}

// MARK: - Alternative Methodology Row
//
// Gentle suggestion at the bottom of the card.
// Never commanding — presents an option, explains why.

private struct AlternativeMethodologyRow: View {
    let alternative : PlanType
    let rationale   : String
    let currentBase : Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Also worth considering", systemImage: "lightbulb")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)

            Text("**\(alternative.rawValue)** — \(rationale)")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Readiness Card Container
//
// Convenience wrapper that handles the optional evaluation.
// Drop this into your plan confirmation view.
//
// INTEGRATION EXAMPLE:
//
//   ReadinessCardIfNeeded(settings: draftSettings)
//       .padding(.horizontal)
//       .padding(.bottom, 8)

struct ReadinessCardIfNeeded: View {
    let settings: UserSettings

    var body: some View {
        if let readiness = MethodologyReadinessEngine.evaluate(
            planType:    settings.planType,
            baseMileage: settings.baseMileage
        ) {
            MethodologyReadinessCard(readiness: readiness, settings: settings)
        }
    }
}

// MARK: - Current Mileage Indicator
//
// Optional small inline element showing mileage vs methodology range.
// Useful beneath the base mileage input field in plan setup.
//
// INTEGRATION EXAMPLE (in plan setup, below baseMileage slider):
//
//   MileageCompatibilityLabel(planType: settings.planType,
//                              baseMileage: settings.baseMileage)

struct MileageCompatibilityLabel: View {
    let planType    : PlanType
    let baseMileage : Double

    private var recommendation: String? {
        MethodologyReadinessEngine.evaluate(planType: planType,
                                             baseMileage: baseMileage)?
            .tier == .adaptive
            ? MethodologyReadinessEngine.evaluate(planType: planType,
                                                   baseMileage: baseMileage)?
                .headline
            : nil
    }

    private var tier: ReadinessTier? {
        MethodologyReadinessEngine.evaluate(planType: planType,
                                             baseMileage: baseMileage)?.tier
    }

    var body: some View {
        if let t = tier, t != .ideal {
            HStack(spacing: 5) {
                Image(systemName: t.iconName)
                    .font(.system(size: 11))
                    .foregroundColor(t.color)
                Text(t.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(t.color)
            }
            .transition(.opacity)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MethodologyReadinessCard_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 16) {

                // Advanced Hansons — ideal
                if let r = MethodologyReadinessEngine.evaluate(planType: .hansons,
                                                                 baseMileage: 50) {
                    MethodologyReadinessCard(
                        readiness: r,
                        settings:  previewSettings(.hansons, base: 50)
                    )
                }

                // Developing Hansons — compatible
                if let r = MethodologyReadinessEngine.evaluate(planType: .hansons,
                                                                 baseMileage: 28) {
                    MethodologyReadinessCard(
                        readiness: r,
                        settings:  previewSettings(.hansons, base: 28)
                    )
                }

                // Rebuilding Hansons — adaptive (with suggestion)
                if let r = MethodologyReadinessEngine.evaluate(planType: .hansons,
                                                                 baseMileage: 15) {
                    MethodologyReadinessCard(
                        readiness: r,
                        settings:  previewSettings(.hansons, base: 15)
                    )
                }

                // Developing Pfitz — adaptive
                if let r = MethodologyReadinessEngine.evaluate(planType: .pfitz,
                                                                 baseMileage: 30) {
                    MethodologyReadinessCard(
                        readiness: r,
                        settings:  previewSettings(.pfitz, base: 30)
                    )
                }

            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }

    private static func previewSettings(_ planType: PlanType,
                                         base: Double) -> UserSettings {
        var s = UserSettings()
        s.planType   = planType
        s.baseMileage = base
        return s
    }
}
#endif
