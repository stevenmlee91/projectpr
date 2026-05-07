import Foundation

// MARK: - Run Type

enum OffSeasonRunType: String {
    case easy        = "Easy Run"
    case recovery    = "Recovery Run"
    case tempo       = "Tempo Run"
    case strides     = "Easy + Strides"
    case longRun     = "Long Run"
    case crossTrain  = "Cross-Training"
    case rest        = "Rest"

    var colorName: String {
        switch self {
        case .easy, .strides:    return "green"
        case .recovery:          return "mint"
        case .tempo:             return "orange"
        case .longRun:           return "blue"
        case .crossTrain:        return "purple"
        case .rest:              return "gray"
        }
    }

    var icon: String {
        switch self {
        case .easy:       return "figure.run"
        case .recovery:   return "figure.walk"
        case .tempo:      return "flame"
        case .strides:    return "hare"
        case .longRun:    return "arrow.right.to.line"
        case .crossTrain: return "figure.cross.training"
        case .rest:       return "moon.stars"
        }
    }
}

// MARK: - Suggested Workout

struct SuggestedWorkout {
    let title       : String
    let distance    : String
    let description : String
    let guidance    : String
    let type        : OffSeasonRunType
}

// MARK: - Off-Season Engine

struct OffSeasonEngine {

    // MARK: - Public Entry Point

    static func todaySuggestion(
        date     : Date     = Date(),
        settings : UserSettings? = nil,
        recentlyFinishedRace: Bool = false
    ) -> SuggestedWorkout {

        let cal     = Calendar.current
        let weekday = cal.component(.weekOfYear, from: date)
        let day     = cal.component(.weekday, from: date)
        // weekday: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat

        // Post-race recovery window — first 10 days very light
        if recentlyFinishedRace {
            return postRaceSuggestion(daysAfterRace: 3)
        }

        // Vary suggestions slightly by week of year to avoid repetition
        let weekVariant = weekday % 3  // 0, 1, or 2

        switch day {
        case 2: // Monday
            return monday(variant: weekVariant)
        case 3: // Tuesday
            return tuesday(variant: weekVariant)
        case 4: // Wednesday
            return wednesday(variant: weekVariant)
        case 5: // Thursday
            return thursday(variant: weekVariant)
        case 6: // Friday
            return friday(variant: weekVariant)
        case 7: // Saturday
            return saturday(variant: weekVariant)
        case 1: // Sunday
            return sunday(variant: weekVariant)
        default:
            return monday(variant: 0)
        }
    }

    // MARK: - Daily Suggestions

    private static func monday(variant: Int) -> SuggestedWorkout {
        switch variant {
        case 0:
            return SuggestedWorkout(
                title:       "Easy Run",
                distance:    "3–4 miles",
                description: "Start the week gently. Shake out the weekend's long run.",
                guidance:    "Keep it fully conversational. If you can't speak in sentences, slow down.",
                type:        .easy
            )
        case 1:
            return SuggestedWorkout(
                title:       "Easy Run",
                distance:    "4–5 miles",
                description: "Monday base mileage. Nothing heroic — just consistency.",
                guidance:    "Run by feel. Easy effort, steady breathing.",
                type:        .easy
            )
        default:
            return SuggestedWorkout(
                title:       "Rest or Cross-Train",
                distance:    "30–45 min",
                description: "Active recovery to start the week. Cycling, swimming, or yoga.",
                guidance:    "Low impact. Give your legs a break while keeping the habit.",
                type:        .crossTrain
            )
        }
    }

    private static func tuesday(variant: Int) -> SuggestedWorkout {
        switch variant {
        case 0:
            return SuggestedWorkout(
                title:       "Easy + Strides",
                distance:    "4–5 miles",
                description: "Easy run with 4–6 strides at the end.",
                guidance:    "Strides are 20 seconds at 5K effort — not a sprint, just quick and relaxed. Walk recovery between each.",
                type:        .strides
            )
        case 1:
            return SuggestedWorkout(
                title:       "Tempo Run",
                distance:    "4–5 miles",
                description: "1 mile easy warm-up, 2 miles at comfortably hard effort, 1 mile easy cool-down.",
                guidance:    "Tempo effort is roughly 15K to half marathon pace. Uncomfortable but controlled.",
                type:        .tempo
            )
        default:
            return SuggestedWorkout(
                title:       "Easy Run",
                distance:    "3–4 miles",
                description: "Light Tuesday run. Keep the legs moving without digging a hole.",
                guidance:    "If yesterday felt heavy, make today shorter. Consistency over the week matters more than any single session.",
                type:        .easy
            )
        }
    }

    private static func wednesday(variant: Int) -> SuggestedWorkout {
        switch variant {
        case 0:
            return SuggestedWorkout(
                title:       "Easy Run",
                distance:    "4–6 miles",
                description: "Mid-week aerobic run. The backbone of any base-building block.",
                guidance:    "Run at the effort where you could hold a conversation without gasping. That is the right pace.",
                type:        .easy
            )
        case 1:
            return SuggestedWorkout(
                title:       "Cross-Training",
                distance:    "45–60 min",
                description: "Mid-week break from running. Bike, swim, or elliptical.",
                guidance:    "Aerobic effort without the impact. Lets the legs recover while keeping fitness.",
                type:        .crossTrain
            )
        default:
            return SuggestedWorkout(
                title:       "Easy Run",
                distance:    "5–6 miles",
                description: "Longer mid-week easy run. Build aerobic volume without intensity.",
                guidance:    "This is the run most runners cut short or skip. Do not. Mid-week mileage is where base fitness is actually built.",
                type:        .easy
            )
        }
    }

    private static func thursday(variant: Int) -> SuggestedWorkout {
        switch variant {
        case 0:
            return SuggestedWorkout(
                title:       "Moderate Run",
                distance:    "5–7 miles",
                description: "Slightly harder than easy. Not a workout, but not a jog either.",
                guidance:    "General aerobic effort — honest running without structure. Find a rhythm and stay there.",
                type:        .easy
            )
        case 1:
            return SuggestedWorkout(
                title:       "Easy + Strides",
                distance:    "4–5 miles",
                description: "Easy run with strides at the end to maintain leg speed.",
                guidance:    "Strides keep your neuromuscular system sharp during base building. Do not skip them because they feel unnecessary.",
                type:        .strides
            )
        default:
            return SuggestedWorkout(
                title:       "Moderate Run",
                distance:    "5–6 miles",
                description: "Thursday push. More honest than easy, less structured than a workout.",
                guidance:    "This sits between easy and tempo. You are working, but you are not digging deep.",
                type:        .easy
            )
        }
    }

    private static func friday(variant: Int) -> SuggestedWorkout {
        switch variant {
        case 0:
            return SuggestedWorkout(
                title:       "Rest",
                distance:    "—",
                description: "Full rest before tomorrow's long run. This is not optional.",
                guidance:    "Sleep, eat well, hydrate. Everything that happens today affects the quality of tomorrow's long run.",
                type:        .rest
            )
        case 1:
            return SuggestedWorkout(
                title:       "Easy Run",
                distance:    "3–4 miles",
                description: "Short and easy Friday shakeout before tomorrow's long run.",
                guidance:    "Keep it under 40 minutes. Leave something in the tank for Saturday.",
                type:        .easy
            )
        default:
            return SuggestedWorkout(
                title:       "Rest or Cross-Train",
                distance:    "30 min",
                description: "Light movement or full rest. Prepare for tomorrow.",
                guidance:    "If your legs feel heavy from the week, take the full rest. If you feel good, a gentle walk or 20 minutes on the bike is fine.",
                type:        .crossTrain
            )
        }
    }

    private static func saturday(variant: Int) -> SuggestedWorkout {
        switch variant {
        case 0:
            return SuggestedWorkout(
                title:       "Long Run",
                distance:    "6–8 miles",
                description: "The most important run of your week. Fully conversational effort throughout.",
                guidance:    "Start slower than feels right. The first two miles should feel almost easy. If you are breathing hard at mile 3, back off.",
                type:        .longRun
            )
        case 1:
            return SuggestedWorkout(
                title:       "Long Run",
                distance:    "7–9 miles",
                description: "Build your long run gradually over the off-season. This is the run that matters.",
                guidance:    "No pace goal. Time on feet at easy effort. Eat something beforehand if you are running over 75 minutes.",
                type:        .longRun
            )
        default:
            return SuggestedWorkout(
                title:       "Long Run",
                distance:    "5–7 miles",
                description: "Off-season long run. Build the habit of going long, even when there is no race on the horizon.",
                guidance:    "Consistency on the long run during off-season is what allows you to start your next training block at a higher base.",
                type:        .longRun
            )
        }
    }

    private static func sunday(variant: Int) -> SuggestedWorkout {
        switch variant {
        case 0:
            return SuggestedWorkout(
                title:       "Recovery Run",
                distance:    "2–3 miles",
                description: "Short and slow after yesterday's long run.",
                guidance:    "If your legs are very sore, skip this entirely or walk. The point is active recovery, not mileage.",
                type:        .recovery
            )
        case 1:
            return SuggestedWorkout(
                title:       "Rest",
                distance:    "—",
                description: "Full rest day. Recover from the long run.",
                guidance:    "Serious runners take rest seriously. Today is not wasted time — it is when adaptation happens.",
                type:        .rest
            )
        default:
            return SuggestedWorkout(
                title:       "Recovery Run",
                distance:    "3–4 miles",
                description: "Easy Sunday run to keep the legs moving after Saturday.",
                guidance:    "Run slower than feels necessary. Your cardiovascular system recovers faster than your muscles — your perceived effort will lie to you today.",
                type:        .recovery
            )
        }
    }

    // MARK: - Post-Race Recovery

    static func postRaceSuggestion(daysAfterRace: Int) -> SuggestedWorkout {
        switch daysAfterRace {
        case 0...3:
            return SuggestedWorkout(
                title:       "Full Rest",
                distance:    "—",
                description: "You just ran a race. Your body needs complete recovery.",
                guidance:    "No running. Walking is fine. Sleep as much as you can. You earned this.",
                type:        .rest
            )
        case 4...7:
            return SuggestedWorkout(
                title:       "Recovery Walk or Jog",
                distance:    "2–3 miles",
                description: "First steps back. Walk if your legs want to walk.",
                guidance:    "There is no pace goal. No distance goal. Just gentle movement to start the recovery process.",
                type:        .recovery
            )
        case 8...14:
            return SuggestedWorkout(
                title:       "Easy Run",
                distance:    "3–4 miles",
                description: "Easing back into training after your race.",
                guidance:    "Two weeks out from a marathon your legs may still feel flat. That is normal. Keep it easy and short for another week.",
                type:        .easy
            )
        default:
            return monday(variant: 0)
        }
    }
}
