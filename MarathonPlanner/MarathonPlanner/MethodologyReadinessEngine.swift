import Foundation
import SwiftUI

// MARK: - Readiness Match Tier

enum ReadinessTier {
    /// Runner's base is well-aligned. Plan begins with full methodology structure.
    case ideal
    /// Runner has a real base. Brief onboarding before full methodology begins.
    case compatible
    /// Meaningful adaptation required. Plan structurally modified for this runner.
    case adaptive

    var label: String {
        switch self {
        case .ideal:      return "Well Matched"
        case .compatible: return "Compatible"
        case .adaptive:   return "Adapted Plan"
        }
    }

    var color: Color {
        switch self {
        case .ideal:      return Color(.systemGreen)
        case .compatible: return Color(.systemTeal)
        case .adaptive:   return Color(.systemOrange)
        }
    }

    var iconName: String {
        switch self {
        case .ideal:      return "checkmark.circle.fill"
        case .compatible: return "arrow.up.circle.fill"
        case .adaptive:   return "slider.horizontal.3"
        }
    }
}

// MARK: - Methodology Readiness Match

struct MethodologyReadinessMatch {
    /// The readiness tier for this runner + methodology combination.
    let tier                  : ReadinessTier
    /// Short headline — appears directly below the pill.
    let headline              : String
    /// Main coaching body text. Explains expectations and adaptations.
    let body                  : String
    /// Optional: brief bullet-point list of what the plan adapts (for .adaptive tier).
    let adaptationPoints      : [String]
    /// Optional: gentle recommendation for a more appropriate methodology.
    let alternativeMethodology : PlanType?
    /// Optional: explanation of why the alternative might suit them better.
    let alternativeRationale  : String?
    /// Optional: context about expected week-1 structure.
    let openingWeekPreview    : String?
}

// MARK: - Methodology Readiness Engine
//
// Evaluates the fit between a runner's current base mileage and the
// selected methodology. Returns coaching copy that surfaces in the
// plan confirmation screen — before the plan is generated.
//
// Design principles:
//   - Never gatekeeping. The plan always generates.
//   - Supportive realism: what the methodology expects, what will adapt.
//   - Coach voice, not warning system.
//   - Methodology alternatives are gentle suggestions, not redirections.

struct MethodologyReadinessEngine {

    // MARK: - Entry Point

    static func evaluate(planType: PlanType,
                         baseMileage: Double) -> MethodologyReadinessMatch? {
        // Only surface readiness guidance for methodologies with strong
        // base mileage requirements. Beginner plans don't need this.
        switch planType {
        case .hansons:        return hansons(base: baseMileage)
        case .pfitz:          return pfitz(base: baseMileage)
        case .higdonIntermediate: return higdonIntermediate(base: baseMileage)
        case .hansonsHalf:    return hansonsHalf(base: baseMileage)
        case .higdonHalfIntermediate: return higdonHalfIntermediate(base: baseMileage)
        default:              return nil  // Beginner plans: no readiness card needed
        }
    }

    // MARK: - Hansons Marathon

    private static func hansons(base: Double) -> MethodologyReadinessMatch {
        switch RunnerReadinessTier.from(base: base) {

        case .advanced:
            return MethodologyReadinessMatch(
                tier:     .ideal,
                headline: "Well aligned with Hansons.",
                body:     "Your current mileage is a strong match for the Hansons approach. The plan opens with full speed phase sessions from week one — six days running, cumulative fatigue introduced immediately. No adaptation phase needed.",
                adaptationPoints: [],
                alternativeMethodology: nil,
                alternativeRationale:  nil,
                openingWeekPreview:    "Week 1 opens with your first speed session and tempo run on a base of \(Int(base)) mpw."
            )

        case .prepared:
            return MethodologyReadinessMatch(
                tier:     .ideal,
                headline: "Solid match for Hansons.",
                body:     "You have the aerobic base Hansons requires. The plan begins with full cumulative-fatigue structure. Expect the six-day rhythm to feel demanding in weeks 1–2, then increasingly natural as your body adapts to frequency.",
                adaptationPoints: [],
                alternativeMethodology: nil,
                alternativeRationale:  nil,
                openingWeekPreview:    "Week 1 includes a speed session, tempo run, and easy running on six consecutive days."
            )

        case .developing:
            return MethodologyReadinessMatch(
                tier:     .compatible,
                headline: "Good base for Hansons with a brief onboarding.",
                body:     "Your current mileage supports the Hansons approach. The opening 2 weeks include fartlek and light effort sessions in place of full speed work — allowing your body to establish the six-day frequency before the heavier cumulative-fatigue load begins.",
                adaptationPoints: [
                    "Weeks 1–2: fartlek and light sessions instead of full speed intervals",
                    "Week 3: full speed phase begins at reduced session volume",
                    "Weeks 4+: authentic Hansons rhythm with growing cumulative fatigue"
                ],
                alternativeMethodology: nil,
                alternativeRationale:  nil,
                openingWeekPreview:    "Week 1 replaces the speed session with a fartlek run while establishing your six-day habit."
            )

        case .rebuilding:
            return MethodologyReadinessMatch(
                tier:     .adaptive,
                headline: "Hansons works best from 25–30 mpw. Your plan adapts.",
                body:     "Hansons is built around cumulative fatigue on a high-frequency base. From your current mileage, the plan opens with a 3-week rhythm-establishment phase — building six-day consistency and durability before introducing speed and strength sessions. You will be running authentic Hansons by week 4.",
                adaptationPoints: [
                    "Weeks 1–2: strides and easy aerobic work to establish six-day rhythm",
                    "Week 3: fartlek sessions introduce effort variation",
                    "Week 4+: full speed phase begins, volume scaled to your actual weekly mileage",
                    "Speed → strength transition occurs at canonical week 9 regardless of starting point"
                ],
                alternativeMethodology: .higdon,
                alternativeRationale:  "Higdon Novice is designed to build the aerobic base Hansons requires. Completing a Higdon cycle first means you arrive at Hansons with the mileage it was built for.",
                openingWeekPreview:    "Week 1 focuses on establishing six-day consistency with easy runs and strides. No intervals yet."
            )
        }
    }

    // MARK: - Pfitz Marathon

    private static func pfitz(base: Double) -> MethodologyReadinessMatch {
        switch RunnerReadinessTier.from(base: base) {

        case .advanced:
            return MethodologyReadinessMatch(
                tier:     .ideal,
                headline: "Your base is well matched to Pfitz.",
                body:     "You have the aerobic foundation Pfitz's density demands. The plan opens with full structure immediately: a medium-long run every week from day one, LT sessions, and long runs building toward 20+ miles. No adaptation phase.",
                adaptationPoints: [],
                alternativeMethodology: nil,
                alternativeRationale:  nil,
                openingWeekPreview:    "Week 1 includes a lactate threshold session, a medium-long run, and a long run — the complete Pfitz weekly structure."
            )

        case .prepared:
            return MethodologyReadinessMatch(
                tier:     .compatible,
                headline: "Solid base for Pfitz.",
                body:     "Your mileage supports the Pfitz structure. The first week uses a slightly shorter LT segment before canonical volume begins in week 2. The medium-long run is present from day one — it scales with your weekly mileage and grows as the block progresses.",
                adaptationPoints: [
                    "Week 1: LT session at slightly reduced volume",
                    "Weeks 2+: full LT + medium-long run + long run structure",
                    "Medium-long run grows proportionally with weekly mileage"
                ],
                alternativeMethodology: nil,
                alternativeRationale:  nil,
                openingWeekPreview:    "Week 1 opens with LT, MLR, and long run — Pfitz's complete triple-stimulus framework."
            )

        case .developing:
            return MethodologyReadinessMatch(
                tier:     .adaptive,
                headline: "Pfitz is achievable. Your plan builds into the density.",
                body:     "Pfitz's medium-long run + LT + long run structure requires a real aerobic base. From your current mileage, the opening 2–3 weeks use general aerobic runs in place of LT sessions — allowing your body to adapt to the dual-stimulus weekly load before threshold intensity is introduced.",
                adaptationPoints: [
                    "Weeks 1–2: general aerobic runs instead of LT sessions",
                    "Week 3+: LT work begins at scaled volume",
                    "Medium-long run present every week from day one, starting at ~10 miles",
                    "Long runs start conservatively and build toward canonical Pfitz distances"
                ],
                alternativeMethodology: .higdonIntermediate,
                alternativeRationale:  "Higdon Intermediate builds the base Pfitz assumes. Completing a Higdon Intermediate cycle first means you arrive at Pfitz with the mileage and aerobic density it was designed for.",
                openingWeekPreview:    "Week 1 replaces the LT session with a general aerobic run while the medium-long run is present at scaled distance."
            )

        case .rebuilding:
            return MethodologyReadinessMatch(
                tier:     .adaptive,
                headline: "Pfitz works best from 35–40 mpw. Your plan adapts significantly.",
                body:     "Pfitz 18/55 is one of the most demanding marathon programs available. From your current base, the plan opens with a 3–4 week onboarding phase: general aerobic runs replace LT sessions, medium-long runs start smaller, and long runs begin well below canonical Pfitz distances. Full methodology density arrives gradually.",
                adaptationPoints: [
                    "Weeks 1–3: no LT sessions — general aerobic runs instead",
                    "Week 4+: LT sessions begin at reduced volume, growing weekly",
                    "Medium-long run present every week — begins at ~9 miles, builds proportionally",
                    "Long runs start at ~\(Int(base * 0.30))–\(Int(base * 0.32)) miles, building toward 20–22"
                ],
                alternativeMethodology: .higdonIntermediate,
                alternativeRationale:  "Higdon Intermediate is a better starting point. It builds the 35–40 mpw aerobic base that Pfitz was designed for — without the risk of the adaptation gap being too large.",
                openingWeekPreview:    "Week 1 opens with a general aerobic run, a medium-long run at ~\(Int(base * 0.28)) miles, and a long run of ~\(Int(base * 0.30)) miles."
            )
        }
    }

    // MARK: - Higdon Intermediate Marathon

    private static func higdonIntermediate(base: Double) -> MethodologyReadinessMatch {
        if base >= 30 {
            return MethodologyReadinessMatch(
                tier:     .ideal,
                headline: "Your base is well suited to Higdon Intermediate.",
                body:     "You have a strong aerobic foundation for this plan. The tempo runs, midweek longer runs, and progressive long run will feel appropriately challenging — not overwhelming.",
                adaptationPoints: [],
                alternativeMethodology: nil, alternativeRationale: nil,
                openingWeekPreview: nil
            )
        } else {
            return MethodologyReadinessMatch(
                tier:     .compatible,
                headline: "Higdon Intermediate is achievable from your base.",
                body:     "The plan opens with conservative mileage. Tempo runs are introduced gradually. You will build into the full structure over the first 3–4 weeks.",
                adaptationPoints: [
                    "Early tempo sessions start at lower volume",
                    "Midweek longer runs begin at manageable distances"
                ],
                alternativeMethodology: base < 20 ? .higdon : nil,
                alternativeRationale:  base < 20 ? "Higdon Novice is designed for runners building their base. It offers a safer starting point before moving to Intermediate." : nil,
                openingWeekPreview: nil
            )
        }
    }

    // MARK: - Hansons Half

    private static func hansonsHalf(base: Double) -> MethodologyReadinessMatch {
        if base >= 30 {
            return MethodologyReadinessMatch(
                tier:     .ideal,
                headline: "Solid base for Hansons Half.",
                body:     "Your mileage supports the six-day Hansons structure from day one. The plan opens with full speed phase sessions.",
                adaptationPoints: [],
                alternativeMethodology: nil, alternativeRationale: nil,
                openingWeekPreview: nil
            )
        } else if base >= 20 {
            return MethodologyReadinessMatch(
                tier:     .compatible,
                headline: "Compatible with Hansons Half with brief onboarding.",
                body:     "The opening weeks include lighter sessions to establish the six-day rhythm before full cumulative-fatigue training begins. Full methodology structure arrives by week 3.",
                adaptationPoints: [
                    "Weeks 1–2: fartlek and strides instead of full speed sessions",
                    "Week 3+: authentic Hansons speed phase"
                ],
                alternativeMethodology: nil, alternativeRationale: nil,
                openingWeekPreview: nil
            )
        } else {
            return MethodologyReadinessMatch(
                tier:     .adaptive,
                headline: "Your plan adapts Hansons Half to your starting point.",
                body:     "Hansons Half is built for runners with an established base. The plan opens with a rhythm-building phase before cumulative fatigue is introduced. You will be running authentic Hansons Half training by week 4.",
                adaptationPoints: [
                    "Weeks 1–3: onboarding sessions build six-day habit",
                    "Week 4+: speed and strength sessions begin at scaled volume"
                ],
                alternativeMethodology: .higdonHalfNovice,
                alternativeRationale:  "Higdon Half Novice builds the base Hansons Half requires — completing it first gives you a stronger foundation.",
                openingWeekPreview: nil
            )
        }
    }

    // MARK: - Higdon Half Intermediate

    private static func higdonHalfIntermediate(base: Double) -> MethodologyReadinessMatch {
        if base >= 20 {
            return MethodologyReadinessMatch(
                tier:     .ideal,
                headline: "Good match for Higdon Half Intermediate.",
                body:     "Your current mileage supports the tempo work and five-day structure this plan introduces. The progression will feel challenging but manageable.",
                adaptationPoints: [],
                alternativeMethodology: nil, alternativeRationale: nil,
                openingWeekPreview: nil
            )
        } else {
            return MethodologyReadinessMatch(
                tier:     .compatible,
                headline: "Achievable from your base.",
                body:     "Tempo sessions begin at conservative volumes and build gradually. The plan is designed to grow you into the intermediate structure over the first few weeks.",
                adaptationPoints: ["Early tempo sessions at lighter volume"],
                alternativeMethodology: base < 12 ? .higdonHalfNovice : nil,
                alternativeRationale:  base < 12 ? "Higdon Half Novice is a more appropriate starting point at your current mileage." : nil,
                openingWeekPreview: nil
            )
        }
    }
}
