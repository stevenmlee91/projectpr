import SwiftUI

// MARK: - Plan Philosophy Card
//
// Shows the runner what their chosen methodology is actually doing —
// in plain coach language, not technical jargon. Replaces the old
// "Plan Health" score card. Builds trust by explaining the plan;
// doesn't audit it.

struct PlanPhilosophyCard: View {
    let plan: SavedPlan

    private var planType: PlanType? {
        PlanType(rawValue: plan.planType)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            methodologyHeader
            Divider()
            philosophyText
            phaseBreakdown
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Methodology Header

    private var methodologyHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: methodologyIcon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 18, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                Text("HOW THIS PLAN WORKS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .kerning(1.5)
                Text(planType?.rawValue ?? plan.planType)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
    }

    // MARK: - Philosophy Text

    private var philosophyText: some View {
        Text(philosophyCopy)
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(3)
    }

    // MARK: - Phase Breakdown

    private var phaseBreakdown: some View {
        let phases = buildPhases()
        return HStack(spacing: 0) {
            ForEach(phases, id: \.label) { phase in
                VStack(spacing: 5) {
                    Capsule()
                        .fill(phase.color)
                        .frame(height: 3)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(phase.weeks)")
                            .font(.system(size: 11, weight: .semibold,
                                          design: .monospaced))
                            .foregroundColor(.primary)
                        Text(phase.label)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 2)
    }

    // MARK: - Data

    private struct PhaseSegment {
        let label : String
        let weeks : Int
        let color : Color
    }

    private func buildPhases() -> [PhaseSegment] {
        var counts: [(phase: TrainingPhase, count: Int)] = []

        // Walk weeks in order, grouping consecutive same-phase runs
        let sorted = plan.weeks.sorted { $0.weekNumber < $1.weekNumber }
        for week in sorted {
            let ph = week.phase == .race ? TrainingPhase.taper : week.phase
            if let last = counts.indices.last, counts[last].phase == ph {
                counts[counts.indices.last!].count += 1
            } else {
                counts.append((ph, 1))
            }
        }

        return counts.map { entry in
            PhaseSegment(
                label: entry.phase.badgeLabel.capitalized,
                weeks: entry.count,
                color: entry.phase.accentColor
            )
        }
    }

    // MARK: - Copy per methodology

    private var philosophyCopy: String {
        guard let pt = planType else {
            return "A structured plan designed to build your fitness progressively toward race day."
        }
        switch pt {
        case .hansons:
            return "Cumulative fatigue. You train six days a week and never fully recover — that's intentional. The long run is capped at 16 miles because the goal isn't to simulate the marathon in training. It's to make marathon pace feel controlled. Race day will feel easier than your hardest training weeks."

        case .pfitz:
            return "High mileage, aerobic engine. Two quality days anchor a week that also includes a medium-long midweek run. No single workout carries the plan — the accumulation does. Expect some weeks to feel impossible. The volume is the adaptation."

        case .higdon:
            return "Long run focused. Three easy days each week build toward the Sunday long run, which is the week's centerpiece. This plan teaches your body to run far before it asks it to run fast. Runners finish their first marathons on plans like this."

        case .higdonIntermediate:
            return "Long run plus tempo. A step up from novice — a midweek tempo run and a medium-long run add variety and speed development. Cross-training days keep the engine working without adding impact. Built for runners who've finished a marathon and want to run it better."

        case .higdonHalfNovice:
            return "Three days, long run as anchor. Simple enough to stay consistent, substantial enough to prepare you for 13.1 miles. Long run builds to 10 miles. The simplicity is the feature — consistency matters more than complexity at this stage."

        case .higdonHalfIntermediate:
            return "Four to five days with a weekly tempo. Long run reaches 12 miles, one quality session per week develops race-specific speed. More volume than novice, more variety. Designed for runners who've raced a half marathon and want a genuine time improvement."

        case .hansonsHalf:
            return "Six days running, cumulative fatigue for the half marathon. Same philosophy as the marathon plan — controlled tiredness, capped long run, race-pace work built throughout. This is an aggressive half marathon plan. Race day feels controlled because training never fully let up."

        case .firstHalf:
            return "Four days running, built for first-timers. Long run builds gradually to 10 miles. Two rest days protect connective tissue while the aerobic base develops. The goal is to cross the finish line strong, with something left — not to survive it."
        }
    }

    private var methodologyIcon: String {
        guard let pt = planType else { return "figure.run" }
        switch pt {
        case .hansons, .hansonsHalf:               return "arrow.3.trianglepath"
        case .pfitz:                               return "mountain.2.fill"
        case .higdon, .higdonIntermediate:         return "figure.run"
        case .higdonHalfNovice, .firstHalf:        return "figure.run.circle"
        case .higdonHalfIntermediate, .hansonsHalf: return "figure.run.circle.fill"
        }
    }
}
