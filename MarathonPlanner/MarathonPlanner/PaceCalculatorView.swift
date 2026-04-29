import SwiftUI

// MARK: - Pace Calculator View

struct PaceCalculatorView: View {
    @State private var hours         = 3
    @State private var minutes       = 30
    @State private var useKilometers = false
    @State private var copied        = false

    private let presets: [(label: String, hours: Int, minutes: Int)] = [
        ("2:45", 2, 45), ("3:00", 3,  0), ("3:15", 3, 15),
        ("3:30", 3, 30), ("3:45", 3, 45), ("4:00", 4,  0),
        ("4:30", 4, 30), ("5:00", 5,  0),
    ]

    private var goalMinutes: Int { hours * 60 + minutes }

    // Uses the existing PaceEngine from TrainingPlan.swift
    private var engine: PaceEngine {
        PaceEngine(goalMinutes: goalMinutes)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        header
                        timePicker
                        presetRow
                        unitToggle
                        paceCards
                        treadmillSection
                        Spacer().frame(height: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("PACE CALCULATOR")
                        .font(.system(size: 12, weight: .semibold,
                                      design: .monospaced))
                        .foregroundColor(.secondary)
                        .kerning(3)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { copyAllPaces() } label: {
                        Image(systemName: copied
                              ? "checkmark" : "doc.on.doc")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Goal Time")
                .font(.system(size: 11, weight: .semibold,
                              design: .monospaced))
                .foregroundColor(.secondary)
                .kerning(3)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%d:%02d", hours, minutes))
                    .font(.system(size: 52, weight: .thin,
                                  design: .monospaced))
                    .foregroundColor(.primary)
                Text("marathon")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Time Picker

    private var timePicker: some View {
        ZStack {
            Color(.secondarySystemBackground)
            HStack(spacing: 0) {
                Picker("Hours", selection: $hours) {
                    ForEach(2...6, id: \.self) { h in
                        Text("\(h)h").tag(h)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                Text(":")
                    .font(.system(size: 28, weight: .thin,
                                  design: .monospaced))
                    .foregroundColor(.secondary)

                Picker("Minutes", selection: $minutes) {
                    ForEach([0,5,10,15,20,25,30,35,40,45,50,55],
                            id: \.self) { m in
                        Text(String(format: "%02d", m)).tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
            .frame(height: 110)
        }
        .cornerRadius(14)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Preset Row

    private var presetRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(presets, id: \.label) { preset in
                    let isSelected = hours == preset.hours
                                  && minutes == preset.minutes
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            hours   = preset.hours
                            minutes = preset.minutes
                        }
                    } label: {
                        Text(preset.label)
                            .font(.system(size: 12, weight: .semibold,
                                          design: .monospaced))
                            .foregroundColor(isSelected
                                             ? Color(.systemBackground)
                                             : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected
                                        ? Color(.label)
                                        : Color(.secondarySystemBackground))
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 20)
    }

    // MARK: - Unit Toggle

    private var unitToggle: some View {
        HStack {
            Text("PACES PER")
                .font(.system(size: 10, weight: .semibold,
                              design: .monospaced))
                .foregroundColor(.secondary)
                .kerning(2)
            Spacer()
            Picker("Unit", selection: $useKilometers) {
                Text("Mile").tag(false)
                Text("KM").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 130)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Pace Cards

    private var paceCards: some View {
        VStack(spacing: 10) {
            // Marathon Pace — hero card
            heroPaceCard(
                label:    "Marathon Pace",
                icon:     "flag.checkered",
                seconds:  engine.MP,
                subtitle: "Your goal race pace",
                color:    Color(hex: "0A84FF")
            )

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                paceCard(label: "Easy Run",
                         icon:  "figure.walk",
                         range: engine.easy,
                         color: Color(hex: "30D158"))

                paceCard(label: "Long Run",
                         icon:  "arrow.right.to.line",
                         range: engine.longRun,
                         color: Color(hex: "30D158"))

                paceCard(label: "Tempo",
                         icon:  "flame",
                         seconds: engine.higdonTempo,
                         color: Color(hex: "FF9F0A"))

                paceCard(label: "Threshold",
                         icon:  "bolt",
                         seconds: engine.pfitzLT,
                         color: Color(hex: "FF9F0A"))

                paceCard(label: "Intervals",
                         icon:  "repeat",
                         seconds: engine.dInterval,
                         color: Color(hex: "FF453A"))

                paceCard(label: "Recovery",
                         icon:  "moon",
                         seconds: engine.recovery,
                         color: Color(hex: "BF5AF2"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    // MARK: - Hero Card (single pace)

    private func heroPaceCard(label: String, icon: String,
                               seconds: Int, subtitle: String,
                               color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .light))
                .foregroundColor(color)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .semibold,
                                  design: .monospaced))
                    .foregroundColor(.secondary)
                    .kerning(2)
                Text(displaySingle(seconds))
                    .font(.system(size: 32, weight: .thin,
                                  design: .monospaced))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(useKilometers ? "/km" : "/mi")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.3), lineWidth: 1.5)
        )
        .cornerRadius(14)
    }

    // MARK: - Standard Pace Card (single)

    private func paceCard(label: String, icon: String,
                           seconds: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(color)
                Spacer()
                Text(useKilometers ? "/km" : "/mi")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Text(displaySingle(seconds))
                .font(.system(size: 22, weight: .thin, design: .monospaced))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }

    // MARK: - Standard Pace Card (range)

    private func paceCard(label: String, icon: String,
                           range: (low: Int, high: Int),
                           color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(color)
                Spacer()
                Text(useKilometers ? "/km" : "/mi")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Text(displayRange(range))
                .font(.system(size: 18, weight: .thin, design: .monospaced))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }

    // MARK: - Treadmill Section

    private var treadmillSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TREADMILL SPEEDS")
                .font(.system(size: 10, weight: .semibold,
                              design: .monospaced))
                .foregroundColor(.secondary)
                .kerning(3)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                treadmillRow(label: "Easy Run",
                             seconds: (engine.easy.low + engine.easy.high) / 2,
                             display: displayRange(engine.easy),
                             isLast: false)
                Divider().padding(.leading, 16)
                treadmillRow(label: "Marathon Pace",
                             seconds: engine.MP,
                             display: displaySingle(engine.MP),
                             isLast: false)
                Divider().padding(.leading, 16)
                treadmillRow(label: "Tempo",
                             seconds: engine.higdonTempo,
                             display: displaySingle(engine.higdonTempo),
                             isLast: false)
                Divider().padding(.leading, 16)
                treadmillRow(label: "Threshold",
                             seconds: engine.pfitzLT,
                             display: displaySingle(engine.pfitzLT),
                             isLast: true)
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    private func treadmillRow(label: String, seconds: Int,
                               display: String, isLast: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.primary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(mph(from: seconds)) mph")
                    .font(.system(size: 14, weight: .medium,
                                  design: .monospaced))
                    .foregroundColor(.primary)
                Text(display + "/mi")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Display Helpers

    // Format seconds to "M:SS"
    private func fmt(_ s: Int) -> String {
        let safe = max(s, 60)
        return String(format: "%d:%02d", safe / 60, safe % 60)
    }

    // Single pace — optionally converted to km
    private func displaySingle(_ seconds: Int) -> String {
        useKilometers ? fmt(toKmSeconds(seconds)) : fmt(seconds)
    }

    // Range pace — optionally converted to km
    private func displayRange(_ range: (low: Int, high: Int)) -> String {
        if useKilometers {
            return "\(fmt(toKmSeconds(range.high)))–\(fmt(toKmSeconds(range.low)))"
        }
        return "\(fmt(range.high))–\(fmt(range.low))"
    }

    // Convert seconds/mile to seconds/km
    private func toKmSeconds(_ secondsPerMile: Int) -> Int {
        Int(Double(secondsPerMile) / 1.60934)
    }

    // Treadmill MPH from seconds per mile
    private func mph(from secondsPerMile: Int) -> String {
        guard secondsPerMile > 0 else { return "—" }
        return String(format: "%.1f", 3600.0 / Double(secondsPerMile))
    }

    // MARK: - Copy

    private func copyAllPaces() {
        let unit = useKilometers ? "/km" : "/mi"
        let text = """
        Mile Zero — Pace Calculator
        Goal: \(String(format: "%d:%02d", hours, minutes)) Marathon

        Marathon Pace:  \(displaySingle(engine.MP))\(unit)
        Easy Run:       \(displayRange(engine.easy))\(unit)
        Long Run:       \(displayRange(engine.longRun))\(unit)
        Tempo:          \(displaySingle(engine.higdonTempo))\(unit)
        Threshold:      \(displaySingle(engine.pfitzLT))\(unit)
        Intervals:      \(displaySingle(engine.dInterval))\(unit)
        Recovery:       \(displaySingle(engine.recovery))\(unit)
        """
        UIPasteboard.general.string = text
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copied = false }
        }
    }
}
