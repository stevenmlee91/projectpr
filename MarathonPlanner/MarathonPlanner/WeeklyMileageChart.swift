import SwiftUI
import Charts

// MARK: - Week Display State
// Single source of truth for ALL bar colors and legend entries.

private enum WeekDisplayState: CaseIterable {
    case past, current, upcoming, peak, taper, race

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
        case .current:  return "Now"
        case .upcoming: return "Future"
        case .peak:     return "Peak"
        case .taper:    return "Taper"
        case .race:     return "Race"
        }
    }
}

// MARK: - Chart Bar

struct ChartBar: Identifiable {
    let id          : UUID
    let weekNumber  : Int
    let miles       : Double   // planned — always the bar height
    let actualMiles : Double   // 0 if nothing logged yet
    let phase       : TrainingPhase
    let phaseLabel  : String
    let isCurrent   : Bool
    let isPast      : Bool
    let hasLogged   : Bool
}

// MARK: - Weekly Mileage Chart View

struct WeeklyMileageChartView: View {
    let plan           : SavedPlan
    let currentWeekNum : Int
    var onSelectWeek   : ((SavedWeek) -> Void)? = nil

    @State private var selectedWeekNum : Int? = nil
    @State private var animateChart    = false

    // MARK: Computed

    private var peakWeekNum: Int {
        TrainingPhaseEngine.peakWeekNumber(for: plan)
    }

    private var weekCount: Int { plan.weeks.count }

    private var hasAnyActual: Bool {
        plan.weeks.contains { $0.hasAnyActualMiles }
    }

    private var bars: [ChartBar] {
        plan.weeks.map { week in
            ChartBar(
                id:          week.id,
                weekNumber:  week.weekNumber,
                miles:       week.totalMiles,
                actualMiles: week.actualTotalMiles,
                phase:       week.phase,
                phaseLabel:  week.phaseLabel,
                isCurrent:   week.weekNumber == currentWeekNum,
                isPast:      week.weekNumber < currentWeekNum,
                hasLogged:   week.hasAnyActualMiles
            )
        }
    }

    /// Past and current weeks that have at least some actual mileage —
    /// used for the performance line and dots.
    private var loggedBars: [ChartBar] {
        bars.filter { ($0.isPast || $0.isCurrent) && $0.actualMiles > 0 }
    }

    private var selectedBar: ChartBar? {
        bars.first { $0.weekNumber == selectedWeekNum }
    }

    private var selectedWeek: SavedWeek? {
        guard let n = selectedWeekNum else { return nil }
        return plan.weeks.first { $0.weekNumber == n }
    }

    private var maxMiles: Double {
        let plannedPeak = plan.weeks.map { $0.totalMiles }.max() ?? 50
        let actualPeak  = plan.weeks.map { $0.actualTotalMiles }.max() ?? 0
        return max(plannedPeak, actualPeak) * 1.15
    }

    // MARK: Display State

    private func displayState(for bar: ChartBar) -> WeekDisplayState {
        if bar.phase == .race            { return .race    }
        if bar.isCurrent                 { return .current }
        if bar.weekNumber == peakWeekNum { return .peak    }
        if bar.isPast                    { return .past    }
        if bar.phase == .taper           { return .taper   }
        return .upcoming
    }

    // MARK: Actual Performance Color
    // Traffic-light scale: how close did actual come to the plan?

    private func actualColor(for bar: ChartBar) -> Color {
        guard bar.miles > 0 else { return Color(hex: "30D158") }
        let ratio = bar.actualMiles / bar.miles
        switch ratio {
        case 0.90...: return Color(hex: "30D158")  // on target or above
        case 0.70...: return Color(hex: "FF9F0A")  // slightly under
        default:      return Color(hex: "FF453A")  // significantly behind
        }
    }

    // MARK: Body

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
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) {
                animateChart = true
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TRAINING ARC")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
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
            }
        }
    }

    // MARK: Chart

    private var chart: some View {
        Chart {
            // ── Planned bars ──────────────────────────────────────────
            // The structural backbone of the plan. Ghosted for past and
            // current weeks where actual data exists so the performance
            // line and dots read as the primary signal.
            ForEach(bars) { bar in
                BarMark(
                    x: .value("Week", bar.weekNumber),
                    y: .value("Miles", animateChart ? bar.miles : 0)
                )
                .foregroundStyle(barColor(bar))
                .cornerRadius(4)
            }

            // ── Actual performance line ───────────────────────────────
            // A smooth Catmull-Rom spline connecting every logged week.
            // Only drawn when two or more weeks have data (one point
            // cannot form a line).
            if loggedBars.count > 1 {
                ForEach(loggedBars) { bar in
                    LineMark(
                        x: .value("Week", bar.weekNumber),
                        y: .value("Actual", animateChart ? bar.actualMiles : 0)
                    )
                    .foregroundStyle(Color.white.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1.5,
                                          lineCap:   .round,
                                          lineJoin:  .round))
                    .interpolationMethod(.catmullRom)
                }
            }

            // ── Actual performance dots ───────────────────────────────
            // One filled circle per logged week, drawn on top of the
            // planned bar and the connecting line.
            // Colour encodes ratio of actual ÷ planned:
            //   ● Green  ≥ 90%   — on target
            //   ● Amber  70–89%  — slightly under
            //   ● Red    < 70%   — significantly behind
            ForEach(loggedBars) { bar in
                PointMark(
                    x: .value("Week", bar.weekNumber),
                    y: .value("Actual", animateChart ? bar.actualMiles : 0)
                )
                .foregroundStyle(actualColor(for: bar))
                .symbolSize(selectedWeekNum == bar.weekNumber ? 90 : 52)
                .symbol(.circle)
            }
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
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    withAnimation { selectedWeekNum = nil }
                                }
                            }
                    )
            }
        }
        .frame(height: 160)
        .animation(.easeOut(duration: 0.7),
                   value: animateChart)
        .animation(.spring(response: 0.5, dampingFraction: 0.8),
                   value: bars.map { $0.actualMiles })
    }

    // MARK: Bar Color
    // Ghost the planned bar when actual data exists — line + dots carry
    // the performance story; the bar becomes the reference scale.

    private func barColor(_ bar: ChartBar) -> Color {
        if bar.weekNumber == selectedWeekNum { return Color.white }
        let state = displayState(for: bar)
        if (bar.isPast || bar.isCurrent) && bar.hasLogged {
            return state.color.opacity(0.22)
        }
        return state.color
    }

    // MARK: Selected Week Detail

    private func selectedDetail(bar: ChartBar, week: SavedWeek) -> some View {
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

                if bar.hasLogged {
                    let planned = week.totalMiles
                    let actual  = week.actualTotalMiles
                    let diff    = actual - planned
                    let aColor  = actualColor(for: bar)

                    HStack(spacing: 16) {
                        metricCell(label: "PLANNED",
                                   value: String(format: "%.0f mi", planned),
                                   color: .secondary)
                        metricCell(label: "ACTUAL",
                                   value: String(format: "%.0f mi", actual),
                                   color: aColor,
                                   bold:  true)
                        if abs(diff) > 0.5 {
                            metricCell(
                                label: "DIFF",
                                value: String(format: "%+.0f mi", diff),
                                color: diff >= 0
                                    ? Color(hex: "30D158")
                                    : Color(hex: "FF453A")
                            )
                        }
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f",
                            bar.hasLogged ? bar.actualMiles : bar.miles))
                    .font(.system(size: 28, weight: .thin,
                                  design: .monospaced))
                    .foregroundColor(bar.hasLogged ? actualColor(for: bar) : .primary)
                Text(bar.hasLogged ? "actual mi" : "planned mi")
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

    private func metricCell(label: String, value: String,
                             color: Color, bold: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
                .kerning(1)
            Text(value)
                .font(.system(size: 14,
                              weight: bold ? .semibold : .medium,
                              design: .monospaced))
                .foregroundColor(color)
        }
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

    // MARK: Legend
    // Row 1: bar phase colours (always shown).
    // Row 2: dot performance scale (shown only when Strava or manual
    //        data gives us at least one logged week to explain).

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                ForEach(WeekDisplayState.allCases, id: \.legendLabel) { state in
                    legendBarItem(color: state.color, label: state.legendLabel)
                }
                Spacer()
            }
            if hasAnyActual {
                HStack(spacing: 12) {
                    legendDotItem(color: Color(hex: "30D158"), label: "On target")
                    legendDotItem(color: Color(hex: "FF9F0A"), label: "Under")
                    legendDotItem(color: Color(hex: "FF453A"), label: "Behind")
                    Spacer()
                }
            }
        }
        .padding(.top, 2)
    }

    /// Filled square — matches the bar mark appearance.
    private func legendBarItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    /// Filled circle — mirrors the PointMark dot appearance.
    private func legendDotItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    // MARK: X Axis Values

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
