import SwiftUI

// MARK: - Onboarding View

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @EnvironmentObject var store: PlanStore

    @State private var currentPage    : Int  = 0
    @State private var showCreatePlan : Bool = false

    private let totalPages = 5

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                TabView(selection: $currentPage) {
                    WelcomePage()
                        .tag(0)
                    WhyMileZeroPage()
                        .tag(1)
                    HowItWorksPage()
                        .tag(2)
                    TrainingPhilosophyPage()
                        .tag(3)
                    ReadyPage(onLaunch: {
                        UINotificationFeedbackGenerator()
                            .notificationOccurred(.success)
                        DispatchQueue.main.asyncAfter(
                            deadline: .now() + 0.55) {
                            showCreatePlan = true
                        }
                    })
                    .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.35),
                           value: currentPage)

                // Bottom bar only shown on pages 0–3
                // Page 4 (ReadyPage) has its own CTA
                if currentPage < totalPages - 1 {
                    bottomBar
                        .padding(.bottom, 44)
                } else {
                    // Spacer to keep layout stable on last page
                    Color.clear
                        .frame(height: 130)
                }
            }
        }
        .sheet(isPresented: $showCreatePlan,
               onDismiss: { hasCompletedOnboarding = true }) {
            CreatePlanView()
                .environmentObject(store)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "figure.run")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("MILE ZERO")
                    .font(.system(size: 11, weight: .semibold,
                                  design: .monospaced))
                    .foregroundColor(.secondary)
                    .kerning(3)
            }
            Spacer()
            if currentPage < totalPages - 1 {
                Button("Skip") {
                    UIImpactFeedbackGenerator(style: .light)
                        .impactOccurred()
                    withAnimation(.easeInOut(duration: 0.35)) {
                        currentPage = totalPages - 1
                    }
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .padding(.top, 8)
    }

    // MARK: - Bottom Bar (pages 0–3 only)

    private var bottomBar: some View {
        VStack(spacing: 22) {

            // Progress dots
            HStack(spacing: 6) {
                ForEach(0..<totalPages, id: \.self) { i in
                    Capsule()
                        .fill(i == currentPage
                              ? Color.primary
                              : Color(.systemFill))
                        .frame(width: i == currentPage ? 24 : 7,
                               height: 7)
                        .animation(.spring(response: 0.3,
                                           dampingFraction: 0.7),
                                   value: currentPage)
                }
            }

            // CTA
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.easeInOut(duration: 0.35)) {
                    currentPage = min(currentPage + 1, totalPages - 1)
                }
            } label: {
                HStack(spacing: 8) {
                    Text(currentPage == 0 ? "Get Started" : "Continue")
                        .font(.system(size: 15, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(Color(.systemBackground))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color(.label))
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Page 0: Welcome

struct WelcomePage: View {
    @State private var appeared   = false
    @State private var iconBounce = false
    @State private var ringTrim   : CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animated icon cluster
            ZStack {
                Circle()
                    .trim(from: 0, to: ringTrim)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "0A84FF").opacity(0.7),
                                Color(hex: "30D158").opacity(0.35)
                            ],
                            startPoint: .topLeading,
                            endPoint:   .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 2,
                                           lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.5).delay(0.3),
                               value: ringTrim)

                Circle()
                    .stroke(Color(hex: "0A84FF").opacity(0.06),
                            lineWidth: 1)
                    .frame(width: 145, height: 145)

                Circle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 112, height: 112)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "0A84FF").opacity(0.10),
                                Color.clear
                            ],
                            center:      .center,
                            startRadius: 0,
                            endRadius:   55
                        )
                    )
                    .frame(width: 112, height: 112)

                Image(systemName: "figure.run")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(.primary)
                    .offset(y: iconBounce ? -6 : 0)
                    .animation(
                        .easeInOut(duration: 1.15)
                        .repeatForever(autoreverses: true)
                        .delay(0.6),
                        value: iconBounce
                    )
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.72)
            .animation(
                .spring(response: 0.7, dampingFraction: 0.7)
                .delay(0.1),
                value: appeared
            )
            .padding(.bottom, 48)

            // Copy
            VStack(spacing: 16) {
                Text("Mile Zero.\nEvery PR starts here.")
                    .font(.system(size: 30, weight: .bold,
                                  design: .serif))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.easeOut(duration: 0.55).delay(0.3),
                               value: appeared)

                Text("Every runner has a best race in them.\nThis is where you find yours.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 14)
                    .animation(.easeOut(duration: 0.55).delay(0.45),
                               value: appeared)

                // Accent line
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(Color(hex: "0A84FF").opacity(0.4))
                        .frame(width: 24, height: 1)
                    Text("MARATHON & HALF MARATHON PLANS")
                        .font(.system(size: 9, weight: .semibold,
                                      design: .monospaced))
                        .foregroundColor(.secondary)
                        .kerning(1.5)
                    Rectangle()
                        .fill(Color(hex: "0A84FF").opacity(0.4))
                        .frame(width: 24, height: 1)
                }
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.55).delay(0.6),
                           value: appeared)
            }
            .padding(.horizontal, 36)

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

// MARK: - Page 1: Why Mile Zero

struct WhyMileZeroPage: View {
    @State private var appeared = false

    private let pillars:
        [(icon: String, color: Color, title: String, body: String)] = [
        ("calendar.badge.clock",
         Color(hex: "0A84FF"),
         "Plans that flex to your life.",
         "Choose your rest days, quality sessions, and long run day. The plan adapts — not you."),
        ("sun.max.fill",
         Color(hex: "FF9F0A"),
         "Always know what to run.",
         "The Today dashboard shows your workout, pace targets, and where you stand in the week."),
        ("speedometer",
         Color(hex: "FF453A"),
         "Every pace, mathematically yours.",
         "Easy, tempo, threshold, intervals — all derived precisely from your goal finish time."),
        ("map.fill",
         Color(hex: "30D158"),
         "Routes built for runners.",
         "Plan courses, see elevation profiles, find water stops, and export GPX to your watch."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            VStack(alignment: .leading, spacing: 8) {
                Text("Built for runners\nwho are serious.")
                    .font(.system(size: 34, weight: .bold,
                                  design: .serif))
                    .foregroundColor(.primary)
                    .lineSpacing(2)
                Text("Train with structure. Improve with purpose.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(.easeOut(duration: 0.5).delay(0.1),
                       value: appeared)

            VStack(spacing: 10) {
                ForEach(pillars.indices, id: \.self) { i in
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(pillars[i].color.opacity(0.12))
                                .frame(width: 40, height: 40)
                            Image(systemName: pillars[i].icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(pillars[i].color)
                        }
                        .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(pillars[i].title)
                                .font(.system(size: 14,
                                              weight: .semibold))
                                .foregroundColor(.primary)
                            Text(pillars[i].body)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false,
                                           vertical: true)
                                .lineSpacing(2)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(14)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.45)
                        .delay(0.15 + Double(i) * 0.07),
                               value: appeared)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Page 2: How It Works

struct HowItWorksPage: View {
    @State private var appeared   = false
    @State private var barHeights : [CGFloat] = Array(repeating: 0,
                                                       count: 6)

    private let phases:
        [(label: String, color: Color, height: CGFloat)] = [
        ("BASE",  Color(hex: "30D158"), 0.35),
        ("BUILD", Color(hex: "0A84FF"), 0.52),
        ("BUILD", Color(hex: "0A84FF"), 0.68),
        ("PEAK",  Color(hex: "FF9F0A"), 0.92),
        ("TAPER", Color(hex: "BF5AF2"), 0.54),
        ("RACE",  Color(hex: "FF453A"), 0.38),
    ]

    private let legend:
        [(color: Color, title: String, description: String)] = [
        (Color(hex: "30D158"), "Base",
         "Build your aerobic engine"),
        (Color(hex: "0A84FF"), "Build",
         "Add mileage and quality sessions"),
        (Color(hex: "FF9F0A"), "Peak",
         "Your highest training weeks"),
        (Color(hex: "BF5AF2"), "Taper",
         "Sharpen and recover before race day"),
        (Color(hex: "FF453A"), "Race",
         "Everything you trained for"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            VStack(alignment: .leading, spacing: 8) {
                Text("Every week\nhas a purpose.")
                    .font(.system(size: 34, weight: .bold,
                                  design: .serif))
                    .foregroundColor(.primary)
                    .lineSpacing(2)
                Text("Mile Zero guides the full journey\nfrom first run to race day.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(.easeOut(duration: 0.5).delay(0.1),
                       value: appeared)

            // Bar chart
            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(phases.indices, id: \.self) { i in
                        VStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(phases[i].color.opacity(0.75))
                                .frame(height: barHeights[i])
                                .frame(maxWidth: .infinity)
                                .animation(
                                    .spring(response: 0.65,
                                            dampingFraction: 0.72)
                                    .delay(0.3 + Double(i) * 0.11),
                                    value: barHeights[i]
                                )
                            Text(phases[i].label)
                                .font(.system(size: 7, weight: .bold,
                                              design: .monospaced))
                                .foregroundColor(phases[i].color)
                                .kerning(0.3)
                                .opacity(appeared ? 1 : 0)
                                .animation(
                                    .easeOut(duration: 0.4)
                                    .delay(0.5 + Double(i) * 0.09),
                                    value: appeared
                                )
                        }
                    }
                }
                .onAppear {
                    let maxH = geo.size.height * 0.82
                    for i in phases.indices {
                        barHeights[i] = maxH * phases[i].height
                    }
                }
            }
            .frame(height: 120)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            // Legend
            VStack(spacing: 7) {
                ForEach(legend.indices, id: \.self) { i in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(legend[i].color)
                            .frame(width: 7, height: 7)
                        Text(legend[i].title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("·")
                            .foregroundColor(Color(.systemFill))
                        Text(legend[i].description)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(x: appeared ? 0 : 20)
                    .animation(.easeOut(duration: 0.4)
                        .delay(0.5 + Double(i) * 0.06),
                               value: appeared)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Page 3: Training Philosophies

struct TrainingPhilosophyPage: View {
    @State private var appeared  = false
    @State private var selected  : Int = -1

    private let philosophies:
        [(icon: String,
          color: Color,
          name: String,
          author: String,
          style: String,
          description: String)] = [
        (
            "waveform.path.ecg",
            Color(hex: "0A84FF"),
            "Pfitzinger",
            "Pete Pfitzinger",
            "High mileage · Serious runners",
            "The gold standard for competitive marathon runners. High weekly mileage with structured quality sessions. Trusted by athletes targeting PRs."
        ),
        (
            "bolt.fill",
            Color(hex: "FF9F0A"),
            "Hansons",
            "Hansons Running",
            "Cumulative fatigue · Race simulation",
            "Built on the concept of running on tired legs. Moderate mileage with a signature 16-mile long run. Proven to prepare you for the final miles."
        ),
        (
            "figure.run.circle",
            Color(hex: "30D158"),
            "Higdon",
            "Hal Higdon",
            "Accessible · Beginner friendly",
            "The most widely used marathon plan in the world. Approachable structure that builds confidence week over week. Perfect for first timers and returning runners."
        ),
        (
            "flame.fill",
            Color(hex: "BF5AF2"),
            "Jack Daniels",
            "Jack Daniels Ph.D.",
            "Scientific · VDOT based",
            "Scientifically derived training zones based on your VDOT score. Every pace has a precise physiological purpose. The coach's choice for optimised adaptation."
        ),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            VStack(alignment: .leading, spacing: 8) {
                Text("Your training\nphilosophy.")
                    .font(.system(size: 34, weight: .bold,
                                  design: .serif))
                    .foregroundColor(.primary)
                    .lineSpacing(2)
                Text("Mile Zero includes four proven methodologies.\nChoose your approach when you build your plan.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(.easeOut(duration: 0.5).delay(0.1),
                       value: appeared)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(philosophies.indices, id: \.self) { i in
                        let p       = philosophies[i]
                        let isOpen  = selected == i

                        Button {
                            withAnimation(.spring(response: 0.35,
                                                  dampingFraction: 0.75)) {
                                selected = isOpen ? -1 : i
                            }
                            UIImpactFeedbackGenerator(style: .light)
                                .impactOccurred()
                        } label: {
                            VStack(alignment: .leading, spacing: 0) {

                                // Header row
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(p.color.opacity(0.12))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: p.icon)
                                            .font(.system(size: 16,
                                                          weight: .medium))
                                            .foregroundColor(p.color)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(p.name)
                                            .font(.system(size: 14,
                                                          weight: .semibold))
                                            .foregroundColor(.primary)
                                        Text(p.style)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 11,
                                                      weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .rotationEffect(
                                            .degrees(isOpen ? 180 : 0))
                                        .animation(.spring(response: 0.3),
                                                   value: isOpen)
                                }
                                .padding(14)

                                // Expanded detail
                                if isOpen {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Divider()
                                            .padding(.horizontal, 14)

                                        Text(p.description)
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                            .lineSpacing(4)
                                            .fixedSize(horizontal: false,
                                                       vertical: true)
                                            .padding(.horizontal, 14)
                                            .padding(.bottom, 14)
                                    }
                                    .transition(.opacity.combined(
                                        with: .move(edge: .top)))
                                }
                            }
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(isOpen
                                            ? p.color.opacity(0.3)
                                            : Color.clear,
                                            lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(.easeOut(duration: 0.45)
                            .delay(0.15 + Double(i) * 0.07),
                                   value: appeared)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Page 4: Ready

struct ReadyPage: View {
    let onLaunch : () -> Void

    @State private var appeared  = false
    @State private var ringTrim  : CGFloat = 0
    @State private var pulse     = false
    @State private var launched  = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Completion ring
            ZStack {
                Circle()
                    .stroke(Color(.systemFill), lineWidth: 2)
                    .frame(width: 190, height: 190)

                Circle()
                    .trim(from: 0, to: ringTrim)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "0A84FF"),
                                Color(hex: "30D158")
                            ],
                            startPoint: .topLeading,
                            endPoint:   .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 2.5,
                                           lineCap: .round)
                    )
                    .frame(width: 190, height: 190)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.5).delay(0.3),
                               value: ringTrim)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "30D158").opacity(0.10),
                                Color.clear
                            ],
                            center:      .center,
                            startRadius: 0,
                            endRadius:   65
                        )
                    )
                    .frame(width: 130, height: 130)
                    .scaleEffect(pulse ? 1.08 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.6)
                        .repeatForever(autoreverses: true),
                        value: pulse
                    )

                Circle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 128, height: 128)

                Image(systemName: launched
                      ? "checkmark" : "figure.run")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(
                        launched ? Color(hex: "30D158") : .primary
                    )
                    .animation(.spring(response: 0.4), value: launched)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.72)
            .animation(
                .spring(response: 0.7, dampingFraction: 0.7)
                .delay(0.1),
                value: appeared
            )
            .padding(.bottom, 48)

            // Copy
            VStack(spacing: 14) {
                Text("You're ready\nto train.")
                    .font(.system(size: 40, weight: .bold,
                                  design: .serif))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.easeOut(duration: 0.55).delay(0.4),
                               value: appeared)

                Text("Build your first plan in under two minutes.\nEvery run from here moves you closer.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 14)
                    .animation(.easeOut(duration: 0.55).delay(0.55),
                               value: appeared)
            }
            .padding(.horizontal, 36)

            Spacer()

            // Single CTA — this page owns its own button
            // The bottom bar is hidden on this page
            Button {
                UINotificationFeedbackGenerator()
                    .notificationOccurred(.success)
                withAnimation(.spring(response: 0.4)) {
                    launched = true
                }
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + 0.55) {
                    onLaunch()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Build My Plan")
                        .font(.system(size: 15, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(Color(.systemBackground))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color(.label))
                .cornerRadius(16)
                .scaleEffect(launched ? 0.96 : 1.0)
                .animation(.spring(response: 0.3), value: launched)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
            .padding(.bottom, 52)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(.easeOut(duration: 0.55).delay(0.7),
                       value: appeared)
        }
        .onAppear {
            appeared = true
            ringTrim = 1.0
            pulse    = true
        }
    }
}
