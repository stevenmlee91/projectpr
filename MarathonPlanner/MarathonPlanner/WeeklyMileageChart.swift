import SwiftUI
import Charts

// MARK: - Chart Phase

enum ChartPhase {
    case past
    case current
    case peak
    case taper
    case race
    case future
}

// MARK: - Chart Data Point

struct MileagePoint: Identifiable {
    let id         : UUID
    let weekNumber : Int
    let planned    : Double
    let actual     : Double      // 0 if week not started yet
    let phase      : ChartPhase
    let phaseLabel : String
    let isCurrent  : Bool
    let isSelected : Bool
    let hasLogged  : Bool        // true if user has touched any day this week

    // Color for the planned bar
    var plannedColor: Color {
        if isSelected { return Color(.systemFill) }
        switch phase {
        case .race:    return Color.yellow.opacity(barOpacity * 0.6)
        case .peak:    return Color(hex: "FF453A").opacity(barOpacity * 0.4)
        case .taper:   return Color(hex: "FF9F0A").opacity(barOpacity * 0.4)
        case .current: return Color(.systemFill)
        case .past:    return Color(.systemFill)
        case .future:  return Color(.systemFill).opacity(0.5)
        }
    }

    // Color for the actual bar
    var actualColor: Color {
        if isSelected { return Color.white }
        switch phase {
        case .race:    return Color.yellow.opacity(barOpacity)
        case .peak:    return Color(hex: "FF453A").opacity(barOpacity)
        case .taper:   return Color(hex: "FF9F0A").opacity(barOpacity)
        case .current: return Color.white
        case .past:    return Color(hex: "30D158")
        case .future:  return Color(.tertiaryLabel)
        }
    }

    private var barOpacity: Double {
        weekNumber <= 0 ? 0.3 : 1.0
    }
}

// MARK: - Phase Detection

private func detectPhase(
    week: SavedWeek,
    currentWeekNum: Int,
    peakWeekNum: Int
) -> ChartPhase {
    let phase = week.phase.lowercased()
    if phase.contains("race")   { return .race }
    if phase.contains("taper")  {
        return week.weekNumber < currentWeekNum ? .past : .taper
    }
    if phase.contains("peak") || week.weekNumber == peakWeekNum {
        return week.weekNumber < currentWeekNum ? .past : .peak
    }
    if week.weekNumber == currentWeekNum { return .current }
    if week.weekNumber < currentWeekNum  { return .past }
    return .future
}

// MARK: - Weekly Mileage Chart View

struct WeeklyMileageChartView: View {
    let plan           : SavedPlan
    let currentWeekNum : Int
    var onSelectWeek   : ((SavedWeek) -> Void)? = nil

    @State private var selectedWeekNum : Int?  = nil
    @State private var animateChart            = false
    @State private var showActual              = true

    private var peakWeekNum: Int {
        plan.weeks
            .filter { w in
                let p = w.phase.lowercased()
                return !p.contains("race") && !p.contains("taper")
            }
            .max { $0.totalMiles < $1.totalMiles }?
            .weekNumber ?? 1
    }

    private var chartData: [MileagePoint] {
        plan.weeks.map { week in
            let phase = detectPhase(week: week,
                                    currentWeekNum: currentWeekNum,
                                    peakWeekNum: peakWeekNum)
            return MileagePoint(
                id:         week.id,
                weekNumber: week.weekNumber,
                planned:    week.totalMiles,
                actual:     week.actualTotalMiles,
                phase:      phase,
                phaseLabel: week.phase,
                isCurrent:  week.weekNumber == currentWeekNum,
                isSelected: week.weekNumber == selectedWeekNum,
                hasLogged:  week.hasAnyActualMiles
            )
        }
    }

    private var selectedPoint: MileagePoint? {
        chartData.first { $0.weekNumber == selectedWeekNum }
    }

    private var selectedWeek: SavedWeek? {
        guard let n = selectedWeekNum else { return nil }
        return plan.weeks.first { $0.weekNumber == n }
    }

    // Whether any week has actual logged data to show
    private var hasAnyLoggedData: Bool {
        plan.weeks.contains { $0.hasAnyActualMiles }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            chart
            if let point = selectedPoint, let week = selectedWeek {
                selectedWeekDetail(point: point, week: week)
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
            withAnimation(.easeOut(duration: 0.8)) {
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
                Text("of \(plan.weeks.count)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Spacer()
                // Toggle between planned / actual view
                if hasAnyLoggedData {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showActual.toggle()
                        }
                    } label: {
                        Text(showActual ? "Actual" : "Planned")
                            .font(.system(size: 11, weight: .semibold,
                                          design: .monospaced))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                currentPhaseChip
            }
        }
    }

    private var currentPhaseChip: some View {
        let point = chartData.first { $0.isCurrent }
        let label = point?.phaseLabel.uppercased() ?? "TRAINING"
        let color = phaseChipColor(point?.phase ?? .current)
        return Text(label)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .cornerRadius(6)
    }

    private func phaseChipColor(_ phase: ChartPhase) -> Color {
        switch phase {
        case .taper, .race: return Color(hex: "FF9F0A")
        case .peak:         return Color(hex: "FF453A")
        default:            return Color(hex: "30D158")
        }
    }

    // MARK: - Chart

    private var chart: some View {
        Chart(chartData) { point in
            if showActual && hasAnyLoggedData {
                // Planned bar — lighter, behind
                BarMark(
                    x: .value("Week", point.weekNumber),
                    y: .value("Planned", animateChart ? point.planned : 0)
                )
                .foregroundStyle(point.plannedColor)
                .cornerRadius(3)

                // Actual bar — solid, in front
                // Only draw if week has been touched at all
                if point.hasLogged {
                    BarMark(
                        x: .value("Week", point.weekNumber),
                        y: .value("Actual", animateChart ? point.actual : 0)
                    )
                    .foregroundStyle(point.actualColor)
                    .cornerRadius(3)
                }
            } else {
                // Planned only view
                BarMark(
                    x: .value("Week", point.weekNumber),
                    y: .value("Miles", animateChart ? point.planned : 0)
                )
                .foregroundStyle(plannedOnlyColor(point))
                .cornerRadius(3)
            }
        }
        .chartXAxis {
            AxisMarks(values: xAxisValues()) { value in
                if let wk = value.as(Int.self) {
                    AxisValueLabel {
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
                    AxisValueLabel {
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
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let origin = geo[proxy.plotAreaFrame].origin
                                let x = value.location.x - origin.x
                                if let weekNum: Int = proxy.value(atX: x) {
                                    let clamped = max(1, min(weekNum,
                                                             plan.weeks.count))
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
        .animation(.easeOut(duration: 0.8), value: animateChart)
        .animation(.easeInOut(duration: 0.3), value: showActual)
    }

    private func plannedOnlyColor(_ point: MileagePoint) -> Color {
        if point.isSelected   { return Color.white }
        switch point.phase {
        case .race:    return Color.yellow
        case .peak:    return Color(hex: "FF453A")
        case .taper:   return Color(hex: "FF9F0A")
        case .current: return Color.white
        case .past:    return Color(hex: "30D158")
        case .future:  return Color(.systemFill)
        }
    }

    // MARK: - Selected Week Detail

    private func selectedWeekDetail(point: MileagePoint,
                                    week: SavedWeek) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("WEEK \(point.weekNumber)")
                        .font(.system(size: 11, weight: .bold,
                                      design: .monospaced))
                        .foregroundColor(.primary)

                    if point.isCurrent {
                        phaseBadge("NOW", fg: Color(.systemBackground),
                                   bg: Color(.label))
                    }
                    if point.phase == .peak {
                        phaseBadge("PEAK", fg: .white,
                                   bg: Color(hex: "FF453A"))
                    }
                    if point.phase == .taper {
                        phaseBadge("TAPER", fg: .black,
                                   bg: Color(hex: "FF9F0A"))
                    }
                    if point.phase == .race {
                        phaseBadge("RACE", fg: .black, bg: .yellow)
                    }
                }
                Text(point.phaseLabel)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                // Planned vs actual breakdown
                if point.hasLogged {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PLANNED")
                                .font(.system(size: 8, weight: .semibold,
                                              design: .monospaced))
                                .foregroundColor(.secondary)
                                .kerning(1)
                            Text(String(format: "%.0f mi", point.planned))
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
                            Text(String(format: "%.0f mi", point.actual))
                                .font(.system(size: 14, weight: .semibold,
                                              design: .monospaced))
                                .foregroundColor(Color(hex: "30D158"))
                        }
                        // Difference
                        if point.actual != point.planned {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("DIFF")
                                    .font(.system(size: 8, weight: .semibold,
                                                  design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .kerning(1)
                                let diff = point.actual - point.planned
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

            // Big mileage number
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f",
                            point.hasLogged ? point.actual : point.planned))
                    .font(.system(size: 28, weight: .thin,
                                  design: .monospaced))
                    .foregroundColor(.primary)
                Text(point.hasLogged ? "actual mi" : "planned mi")
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
        HStack(spacing: 0) {
            if hasAnyLoggedData && showActual {
                legendDot(color: Color(.systemFill),       label: "Planned")
                Spacer()
                legendDot(color: Color(hex: "30D158"),     label: "Actual")
                Spacer()
            }
            legendDot(color: Color(hex: "FF453A"), label: "Peak")
            Spacer()
            legendDot(color: Color(hex: "FF9F0A"), label: "Taper")
            Spacer()
            legendDot(color: Color.yellow,         label: "Race")
            if hasAnyLoggedData && showActual {
                Spacer()
                legendDot(color: Color(hex: "FF453A"), label: "Under")
            }
        }
        .padding(.top, 2)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - X Axis

    private func xAxisValues() -> [Int] {
        let total = plan.weeks.count
        let step  = total > 14 ? 4 : 2
        var values = stride(from: 1, through: total, by: step).map { $0 }
        if !values.contains(currentWeekNum) { values.append(currentWeekNum) }
        if !values.contains(total)          { values.append(total) }
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
