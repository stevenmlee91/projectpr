import SwiftUI

// MARK: - Race Distance Mode

enum PaceCalculatorMode: String, CaseIterable {
    case marathon     = "Marathon"
    case halfMarathon = "Half Marathon"

    var label: String { rawValue }

    var icon: String {
        switch self {
        case .marathon:     return "figure.run"
        case .halfMarathon: return "figure.run.circle"
        }
    }

    var heroLabel: String {
        switch self {
        case .marathon:     return "Marathon Pace"
        case .halfMarathon: return "Half Marathon Pace"
        }
    }

    var heroSubtitle: String {
        switch self {
        case .marathon:     return "Your goal race pace"
        case .halfMarathon: return "Your goal half marathon pace"
        }
    }

    var treadmillRaceLabel: String {
        switch self {
        case .marathon:     return "Marathon Pace"
        case .halfMarathon: return "HM Pace"
        }
    }

    // Default hours for the picker
    var defaultHours: Int {
        switch self {
        case .marathon:     return 3
        case .halfMarathon: return 1
        }
    }

    var defaultMinutes: Int {
        switch self {
        case .marathon:     return 30
        case .halfMarathon: return 45
        }
    }

    var hourRange: [Int] {
        switch self {
        case .marathon:     return Array(2...6)
        case .halfMarathon: return Array(1...3)
        }
    }

    var presets: [(label: String, hours: Int, minutes: Int)] {
        switch self {
        case .marathon:
            return [
                ("2:45", 2, 45), ("3:00", 3,  0), ("3:15", 3, 15),
                ("3:30", 3, 30), ("3:45", 3, 45), ("4:00", 4,  0),
                ("4:30", 4, 30), ("5:00", 5,  0),
            ]
        case .halfMarathon:
            return [
                ("1:20", 1, 20), ("1:30", 1, 30), ("1:45", 1, 45),
                ("2:00", 2,  0), ("2:15", 2, 15), ("2:30", 2, 30),
            ]
        }
    }
}

// MARK: - Half Marathon Pace Engine
//
// Half marathon paces are faster than marathon paces for the same runner.
// We derive them from the HM goal time directly, using standard
// equivalency relationships between HM pace and training zones.

struct HalfMarathonPaceEngine {
    let goalMinutes: Int

    // Half marathon pace in seconds per mile
    var HMP: Int {
        Int(Double(goalMinutes) / 13.1 * 60)
    }

    // Easy: 60–90 sec slower than HMP
    var easy        : (low: Int, high: Int) { (HMP + 60, HMP + 90)  }

    // Long run: 45–75 sec slower than HMP
    var longRun     : (low: Int, high: Int) { (HMP + 45, HMP + 75)  }

    // Recovery: 90 sec slower than HMP
    var recovery    : Int                   { HMP + 90 }

    // Tempo / lactate threshold: ~10 sec faster than HMP
    var tempo       : Int                   { HMP - 10 }

    // Threshold: ~20 sec faster than HMP
    var threshold   : Int                   { HMP - 20 }

    // Intervals (5K effort): ~40 sec faster than HMP
    var intervals   : Int                   { HMP - 40 }

    // Speed / repetition: ~60 sec faster than HMP
    var speed       : Int                   { HMP - 60 }

    static func format(_ s: Int) -> String {
        let safe = max(s, 60)
        return String(format: "%d:%02d", safe / 60, safe % 60)
    }

    func rangeString(_ r: (low: Int, high: Int)) -> String {
        "\(HalfMarathonPaceEngine.format(r.high))–\(HalfMarathonPaceEngine.format(r.low))"
    }

    func singleString(_ s: Int) -> String {
        HalfMarathonPaceEngine.format(s)
    }
}

// MARK: - Pace Calculator View

struct PaceCalculatorView: View {
    @State private var mode          : PaceCalculatorMode = .marathon
    @State private var hours         = 3
    @State private var minutes       = 30
    @State private var useKilometers = false
    @State private var copied        = false

    private var goalMinutes: Int { hours * 60 + minutes }

    private var marathonEngine: PaceEngine {
        PaceEngine(goalMinutes: goalMinutes)
    }

    private var halfEngine: HalfMarathonPaceEngine {
        HalfMarathonPaceEngine(goalMinutes: goalMinutes)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        modeSelector
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
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        HStack(spacing: 8) {
            ForEach(PaceCalculatorMode.allCases, id: \.self) { m in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode    = m
                        hours   = m.defaultHours
                        minutes = m.defaultMinutes
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: m.icon)
                            .font(.system(size: 12, weight: .medium))
                        Text(m.label)
                            .font(.system(size: 12, weight: .semibold,
                                          design: .monospaced))
                    }
                    .foregroundColor(mode == m
                                     ? Color(.systemBackground)
                                     : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(mode == m
                                ? Color(.label)
                                : Color(.secondarySystemBackground))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
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
                Text(mode == .marathon ? "marathon" : "half marathon")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .animation(.none, value: mode)
    }

    // MARK: - Time Picker

    private var timePicker: some View {
        ZStack {
            Color(.secondarySystemBackground)
            HStack(spacing: 0) {
                Picker("Hours", selection: $hours) {
                    ForEach(mode.hourRange, id: \.self) { h in
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
                ForEach(mode.presets, id: \.label) { preset in
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
            if mode == .marathon {
                marathonPaceCards
            } else {
                halfMarathonPaceCards
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .animation(.easeInOut(duration: 0.25), value: mode)
    }

    // MARK: Marathon Cards

    private var marathonPaceCards: some View {
        VStack(spacing: 10) {
            heroPaceCard(
                label:    mode.heroLabel,
                icon:     "flag.checkered",
                seconds:  marathonEngine.MP,
                subtitle: mode.heroSubtitle,
                color:    Color(hex: "0A84FF")
            )

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                paceCard(label: "Easy Run",
                         icon:  "figure.walk",
                         range: marathonEngine.easy,
                         color: Color(hex: "30D158"))

                paceCard(label: "Long Run",
                         icon:  "arrow.right.to.line",
                         range: marathonEngine.longRun,
                         color: Color(hex: "30D158"))

                paceCard(label: "Tempo",
                         icon:  "flame",
                         seconds: marathonEngine.higdonTempo,
                         color: Color(hex: "FF9F0A"))

                paceCard(label: "Threshold",
                         icon:  "bolt",
                         seconds: marathonEngine.pfitzLT,
                         color: Color(hex: "FF9F0A"))

                paceCard(label: "Intervals",
                         icon:  "repeat",
                         seconds: marathonEngine.dInterval,
                         color: Color(hex: "FF453A"))

                paceCard(label: "Recovery",
                         icon:  "moon",
                         seconds: marathonEngine.recovery,
                         color: Color(hex: "BF5AF2"))
            }
        }
    }

    // MARK: Half Marathon Cards

    private var halfMarathonPaceCards: some View {
        VStack(spacing: 10) {
            heroPaceCard(
                label:    mode.heroLabel,
                icon:     "flag.checkered",
                seconds:  halfEngine.HMP,
                subtitle: mode.heroSubtitle,
                color:    Color(hex: "0A84FF")
            )

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                paceCard(label: "Easy Run",
                         icon:  "figure.walk",
                         range: halfEngine.easy,
                         color: Color(hex: "30D158"))

                paceCard(label: "Long Run",
                         icon:  "arrow.right.to.line",
                         range: halfEngine.longRun,
                         color: Color(hex: "30D158"))

                paceCard(label: "Tempo",
                         icon:  "flame",
                         seconds: halfEngine.tempo,
                         color: Color(hex: "FF9F0A"))

                paceCard(label: "Threshold",
                         icon:  "bolt",
                         seconds: halfEngine.threshold,
                         color: Color(hex: "FF9F0A"))

                paceCard(label: "Intervals",
                         icon:  "repeat",
                         seconds: halfEngine.intervals,
                         color: Color(hex: "FF453A"))

                paceCard(label: "Recovery",
                         icon:  "moon",
                         seconds: halfEngine.recovery,
                         color: Color(hex: "BF5AF2"))
            }
        }
    }

    // MARK: - Hero Card

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
                if mode == .marathon {
                    treadmillRow(label: "Easy Run",
                                 seconds: (marathonEngine.easy.low + marathonEngine.easy.high) / 2,
                                 display: displayRange(marathonEngine.easy),
                                 isLast: false)
                    Divider().padding(.leading, 16)
                    treadmillRow(label: mode.treadmillRaceLabel,
                                 seconds: marathonEngine.MP,
                                 display: displaySingle(marathonEngine.MP),
                                 isLast: false)
                    Divider().padding(.leading, 16)
                    treadmillRow(label: "Tempo",
                                 seconds: marathonEngine.higdonTempo,
                                 display: displaySingle(marathonEngine.higdonTempo),
                                 isLast: false)
                    Divider().padding(.leading, 16)
                    treadmillRow(label: "Threshold",
                                 seconds: marathonEngine.pfitzLT,
                                 display: displaySingle(marathonEngine.pfitzLT),
                                 isLast: true)
                } else {
                    treadmillRow(label: "Easy Run",
                                 seconds: (halfEngine.easy.low + halfEngine.easy.high) / 2,
                                 display: displayRange(halfEngine.easy),
                                 isLast: false)
                    Divider().padding(.leading, 16)
                    treadmillRow(label: mode.treadmillRaceLabel,
                                 seconds: halfEngine.HMP,
                                 display: displaySingle(halfEngine.HMP),
                                 isLast: false)
                    Divider().padding(.leading, 16)
                    treadmillRow(label: "Tempo",
                                 seconds: halfEngine.tempo,
                                 display: displaySingle(halfEngine.tempo),
                                 isLast: false)
                    Divider().padding(.leading, 16)
                    treadmillRow(label: "Threshold",
                                 seconds: halfEngine.threshold,
                                 display: displaySingle(halfEngine.threshold),
                                 isLast: true)
                }
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

    private func fmt(_ s: Int) -> String {
        let safe = max(s, 60)
        return String(format: "%d:%02d", safe / 60, safe % 60)
    }

    private func displaySingle(_ seconds: Int) -> String {
        useKilometers ? fmt(toKmSeconds(seconds)) : fmt(seconds)
    }

    private func displayRange(_ range: (low: Int, high: Int)) -> String {
        if useKilometers {
            return "\(fmt(toKmSeconds(range.high)))–\(fmt(toKmSeconds(range.low)))"
        }
        return "\(fmt(range.high))–\(fmt(range.low))"
    }

    private func toKmSeconds(_ secondsPerMile: Int) -> Int {
        Int(Double(secondsPerMile) / 1.60934)
    }

    private func mph(from secondsPerMile: Int) -> String {
        guard secondsPerMile > 0 else { return "—" }
        return String(format: "%.1f", 3600.0 / Double(secondsPerMile))
    }

    // MARK: - Copy

    private func copyAllPaces() {
        let unit      = useKilometers ? "/km" : "/mi"
        let raceLabel = mode == .marathon ? "Marathon" : "Half Marathon"
        let text: String

        if mode == .marathon {
            text = """
            Mile Zero — Pace Calculator
            Goal: \(String(format: "%d:%02d", hours, minutes)) \(raceLabel)

            \(raceLabel) Pace:  \(displaySingle(marathonEngine.MP))\(unit)
            Easy Run:          \(displayRange(marathonEngine.easy))\(unit)
            Long Run:          \(displayRange(marathonEngine.longRun))\(unit)
            Tempo:             \(displaySingle(marathonEngine.higdonTempo))\(unit)
            Threshold:         \(displaySingle(marathonEngine.pfitzLT))\(unit)
            Intervals:         \(displaySingle(marathonEngine.dInterval))\(unit)
            Recovery:          \(displaySingle(marathonEngine.recovery))\(unit)
            """
        } else {
            text = """
            Mile Zero — Pace Calculator
            Goal: \(String(format: "%d:%02d", hours, minutes)) \(raceLabel)

            HM Pace:    \(displaySingle(halfEngine.HMP))\(unit)
            Easy Run:   \(displayRange(halfEngine.easy))\(unit)
            Long Run:   \(displayRange(halfEngine.longRun))\(unit)
            Tempo:      \(displaySingle(halfEngine.tempo))\(unit)
            Threshold:  \(displaySingle(halfEngine.threshold))\(unit)
            Intervals:  \(displaySingle(halfEngine.intervals))\(unit)
            Recovery:   \(displaySingle(halfEngine.recovery))\(unit)
            """
        }

        UIPasteboard.general.string = text
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copied = false }
        }
    }
}
