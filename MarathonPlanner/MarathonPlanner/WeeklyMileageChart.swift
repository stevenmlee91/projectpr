import SwiftUI
import Charts

// MARK: - Week Display State
// Single source of truth for ALL chart bar colors and legend entries.
// Both barColor() and the legend derive from this — never from separate sources.

private enum WeekDisplayState: CaseIterable {
    case past       // completed weeks
    case current    // this week
    case upcoming   // future base/build weeks — neutral
    case peak       // future peak week
    case taper      // future taper weeks
    case race       // race week

    // One color definition used by both bars AND legend
    var color: Color {
        switch self {
        case .past:     return Color(hex: "30D158")
        case .current:  return Color.white
        case .upcoming: return Color(.systemFill)
        case .peak:     return Color(hex: "FF453A")
        case .taper:    return Color(hex: "FF9F0A")
        case .race:     return Color.yellow
        }
    }

    var legendLabel: String {
        switch self {
        case .past:     return "Done"
        case .current:  return "This Week"
        case .upcoming: return "Future"
        case .peak:     return "Peak"
        case .taper:    return "Taper"
        case .race:     return "Race"
        }
    }
}

// MARK: - Chart Bar

struct ChartBar: Identifiable {
    let id         : UUID
    let weekNumber : Int
    let miles      : Double
    let phase      : TrainingPhase
    let phaseLabel : String
    let isCurrent  : Bool
    let isPast     : Bool
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

    private var totalWeeks: Int { plan.weeks.count }

    private var peakWeekNum: Int {
        TrainingPhaseEngine.peakWeekNumber(for: plan)
    }

    private var hasAnyLoggedData: Bool {
        plan.weeks.contains { $0.hasAnyActualMiles }
    }

    private var bars: [ChartBar] {
        plan.weeks.map { week in
            let miles: Double = showingActual
                ? week.actualTotalMiles
                : week.totalMiles

            return ChartBar(
                id:         week.id,
                weekNumber: week.weekNumber,
                miles:      miles,
                phase:      week.phase,
                phaseLabel: week.phaseLabel,
                isCurrent:  week.weekNumber == currentWeekNum,
                isPast:     week.weekNumber < currentWeekNum,
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

    // MARK: - Display State
    // The ONLY place where a bar's visual state is computed.
    // Both barColor() and selectedDetail() use this.

    // AFTER:
    private func displayState(for bar: ChartBar) -> WeekDisplayState {
        // Race week: always yellow — checked first, absolute
        if bar.phase == .race    { return .race    }
        // Current week: always white highlight
        if bar.isCurrent         { return .current }
        // Peak week: always red — a permanent milestone, past or future
        // Uses mileage-derived peakWeekNum so old plans work too
        if bar.weekNumber == peakWeekNum { return .peak }
        // Past weeks: completed green
        if bar.isPast            { return .past    }
        // Future weeks: phase-aware
        if bar.phase == .taper   { return .taper  }
        return .upcoming
    }

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

                if hasAnyLoggedData {
                    HStack(spacing: 0) {
                        toggleButton(label: "Planned",
                                     active: !showingActual) {
                            showingActual = false
                        }
                        toggleButton(label: "Actual",
                                     active: showingActual) {
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
                .font(.system(size: 11,
                              weight: active ? .semibold : .regular,
                              design: .monospaced))
                .foregroundColor(active
                                 ? Color(.systemBackground)
                                 : .secondary)
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
            AxisMarks(preset: .aligned,
                      values: xAxisValues()) { value in
                if let wk = value.as(Int.self) {
                    AxisValueLabel(anchor: .top) {
                        Text("\(wk)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(
                                wk == currentWeekNum
                                    ? .primary : .secondary
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
                                let origin =
                                    geo[proxy.plotAreaFrame].origin
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
                                    withAnimation {
                                        selectedWeekNum = nil
                                    }
                                }
                            }
                    )
            }
        }
        .frame(height: 160)
        .animation(.easeOut(duration: 0.5),   value: animateChart)
        .animation(.easeInOut(duration: 0.3), value: showingActual)
    }

    // MARK: - Bar Color
    // All color logic flows through displayState() → WeekDisplayState.color.
    // Two overrides: unlogged actual bars fade out; selected bar highlights white.

    private func barColor(_ bar: ChartBar) -> Color {
        if showingActual && !bar.hasLogged && !bar.isPast {
            return Color(.systemFill).opacity(0.2)
        }
        if bar.weekNumber == selectedWeekNum { return Color.white }
        return displayState(for: bar).color
    }

    // MARK: - Selected Week Detail

    private func selectedDetail(bar: ChartBar,
                                 week: SavedWeek) -> some View {
        let state = displayState(for: bar)

        return HStack(spacing: 0) {
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
                    switch state {
                    case .peak, .taper, .race:
                        phaseBadge(state.legendLabel.uppercased(),
                                   fg: state == .taper || state == .race
                                       ? .black : .white,
                                   bg: state.color)
                    default:
                        EmptyView()
                    }
                }

                Text(bar.phaseLabel)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

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

    private func phaseBadge(_ label: String,
                              fg: Color,
                              bg: Color) -> some View {
        Text(label)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundColor(fg)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(bg)
            .cornerRadius(4)
    }

    // MARK: - Legend
    // Generated directly from WeekDisplayState.allCases.
    // Impossible for legend and bars to show different colors.

    private var legend: some View {
        HStack(spacing: 14) {
            ForEach(WeekDisplayState.allCases, id: \.legendLabel) { state in
                legendItem(color: state.color, label: state.legendLabel)
            }
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
        var values = stride(from: 1, through: weekCount,
                            by: step).map { $0 }
        if !values.contains(currentWeekNum) {
            values.append(currentWeekNum)
        }
        if !values.contains(weekCount) {
            values.append(weekCount)
        }
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
