import SwiftUI
import Charts

// MARK: - Chart Phase

enum ChartPhase {
    case past, current, peak, taper, race, future
}

// MARK: - Phase Detection

private func detectPhase(week: SavedWeek,
                          currentWeekNum: Int,
                          peakWeekNum: Int) -> ChartPhase {
    let p = week.phase.lowercased()
    if p.contains("race")  { return .race }
    if p.contains("taper") { return week.weekNumber < currentWeekNum ? .past : .taper }
    if p.contains("peak") || week.weekNumber == peakWeekNum {
        return week.weekNumber < currentWeekNum ? .past : .peak
    }
    if week.weekNumber == currentWeekNum { return .current }
    if week.weekNumber < currentWeekNum  { return .past }
    return .future
}

// MARK: - Chart Bar

struct ChartBar: Identifiable {
    let id         : UUID
    let weekNumber : Int
    let miles      : Double
    let phase      : ChartPhase
    let phaseLabel : String
    let isCurrent  : Bool
    let hasLogged  : Bool
}

// MARK: - Weekly Mileage Chart View

struct WeeklyMileageChartView: View {
    let plan           : SavedPlan
    let currentWeekNum : Int
    var onSelectWeek   : ((SavedWeek) -> Void)? = nil

    @State private var showingActual   = false
    @State private var selectedWeekNum : Int? = nil
    @State private var animateChart    = false

    // MARK: - Computed

    private var peakWeekNum: Int {
        plan.weeks
            .filter {
                !$0.phase.lowercased().contains("race") &&
                !$0.phase.lowercased().contains("taper")
            }
            .max { $0.totalMiles < $1.totalMiles }?
            .weekNumber ?? 1
    }

    private var hasAnyLoggedData: Bool {
        plan.weeks.contains { $0.hasAnyActualMiles }
    }

    private var bars: [ChartBar] {
        plan.weeks.map { week in
            let phase = detectPhase(week: week,
                                    currentWeekNum: currentWeekNum,
                                    peakWeekNum: peakWeekNum)
            // In actual mode only show bars for weeks with logged data.
            // Weeks not yet started show 0 in actual mode.
            let miles: Double = showingActual
                ? week.actualTotalMiles
                : week.totalMiles

            return ChartBar(
                id:         week.id,
                weekNumber: week.weekNumber,
                miles:      miles,
                phase:      phase,
                phaseLabel: week.phase,
                isCurrent:  week.weekNumber == currentWeekNum,
                hasLogged:  week.hasAnyActualMiles
            )
        }
    }

    private var selectedBar: ChartBar? {
        bars.first { $0.weekNumber == selectedWeekNum }
    }

    private var selectedWeek: SavedWeek? {
        guard let n = selectedWeekNum else { return nil }
        return plan.weeks.first { $0.weekNumber == n }
    }

    private var maxMiles: Double {
        let peak = plan.weeks.map { $0.totalMiles }.max() ?? 50
        return peak * 1.15
    }

    private var weekCount: Int { plan.weeks.count }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            chart
            if let bar = selectedBar, let week = selectedWeek {
                selectedDetail(bar: bar, week: week)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                legend
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .animation(.easeInOut(duration: 0.2), value: selectedWeekNum)
        .animation(.easeInOut(duration: 0.25), value: showingActual)
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) {
                animateChart = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TRAINING ARC")
                .font(.system(size: 10, weight: .semibold,
                              design: .monospaced))
                .foregroundColor(.secondary)
                .kerning(3)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Week \(currentWeekNum)")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                Text("of \(weekCount)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Spacer()

                // Toggle — only shown once user has logged something
                if hasAnyLoggedData {
                    HStack(spacing: 0) {
                        toggleButton(label: "Planned", active: !showingActual) {
                            showingActual = false
                        }
                        toggleButton(label: "Actual", active: showingActual) {
                            showingActual = true
                        }
                    }
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
                }
            }
        }
    }

    private func toggleButton(label: String,
                               active: Bool,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: active ? .semibold : .regular,
                              design: .monospaced))
                .foregroundColor(active ? Color(.systemBackground) : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(active ? Color(.label) : Color.clear)
                .cornerRadius(7)
        }
        .buttonStyle(.plain)
        .padding(2)
    }

    // MARK: - Chart

    private var chart: some View {
        Chart(bars) { bar in
            BarMark(
                x: .value("Week", bar.weekNumber),
                y: .value("Miles", animateChart ? bar.miles : 0)
            )
            .foregroundStyle(barColor(bar))
            .cornerRadius(4)
        }
        .chartXScale(domain: 1...weekCount)
        .chartYScale(domain: 0...maxMiles)
        .chartXAxis {
            AxisMarks(preset: .aligned, values: xAxisValues()) { value in
                if let wk = value.as(Int.self) {
                    AxisValueLabel(anchor: .top) {
                        Text("\(wk)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(
                                wk == currentWeekNum ? .primary : .secondary
                            )
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading,
                      values: .automatic(desiredCount: 4)) { value in
                if let miles = value.as(Double.self) {
                    AxisValueLabel(horizontalSpacing: 12) {
                        Text("\(Int(miles))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    AxisGridLine()
                        .foregroundStyle(Color(.separator).opacity(0.4))
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let origin = geo[proxy.plotAreaFrame].origin
                                let x = value.location.x - origin.x
                                if let wk: Int = proxy.value(atX: x) {
                                    let clamped = max(1, min(wk, weekCount))
                                    if clamped != selectedWeekNum {
                                        selectedWeekNum = clamped
                                    }
                                }
                            }
                            .onEnded { _ in
                                DispatchQueue.main.asyncAfter(
                                    deadline: .now() + 3) {
                                    withAnimation { selectedWeekNum = nil }
                                }
                            }
                    )
            }
        }
        .frame(height: 160)
        .animation(.easeOut(duration: 0.5), value: animateChart)
        .animation(.easeInOut(duration: 0.3), value: showingActual)
    }

    // MARK: - Bar Color

    private func barColor(_ bar: ChartBar) -> Color {
        let isSelected = bar.weekNumber == selectedWeekNum

        if showingActual {
            // In actual mode — unstarted weeks are very faint
            if !bar.hasLogged { return Color(.systemFill).opacity(0.2) }
            if isSelected     { return Color.white }
            switch bar.phase {
            case .race:    return Color.yellow
            case .peak:    return Color(hex: "FF453A")
            case .taper:   return Color(hex: "FF9F0A")
            case .current: return Color.white
            case .past:    return Color(hex: "30D158")
            case .future:  return Color(hex: "30D158").opacity(0.5)
            }
        } else {
            // In planned mode
            if isSelected { return Color.white }
            switch bar.phase {
            case .race:    return Color.yellow
            case .peak:    return Color(hex: "FF453A")
            case .taper:   return Color(hex: "FF9F0A")
            case .current: return Color.white
            case .past:    return Color(hex: "30D158")
            case .future:  return Color(.systemFill)
            }
        }
    }

    // MARK: - Selected Week Detail

    private func selectedDetail(bar: ChartBar, week: SavedWeek) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("WEEK \(bar.weekNumber)")
                        .font(.system(size: 11, weight: .bold,
                                      design: .monospaced))
                        .foregroundColor(.primary)
                    if bar.isCurrent {
                        phaseBadge("NOW",
                                   fg: Color(.systemBackground),
                                   bg: Color(.label))
                    }
                    switch bar.phase {
                    case .peak:  phaseBadge("PEAK",  fg: .white, bg: Color(hex: "FF453A"))
                    case .taper: phaseBadge("TAPER", fg: .black, bg: Color(hex: "FF9F0A"))
                    case .race:  phaseBadge("RACE",  fg: .black, bg: .yellow)
                    default:     EmptyView()
                    }
                }

                Text(bar.phaseLabel)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                // Show both planned and actual side by side when in actual mode
                if showingActual && bar.hasLogged {
                    let planned = week.totalMiles
                    let actual  = week.actualTotalMiles
                    let diff    = actual - planned

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PLANNED")
                                .font(.system(size: 8, weight: .semibold,
                                              design: .monospaced))
                                .foregroundColor(.secondary)
                                .kerning(1)
                            Text(String(format: "%.0f mi", planned))
                                .font(.system(size: 14, weight: .medium,
                                              design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ACTUAL")
                                .font(.system(size: 8, weight: .semibold,
                                              design: .monospaced))
                                .foregroundColor(Color(hex: "30D158"))
                                .kerning(1)
                            Text(String(format: "%.0f mi", actual))
                                .font(.system(size: 14, weight: .semibold,
                                              design: .monospaced))
                                .foregroundColor(Color(hex: "30D158"))
                        }
                        if abs(diff) > 0.5 {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("DIFF")
                                    .font(.system(size: 8, weight: .semibold,
                                                  design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .kerning(1)
                                Text(String(format: "%+.0f mi", diff))
                                    .font(.system(size: 14, weight: .medium,
                                                  design: .monospaced))
                                    .foregroundColor(diff >= 0
                                                     ? Color(hex: "30D158")
                                                     : Color(hex: "FF453A"))
                            }
                        }
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f", bar.miles))
                    .font(.system(size: 28, weight: .thin,
                                  design: .monospaced))
                    .foregroundColor(.primary)
                Text(showingActual ? "actual mi" : "planned mi")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            if onSelectWeek != nil {
                Button { onSelectWeek?(week) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.leading, 14)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(10)
    }

    private func phaseBadge(_ label: String, fg: Color, bg: Color) -> some View {
        Text(label)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundColor(fg)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(bg)
            .cornerRadius(4)
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(color: Color(hex: "30D158"), label: "Past")
            legendItem(color: Color.white,          label: "Current")
            legendItem(color: Color(hex: "FF453A"), label: "Peak")
            legendItem(color: Color(hex: "FF9F0A"), label: "Taper")
            legendItem(color: Color.yellow,         label: "Race")
            Spacer()
        }
        .padding(.top, 2)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - X Axis Values

    private func xAxisValues() -> [Int] {
        let step   = weekCount > 14 ? 4 : 2
        var values = stride(from: 1, through: weekCount, by: step).map { $0 }
        if !values.contains(currentWeekNum) { values.append(currentWeekNum) }
        if !values.contains(weekCount)      { values.append(weekCount) }
        return values.sorted()
    }
}

// MARK: - Empty State

struct WeeklyMileageChartEmptyView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundColor(Color(.tertiaryLabel))
            Text("Generate a plan to see\nyour mileage progression.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}
