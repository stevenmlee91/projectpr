import SwiftUI

// MARK: - Milestone Overlay View

struct MilestoneOverlayView: View {
    let milestone  : Milestone
    let onDismiss  : () -> Void

    @State private var appeared       = false
    @State private var iconScale      : CGFloat = 0.3
    @State private var iconOpacity    : Double  = 0
    @State private var iconRotation   : Double  = -30
    @State private var ringScale      : CGFloat = 0.1
    @State private var ringOpacity    : Double  = 0
    @State private var textOpacity    : Double  = 0
    @State private var textOffset     : CGFloat = 20
    @State private var sublineOpacity : Double  = 0
    @State private var sublineOffset  : CGFloat = 16
    @State private var buttonOpacity  : Double  = 0
    @State private var buttonOffset   : CGFloat = 12
    @State private var shimmerPhase   : CGFloat = -1
    @State private var pulseScale     : CGFloat = 1.0
    @State private var particleAnims  : [ParticleState] = []

    private let accent: Color  = { milestone in milestone.accentColor }(Milestone.firstWorkoutCompleted)

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                Spacer()

                // Card
                VStack(spacing: 28) {

                    // Icon cluster
                    iconCluster

                    // Text
                    VStack(spacing: 10) {
                        Text(milestone.headline)
                            .font(.system(size: 28, weight: .light,
                                          design: .serif))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .opacity(textOpacity)
                            .offset(y: textOffset)

                        Text(milestone.subline)
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 8)
                            .opacity(sublineOpacity)
                            .offset(y: sublineOffset)
                    }

                    // Dismiss button
                    Button(action: dismiss) {
                        Text("Keep going")
                            .font(.system(size: 14, weight: .semibold,
                                          design: .monospaced))
                            .foregroundColor(milestone.accentColor)
                            .kerning(1)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(
                                milestone.accentColor.opacity(0.12)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        milestone.accentColor.opacity(0.3),
                                        lineWidth: 1)
                            )
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .opacity(buttonOpacity)
                    .offset(y: buttonOffset)
                }
                .padding(36)
                .frame(maxWidth: .infinity)

                Spacer()
            }

            // Particles
            ForEach(particleAnims) { p in
                ParticleView(state: p, accent: milestone.accentColor)
            }
        }
        .onAppear { runEntrance() }
    }

    // MARK: - Icon Cluster

    private var iconCluster: some View {
        ZStack {
            // Outer pulse ring
            Circle()
                .stroke(milestone.accentColor.opacity(0.15),
                        lineWidth: 1)
                .frame(width: 110, height: 110)
                .scaleEffect(pulseScale)
                .opacity(ringOpacity)

            // Middle ring
            Circle()
                .stroke(milestone.accentColor.opacity(0.25),
                        lineWidth: 1.5)
                .frame(width: 88, height: 88)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

            // Icon background
            Circle()
                .fill(milestone.accentColor.opacity(0.15))
                .frame(width: 72, height: 72)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

            // Icon
            Image(systemName: milestone.icon)
                .font(.system(size: 28, weight: .light))
                .foregroundColor(milestone.accentColor)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)
                .rotationEffect(.degrees(iconRotation))
        }
    }

    // MARK: - Animations

    private func runEntrance() {
        // Haptic
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        // Rings
        withAnimation(.spring(response: 0.55, dampingFraction: 0.65)) {
            ringScale   = 1.0
            ringOpacity = 1.0
        }

        // Icon
        withAnimation(.spring(response: 0.5,
                               dampingFraction: 0.55)
            .delay(0.08)) {
            iconScale    = 1.0
            iconOpacity  = 1.0
            iconRotation = 0
        }

        // Pulse ring — continuous
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeInOut(duration: 1.8)
                .repeatForever(autoreverses: true)) {
                pulseScale = 1.12
            }
        }

        // Headline
        withAnimation(.spring(response: 0.5,
                               dampingFraction: 0.72)
            .delay(0.22)) {
            textOpacity = 1.0
            textOffset  = 0
        }

        // Subline
        withAnimation(.spring(response: 0.5,
                               dampingFraction: 0.75)
            .delay(0.34)) {
            sublineOpacity = 1.0
            sublineOffset  = 0
        }

        // Button
        withAnimation(.spring(response: 0.45,
                               dampingFraction: 0.8)
            .delay(0.48)) {
            buttonOpacity = 1.0
            buttonOffset  = 0
        }

        // Particles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            spawnParticles()
        }
    }

    private func dismiss() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeIn(duration: 0.18)) {
            iconOpacity    = 0
            ringOpacity    = 0
            textOpacity    = 0
            sublineOpacity = 0
            buttonOpacity  = 0
            iconScale      = 0.8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }

    // MARK: - Particles

    private func spawnParticles() {
        particleAnims = (0..<14).map { i in
            ParticleState(
                id:    i,
                angle: Double(i) * (360.0 / 14.0)
                    + Double.random(in: -12...12),
                distance: CGFloat.random(in: 90...160),
                delay:    Double.random(in: 0...0.2),
                size:     CGFloat.random(in: 3...7)
            )
        }
    }
}

// MARK: - Particle

struct ParticleState: Identifiable {
    let id       : Int
    let angle    : Double
    let distance : CGFloat
    let delay    : Double
    let size     : CGFloat
}

struct ParticleView: View {
    let state  : ParticleState
    let accent : Color

    @State private var offset  : CGSize = .zero
    @State private var opacity : Double = 0
    @State private var scale   : CGFloat = 0

    var body: some View {
        Circle()
            .fill(accent.opacity(0.7))
            .frame(width: state.size, height: state.size)
            .scaleEffect(scale)
            .offset(offset)
            .opacity(opacity)
            .onAppear {
                let rad = state.angle * .pi / 180
                let dx  = cos(rad) * state.distance
                let dy  = sin(rad) * state.distance

                withAnimation(.spring(response: 0.6,
                                       dampingFraction: 0.7)
                    .delay(state.delay)) {
                    offset  = CGSize(width: dx, height: dy)
                    scale   = 1.0
                    opacity = 1.0
                }
                withAnimation(.easeOut(duration: 0.5)
                    .delay(state.delay + 0.35)) {
                    opacity = 0
                    scale   = 0.3
                }
            }
    }
}
