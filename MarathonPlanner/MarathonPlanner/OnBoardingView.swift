import SwiftUI

// MARK: - Design Tokens

private enum OB {
    // Spacing (8pt grid)
    static let margin    : CGFloat = 24
    static let cardPad   : CGFloat = 20
    static let sectionGap: CGFloat = 32
    static let itemGap   : CGFloat = 10

    // Typography
    static let heroSize  : CGFloat = 42
    static let bodySize  : CGFloat = 14
    static let labelSize : CGFloat = 10
    static let tagSize   : CGFloat = 10

    // Cards
    static let radius    : CGFloat = 16
    static let tagRadius : CGFloat = 6

    // Animation
    static let spring = Animation.spring(response: 0.55,
                                         dampingFraction: 0.82)
    static let ease   = Animation.easeOut(duration: 0.48)
    static func stagger(_ i: Int, base: Double = 0.12) -> Double {
        base + Double(i) * 0.06
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @EnvironmentObject var store: PlanStore

    @State private var currentPage    = 0
    @State private var showCreatePlan = false
    @State private var newPlanID      : UUID? = nil

    private let totalPages = 5

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.bottom, 4)

                TabView(selection: $currentPage) {
                    OBWelcomePage().tag(0)
                    OBRaceTypePage().tag(1)
                    OBMethodologyPage().tag(2)
                    OBFeaturesPage().tag(3)
                    OBReadyPage {
                        UINotificationFeedbackGenerator()
                            .notificationOccurred(.success)
                        DispatchQueue.main.asyncAfter(
                            deadline: .now() + 0.45) {
                            showCreatePlan = true
                        }
                    }.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.38), value: currentPage)

                if currentPage < totalPages - 1 {
                    bottomBar
                        .padding(.bottom, 48)
                        .transition(.opacity)
                } else {
                    Color.clear.frame(height: 136)
                }
            }
        }
        .sheet(isPresented: $showCreatePlan,
               onDismiss: {
                   store.pendingOpenPlanID = newPlanID
                   hasCompletedOnboarding  = true
               }) {
            CreatePlanView(onPlanCreated: { id in newPlanID = id })
                .environmentObject(store)
        }
    }

    // MARK: Top Bar

    private var topBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "figure.run")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(.tertiaryLabel))
                Text("MILE ZERO")
                    .font(.system(size: 10, weight: .semibold,
                                  design: .monospaced))
                    .foregroundColor(Color(.tertiaryLabel))
                    .kerning(3)
            }
            Spacer()
            if currentPage < totalPages - 1 {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.38)) {
                        currentPage = totalPages - 1
                    }
                } label: {
                    Text("Skip")
                        .font(.system(size: 14))
                        .foregroundColor(Color(.secondaryLabel))
                }
            }
        }
        .padding(.horizontal, OB.margin)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 24) {
            HStack(spacing: 5) {
                ForEach(0..<totalPages, id: \.self) { i in
                    Capsule()
                        .fill(i == currentPage
                              ? Color(.label)
                              : Color(.systemFill))
                        .frame(width: i == currentPage ? 20 : 6, height: 6)
                        .animation(OB.spring, value: currentPage)
                }
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.easeInOut(duration: 0.38)) {
                    currentPage = min(currentPage + 1, totalPages - 1)
                }
            } label: {
                Text(currentPage == 0 ? "Get Started" : "Continue")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Color(.label))
                    .cornerRadius(OB.radius)
            }
            .buttonStyle(OBPressStyle())
            .padding(.horizontal, OB.margin)
        }
    }
}

// MARK: - Press Button Style

struct OBPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(OB.spring, value: configuration.isPressed)
    }
}

// MARK: - Page 0: Welcome

struct OBWelcomePage: View {
    @State private var appeared   = false
    @State private var ringTrim   : CGFloat = 0
    @State private var iconBounce = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Spacer()

            ZStack {
                Circle()
                    .trim(from: 0, to: ringTrim)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "0A84FF").opacity(0.55),
                                Color(hex: "30D158").opacity(0.25)
                            ],
                            startPoint: .topLeading,
                            endPoint:   .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                    )
                    .frame(width: 176, height: 176)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.8).delay(0.4),
                               value: ringTrim)

                Circle()
                    .stroke(Color(.separator).opacity(0.4), lineWidth: 1)
                    .frame(width: 140, height: 140)

                Circle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 108, height: 108)

                HStack(spacing: 32) {
                    OBDistancePill(label: "13.1",
                                   sub:   "HALF",
                                   color: Color(hex: "30D158"))
                    OBDistancePill(label: "26.2",
                                   sub:   "FULL",
                                   color: Color(hex: "0A84FF"))
                }

                Image(systemName: "figure.run")
                    .font(.system(size: 28, weight: .ultraLight))
                    .foregroundColor(.primary)
                    .offset(y: iconBounce ? -5 : 0)
                    .animation(
                        .easeInOut(duration: 1.3)
                        .repeatForever(autoreverses: true)
                        .delay(0.6),
                        value: iconBounce)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.82)
            .animation(OB.spring.delay(0.1), value: appeared)

            Spacer().frame(height: 48)

            VStack(spacing: 12) {
                Text("Train with\npurpose.")
                    .font(.system(size: OB.heroSize, weight: .bold,
                                  design: .serif))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(OB.ease.delay(0.28), value: appeared)

                Text("Marathon and half marathon plans\nbuilt for real runners.")
                    .font(.system(size: OB.bodySize))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(OB.ease.delay(0.40), value: appeared)
            }
            .padding(.horizontal, 40)

            Spacer()
            Spacer()
            Spacer()
        }
        .onAppear {
            appeared   = true
            iconBounce = true
            ringTrim   = 0.80
        }
    }
}

private struct OBDistancePill: View {
    let label : String
    let sub   : String
    let color : Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(sub)
                .font(.system(size: 7, weight: .semibold, design: .monospaced))
                .foregroundColor(color.opacity(0.55))
                .kerning(1)
        }
    }
}

// MARK: - Page 1: Race Type

struct OBRaceTypePage: View {
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OBPageHeader(
                eyebrow:  "YOUR DISTANCE",
                headline: "Train for\nevery distance.",
                subtitle: "Half marathon to full marathon. Every level from first finish to PR.",
                appeared: appeared,
                delay:    0.08
            )

            Spacer().frame(height: OB.sectionGap)

            VStack(spacing: OB.itemGap + 4) {
                OBDistanceCard(
                    icon:        "figure.run.circle",
                    color:       Color(hex: "30D158"),
                    title:       "Half Marathon",
                    distance:    "13.1 miles",
                    description: "From your very first finish line to chasing a new PR. Beginner-friendly plans built for confidence.",
                    tags:        ["First Half", "Higdon", "Hansons"],
                    appeared:    appeared,
                    delay:       OB.stagger(0)
                )

                OBDistanceCard(
                    icon:        "figure.run",
                    color:       Color(hex: "0A84FF"),
                    title:       "Marathon",
                    distance:    "26.2 miles",
                    description: "Progressive, structured training from first marathon to Boston qualifier. Every methodology included.",
                    tags:        ["Higdon", "Hansons", "Pfitz"],
                    appeared:    appeared,
                    delay:       OB.stagger(1)
                )
            }
            .padding(.horizontal, OB.margin)

            Spacer()
        }
        .onAppear { appeared = true }
    }
}

private struct OBDistanceCard: View {
    let icon        : String
    let color       : Color
    let title       : String
    let distance    : String
    let description : String   // ← not 'body'
    let tags        : [String]
    let appeared    : Bool
    let delay       : Double

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.10))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(distance)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Text(description)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: OB.tagSize, weight: .medium,
                                      design: .monospaced))
                        .foregroundColor(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(color.opacity(0.08))
                        .cornerRadius(OB.tagRadius)
                }
            }
        }
        .padding(OB.cardPad)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(OB.radius)
        .overlay(
            RoundedRectangle(cornerRadius: OB.radius)
                .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
        )
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.97)
        .offset(y: appeared ? 0 : 12)
        .animation(OB.ease.delay(delay), value: appeared)
    }
}

// MARK: - Page 2: Methodology

struct OBMethodologyPage: View {
    @State private var appeared = false
    @State private var expanded : Int? = nil

    private struct Method: Identifiable {
        let id     : Int
        let icon   : String
        let color  : Color
        let name   : String
        let tag    : String
        let short  : String
        let detail : String
    }

    private let methods: [Method] = [
        .init(id: 0,
              icon:   "figure.run.circle.fill",
              color:  Color(hex: "30D158"),
              name:   "First Half",
              tag:    "BEGINNER · HALF MARATHON",
              short:  "Built for first-time racers.",
              detail: "Four days of running per week with conservative, confidence-building progression. Long runs top out at 11 miles. Finish strong."),
        .init(id: 1,
              icon:   "sun.max.fill",
              color:  Color(hex: "FF9F0A"),
              name:   "Higdon",
              tag:    "BEGINNER TO INTERMEDIATE",
              short:  "Simple, approachable progression.",
              detail: "The world's most widely used marathon program. Mostly easy running, long run as the centrepiece. Confidence builds week by week."),
        .init(id: 2,
              icon:   "bolt.fill",
              color:  Color(hex: "FF453A"),
              name:   "Hansons",
              tag:    "INTERMEDIATE TO ADVANCED",
              short:  "Structured training on tired legs.",
              detail: "Cumulative fatigue model. Long run capped at 16 miles. You always arrive at race day prepared — because you've trained tired."),
        .init(id: 3,
              icon:   "waveform.path.ecg",
              color:  Color(hex: "0A84FF"),
              name:   "Pfitzinger",
              tag:    "ADVANCED",
              short:  "High-mileage endurance preparation.",
              detail: "The gold standard for competitive marathon runners. Medium-long mid-week runs layer aerobic fitness over a demanding base."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OBPageHeader(
                eyebrow:  "COACHING APPROACH",
                headline: "Your coaching\nphilosophy.",
                subtitle: "Every plan is built around a proven methodology. You choose the fit.",
                appeared: appeared,
                delay:    0.08
            )

            Spacer().frame(height: OB.sectionGap)

            ScrollView(showsIndicators: false) {
                VStack(spacing: OB.itemGap) {
                    ForEach(methods) { m in
                        methodCard(m)
                    }
                }
                .padding(.horizontal, OB.margin)
                .padding(.bottom, 20)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [Color(.systemBackground).opacity(0),
                             Color(.systemBackground).opacity(0.7)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 32)
                .allowsHitTesting(false)
            }
        }
        .onAppear { appeared = true }
    }

    private func methodCard(_ m: Method) -> some View {
        let isOpen = expanded == m.id

        return Button {
            withAnimation(OB.spring) {
                expanded = isOpen ? nil : m.id
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(m.color.opacity(0.10))
                            .frame(width: 40, height: 40)
                        Image(systemName: m.icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(m.color)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(m.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        Text(m.short)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(.tertiaryLabel))
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                        .animation(OB.spring, value: isOpen)
                }
                .padding(OB.cardPad)

                if isOpen {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()
                            .padding(.horizontal, OB.cardPad)

                        Text(m.detail)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, OB.cardPad)

                        Text(m.tag)
                            .font(.system(size: OB.tagSize, weight: .semibold,
                                          design: .monospaced))
                            .foregroundColor(m.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(m.color.opacity(0.08))
                            .cornerRadius(OB.tagRadius)
                            .padding(.horizontal, OB.cardPad)
                            .padding(.bottom, OB.cardPad)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(OB.radius)
            .overlay(
                RoundedRectangle(cornerRadius: OB.radius)
                    .stroke(
                        isOpen
                            ? m.color.opacity(0.25)
                            : Color(.separator).opacity(0.5),
                        lineWidth: isOpen ? 1.0 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.97)
        .offset(y: appeared ? 0 : 10)
        .animation(OB.ease.delay(OB.stagger(m.id)), value: appeared)
    }
}

// MARK: - Page 3: Features

struct OBFeaturesPage: View {
    @State private var appeared = false

    private struct Feature {
        let icon        : String
        let color       : Color
        let title       : String
        let description : String   // ← not 'body'
    }

    private let features: [Feature] = [
        .init(icon:        "sun.max.fill",
              color:       Color(hex: "FF9F0A"),
              title:       "Today Dashboard",
              description: "Your workout, pace targets, and weekly position — always visible at a glance."),
        .init(icon:        "chart.bar.fill",
              color:       Color(hex: "0A84FF"),
              title:       "Training Arc",
              description: "Visualise your full training cycle from base building to race day."),
        .init(icon:        "speedometer",
              color:       Color(hex: "30D158"),
              title:       "Pace Calculator",
              description: "Every pace — easy, tempo, threshold — derived precisely from your goal time."),
        .init(icon:        "map.fill",
              color:       Color(hex: "BF5AF2"),
              title:       "Route Builder",
              description: "Plan, save, and export your running routes. Elevation profiles included."),
        .init(icon:        "star.fill",
              color:       Color(hex: "FF453A"),
              title:       "Milestone Moments",
              description: "Long run records, peak weeks, and training achievements celebrated automatically."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OBPageHeader(
                eyebrow:  "WHAT YOU GET",
                headline: "Everything you\nneed to train well.",
                subtitle: nil,
                appeared: appeared,
                delay:    0.08
            )

            Spacer().frame(height: OB.sectionGap)

            ScrollView(showsIndicators: false) {
                VStack(spacing: OB.itemGap) {
                    ForEach(features.indices, id: \.self) { i in
                        featureRow(features[i], delay: OB.stagger(i))
                    }
                }
                .padding(.horizontal, OB.margin)
                .padding(.bottom, 20)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [Color(.systemBackground).opacity(0),
                             Color(.systemBackground).opacity(0.7)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 32)
                .allowsHitTesting(false)
            }
        }
        .onAppear { appeared = true }
    }

    private func featureRow(_ f: Feature, delay: Double) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(f.color.opacity(0.10))
                    .frame(width: 42, height: 42)
                Image(systemName: f.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(f.color)
            }
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(f.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                Text(f.description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(OB.cardPad)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(OB.radius)
        .overlay(
            RoundedRectangle(cornerRadius: OB.radius)
                .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
        )
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.97)
        .offset(y: appeared ? 0 : 10)
        .animation(OB.ease.delay(delay), value: appeared)
    }
}

// MARK: - Page 4: Ready

struct OBReadyPage: View {
    let onLaunch: () -> Void

    @State private var appeared = false
    @State private var ringTrim : CGFloat = 0
    @State private var pulse    = false
    @State private var launched = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color(.systemFill), lineWidth: 1.5)
                    .frame(width: 188, height: 188)

                Circle()
                    .trim(from: 0, to: ringTrim)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "0A84FF"),
                                     Color(hex: "30D158")],
                            startPoint: .topLeading,
                            endPoint:   .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: 188, height: 188)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.8).delay(0.3),
                               value: ringTrim)

                Circle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 130, height: 130)
                    .scaleEffect(pulse ? 1.04 : 1.0)
                    .animation(
                        .easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true),
                        value: pulse)

                Image(systemName: launched ? "checkmark" : "figure.run")
                    .font(.system(size: 40, weight: .ultraLight))
                    .foregroundColor(launched
                                     ? Color(hex: "30D158") : .primary)
                    .animation(OB.spring, value: launched)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.80)
            .animation(OB.spring.delay(0.1), value: appeared)

            Spacer().frame(height: 48)

            VStack(spacing: 12) {
                Text("Your next starting line begins here.")
                    .font(.system(size: 34, weight: .bold,
                                  design: .serif))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(OB.ease.delay(0.36), value: appeared)

                Text("Build your first plan in minutes.")
                    .font(.system(size: OB.bodySize))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(OB.ease.delay(0.48), value: appeared)
            }
            .padding(.horizontal, 40)

            Spacer()
            Spacer()

            Button {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(OB.spring) { launched = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    onLaunch()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Create My Plan")
                        .font(.system(size: 16, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(Color(.systemBackground))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color(.label))
                .cornerRadius(OB.radius)
            }
            .buttonStyle(OBPressStyle())
            .padding(.horizontal, OB.margin)
            .padding(.bottom, 52)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(OB.ease.delay(0.60), value: appeared)
        }
        .onAppear {
            appeared = true
            ringTrim = 1.0
            pulse    = true
        }
    }
}

// MARK: - Shared Page Header

struct OBPageHeader: View {
    let eyebrow  : String
    let headline : String
    let subtitle : String?
    let appeared : Bool
    let delay    : Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow)
                .font(.system(size: OB.labelSize, weight: .semibold,
                              design: .monospaced))
                .foregroundColor(Color(.tertiaryLabel))
                .kerning(2)

            Text(headline)
                .font(.system(size: 36, weight: .bold, design: .serif))
                .foregroundColor(.primary)
                .lineSpacing(2)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: OB.bodySize))
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, OB.margin)
        .padding(.top, 8)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(OB.ease.delay(delay), value: appeared)
    }
}
