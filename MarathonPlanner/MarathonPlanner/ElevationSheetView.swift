import SwiftUI
import Charts

// MARK: - Elevation Sheet State

enum ElevationSheetState {
    case idle
    case loading
    case loaded(ElevationProfile)
    case failed(String)
}

// MARK: - Elevation Bottom Sheet

struct ElevationSheetView: View {
    let segments    : [RouteSegment]
    let totalMiles  : Double
    @Binding var isPresented: Bool

    @State private var state: ElevationSheetState = .idle

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        switch state {
                        case .idle:
                            loadingView("Preparing elevation data...")
                        case .loading:
                            loadingView("Fetching elevation profile...")
                        case .loaded(let profile):
                            loadedView(profile)
                        case .failed(let message):
                            failedView(message)
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ELEVATION PROFILE")
                        .font(.system(size: 12, weight: .semibold,
                                      design: .monospaced))
                        .foregroundColor(.secondary)
                        .kerning(3)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { isPresented = false }
                        .foregroundColor(.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task { await loadElevation() }
    }

    // MARK: - Loaded View

    @ViewBuilder
    private func loadedView(_ profile: ElevationProfile) -> some View {
        VStack(spacing: 0) {

            // MARK: Distance + difficulty header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(String(format: "%.2f mi", totalMiles))
                        .font(.system(size: 32, weight: .thin,
                                      design: .monospaced))
                        .foregroundColor(.primary)
                    Text(String(format: "%.1f km",
                                totalMiles * 1.60934))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Spacer()
                difficultyBadge(profile.difficulty)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 20)

            // MARK: Stats row — all in feet
            HStack(spacing: 0) {
                elevationStat(
                    label: "GAIN",
                    value: String(format: "%.0f ft", profile.gainFeet),
                    sub:   String(format: "%.0f m", profile.gainM),
                    icon:  "arrow.up",
                    color: Color(hex: "30D158")
                )
                Divider().frame(height: 44)
                elevationStat(
                    label: "LOSS",
                    value: String(format: "%.0f ft", profile.lossFeet),
                    sub:   String(format: "%.0f m", profile.lossM),
                    icon:  "arrow.down",
                    color: Color(hex: "FF453A")
                )
                Divider().frame(height: 44)
                elevationStat(
                    label: "HIGH",
                    value: String(format: "%.0f ft", profile.highestFeet),
                    sub:   String(format: "%.0f m", profile.highestM),
                    icon:  "mountain.2.fill",
                    color: Color(hex: "FF9F0A")
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)
            .padding(.horizontal, 16)
            .padding(.bottom, 20)

            // MARK: Difficulty detail card
            difficultyDetailCard(profile)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)

            // MARK: Chart
            VStack(alignment: .leading, spacing: 10) {
                Text("ELEVATION PROFILE")
                    .font(.system(size: 10, weight: .semibold,
                                  design: .monospaced))
                    .foregroundColor(.secondary)
                    .kerning(3)
                    .padding(.horizontal, 4)

                if profile.points.isEmpty {
                    Text("Not enough data points to draw profile.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                } else {
                    ElevationChartView(profile: profile)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)

            // MARK: Naismith estimate
            naismithCard(profile)
        }
    }

    // MARK: - Difficulty Detail Card

    private func difficultyDetailCard(_ profile: ElevationProfile) -> some View {
        let d = profile.difficulty

        // Gain per mile for context
        let gainPerMile = totalMiles > 0
            ? profile.gainFeet / totalMiles
            : 0

        let description: String = {
            switch d {
            case .flat:
                return "Minimal climbing. Suitable for easy runs, recovery days, and speed work. Comparable to a track or flat road course."
            case .rolling:
                return "Gentle, manageable hills. Good for building strength without excessive fatigue. Suits most training runs."
            case .hilly:
                return "Significant climbing that will raise heart rate and slow your pace. Factor in extra time and effort. Good hill training stimulus."
            case .veryHilly:
                return "Demanding ascent. Expect considerable pace reduction and elevated effort. Ideal for hill training, not for tempo or race pace work."
            }
        }()

        return ZStack {
            Color(hex: d.color).opacity(0.06)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: d.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: d.color))
                    Text(d.rawValue.uppercased())
                        .font(.system(size: 13, weight: .bold,
                                      design: .monospaced))
                        .foregroundColor(Color(hex: d.color))
                        .kerning(2)
                    Spacer()
                    Text(String(format: "%.0f ft/mi", gainPerMile))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(hex: d.color))
                }

                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)

                // Difficulty scale bar
                difficultyScaleBar(d)
            }
            .padding(16)
        }
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: d.color).opacity(0.20), lineWidth: 1)
        )
    }

    // MARK: - Difficulty Scale Bar

    private func difficultyScaleBar(_ current: RouteDifficulty) -> some View {
        let levels: [RouteDifficulty] = [.flat, .rolling, .hilly, .veryHilly]

        return HStack(spacing: 4) {
            ForEach(levels, id: \.rawValue) { level in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(level == current
                              ? Color(hex: current.color)
                              : Color(.systemFill))
                        .frame(height: 5)
                    Text(level.rawValue)
                        .font(.system(size: 7, weight: .medium,
                                      design: .monospaced))
                        .foregroundColor(level == current
                                         ? Color(hex: current.color)
                                         : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Naismith Card

    private func naismithCard(_ profile: ElevationProfile) -> some View {
        let paces: [(label: String, secPerMile: Double)] = [
            ("Easy (9:00/mi)",     540),
            ("Moderate (8:00/mi)", 480),
            ("Fast (7:00/mi)",     420),
        ]

        return VStack(alignment: .leading, spacing: 12) {
            Text("ESTIMATED FINISH TIME")
                .font(.system(size: 10, weight: .semibold,
                              design: .monospaced))
                .foregroundColor(.secondary)
                .kerning(3)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(paces.indices, id: \.self) { i in
                    let pace  = paces[i]
                    let flat  = totalMiles * pace.secPerMile
                    // Naismith: add 1 min per 100 ft of ascent
                    let climb = (profile.gainFeet / 100) * 60
                    let total = flat + climb
                    let h     = Int(total) / 3600
                    let m     = (Int(total) % 3600) / 60

                    HStack {
                        Text(pace.label)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                        Spacer()
                        Text(h > 0
                             ? String(format: "%dh %02dm", h, m)
                             : String(format: "%dm", m))
                            .font(.system(size: 13, weight: .semibold,
                                          design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if i < paces.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Difficulty Badge

    private func difficultyBadge(_ difficulty: RouteDifficulty) -> some View {
        HStack(spacing: 6) {
            Image(systemName: difficulty.icon)
                .font(.system(size: 11, weight: .semibold))
            Text(difficulty.rawValue.uppercased())
                .font(.system(size: 11, weight: .bold,
                              design: .monospaced))
                .kerning(1)
        }
        .foregroundColor(Color(hex: difficulty.color))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(hex: difficulty.color).opacity(0.12))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: difficulty.color).opacity(0.30),
                        lineWidth: 1)
        )
    }

    // MARK: - Elevation Stat Cell

    private func elevationStat(label: String,
                                value: String,
                                sub:   String,
                                icon:  String,
                                color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 16, weight: .semibold,
                              design: .monospaced))
                .foregroundColor(.primary)
            Text(sub)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
            Text(label)
                .font(.system(size: 8, weight: .semibold,
                              design: .monospaced))
                .foregroundColor(.secondary)
                .kerning(2)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Loading View

    private func loadingView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color(hex: "0A84FF"))
            Text(message)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Failed View

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            Image(systemName: "mountain.2")
                .font(.system(size: 44, weight: .ultraLight))
                .foregroundColor(.secondary)
            Text("Elevation Unavailable")
                .font(.system(size: 18, weight: .light, design: .serif))
                .foregroundColor(.primary)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await loadElevation() }
            } label: {
                Text("Try Again")
                    .font(.system(size: 13, weight: .semibold,
                                  design: .monospaced))
                    .foregroundColor(Color(.systemBackground))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(.label))
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Load

    private func loadElevation() async {
        guard !segments.isEmpty else {
            state = .failed("No route segments to analyse.")
            return
        }
        state = .loading
        do {
            let profile = try await ElevationService.shared
                .fetchProfile(for: segments)
            state = .loaded(profile)
        } catch {
            state = .failed(
                error.localizedDescription.isEmpty
                    ? "Could not fetch elevation data. Check your connection and try again."
                    : error.localizedDescription
            )
        }
    }
}
