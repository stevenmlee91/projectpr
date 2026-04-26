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

    // Priority order when multiple states overlap:
    // race > peak > taper > current > past > future
    var color: Color {
        switch self {
        case .past:    return Color(hex: "2E7D52")   // muted green — completed
        case .current: return Color.white              // white — you are here
        case .peak:    return Color(hex: "FF453A")    // red — peak effort
        case .taper:   return Color(hex: "FF9F0A")    // amber — taper
        case .race:    return Color.yellow             // yellow — race week
        case .future:  return Color(hex: "1E3A2A")    // dark green — upcoming
        }
    }

    var dimmedColor: Color {
        switch self {
        case .peak:  return Color(hex: "FF453A").opacity(0.3)
        case .taper: return Color(hex: "FF9F0A").opacity(0.3)
        case .race:  return Color.yellow.opacity(0.35)
        default:     return Color(hex: "1E3A2A")
        }
    }
}

// MARK: - Chart Data Point

struct MileagePoint: Identifiable {
    let id         : UUID
    let weekNumber : Int
    let miles      : Double
    let phase      : ChartPhase
    let phaseLabel : String
    let isCurrent  : Bool
    let isSelected : Bool

    var barColor: Color {
        // Selected always overrides
        if isSelected { return Color.white.opacity(0.9) }

        // Priority: race > peak > taper > current > past > future
        switch phase {
        case .race:    return Color.yellow
        case .peak:    return Color(hex: "FF453A")
        case .taper:   return Color(hex: "FF9F0A")
        case .current: return Color.white
        case .past:    return Color(hex: "2E7D52")
        case .future:  return Color(hex: "1E3A2A")
        }
    }
}

// MARK: - Phase Detection

private func detectPhase(
    week: SavedWeek,
    currentWeekNum: Int,
    peakWeekNum: Int
) -> ChartPhase {
    let phase = week.phase.lowercased()

    // Race week — check first
    if phase.contains("race") {
        return .race
    }

    // Taper — explicit phase label
    if phase.contains("taper") {
        return week.weekNumber < currentWeekNum ? .past : .taper
    }

    // Peak — explicit phase label OR is the highest mileage week
    if phase.contains("peak") || week.weekNumber == peakWeekNum {
        return week.weekNumber < currentWeekNum ? .past : .peak
    }

    // Current week
    if week.weekNumber == currentWeekNum {
        return .current
    }

    // Past
    if week.weekNumber < currentWeekNum {
        return .past
    }

    // Future build
    return .future
}

// MARK: - Weekly Mileage Chart View

struct WeeklyMileageChartView: View {
    let plan           : SavedPlan
    let currentWeekNum : Int
    var onSelectWeek   : ((SavedWeek) -> Void)? = nil

    @State private var selectedWeekNum : Int? = nil
    @State private var animateChart            = false

    // The true peak is the non-race, non-taper week with highest mileage
    private var peakWeekNum: Int {
        plan.weeks
            .filter { week in
                let p = week.phase.lowercased()
                return !p.contains("race") && !p.contains("taper")
            }
            .max { $0.totalMiles < $1.totalMiles }?
            .weekNumber ?? 1
    }

    private var chartData: [MileagePoint] {
        plan.weeks.map { week in
            let phase = detectPhase(
                week:           week,
                currentWeekNum: currentWeekNum,
                peakWeekNum:    peakWeekNum
            )
            return MileagePoint(
                id:         week.id,
                weekNumber: week.weekNumber,
                miles:      week.totalMiles,
                phase:      phase,
                phaseLabel: week.phase,
                isCurrent:  week.weekNumber == currentWeekNum,
                isSelected: week.weekNumber == selectedWeekNum
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
        .background(Color(hex: "1A1A1A"))
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
                .foregroundColor(Color(hex: "5E5E5E"))
                .kerning(3)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Week \(currentWeekNum)")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                Text("of \(plan.weeks.count)")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "5E5E5E"))
                Spacer()
                currentPhaseChip
            }
        }
    }

    private var currentPhaseChip: some View {
        let point = chartData.first { $0.isCurrent }
        let label = point?.phaseLabel.uppercased() ?? "TRAINING"
        let color = point?.barColor ?? Color(hex: "30D158")
        return Text(label)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .cornerRadius(6)
    }

    // MARK: - Chart

    private var chart: some View {
        Chart(chartData) { point in
            BarMark(
                x: .value("Week", point.weekNumber),
                y: .value("Miles", animateChart ? point.miles : 0)
            )
            .foregroundStyle(point.barColor)
            .cornerRadius(3)
        }
        .chartXAxis {
            AxisMarks(values: xAxisValues()) { value in
                if let wk = value.as(Int.self) {
                    AxisValueLabel {
                        Text("\(wk)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(
                                wk == currentWeekNum
                                    ? .white
                                    : Color(hex: "3A3A3A")
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
                            .foregroundColor(Color(hex: "3A3A3A"))
                    }
                    AxisGridLine()
                        .foregroundStyle(Color(hex: "222222"))
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
                                    deadline: .now() + 3
                                ) {
                                    withAnimation { selectedWeekNum = nil }
                                }
                            }
                    )
            }
        }
        .frame(height: 150)
        .animation(.easeOut(duration: 0.8), value: animateChart)
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
                        .foregroundColor(.white)

                    // Phase badges
                    if point.isCurrent {
                        phaseBadge(label: "YOU ARE HERE",
                                   fg: .black,
                                   bg: Color.white)
                    }
                    if point.phase == .peak {
                        phaseBadge(label: "PEAK",
                                   fg: .white,
                                   bg: Color(hex: "FF453A"))
                    }
                    if point.phase == .taper {
                        phaseBadge(label: "TAPER",
                                   fg: .black,
                                   bg: Color(hex: "FF9F0A"))
                    }
                    if point.phase == .race {
                        phaseBadge(label: "RACE",
                                   fg: .black,
                                   bg: Color.yellow)
                    }
                }
                Text(point.phaseLabel)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "5E5E5E"))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f", point.miles))
                    .font(.system(size: 28, weight: .thin,
                                  design: .monospaced))
                    .foregroundColor(point.barColor)
                Text("miles")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(hex: "5E5E5E"))
            }

            if onSelectWeek != nil {
                Button {
                    onSelectWeek?(week)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "5E5E5E"))
                        .padding(.leading, 14)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(hex: "242424"))
        .cornerRadius(10)
    }

    private func phaseBadge(label: String, fg: Color, bg: Color) -> some View {
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
            Group {
                legendDot(color: Color(hex: "2E7D52"), label: "Done")
                Spacer()
                legendDot(color: Color.white, label: "Now")
                Spacer()
                legendDot(color: Color(hex: "FF453A"), label: "Peak")
            }
            Group {
                Spacer()
                legendDot(color: Color(hex: "FF9F0A"), label: "Taper")
                Spacer()
                legendDot(color: Color.yellow, label: "Race")
                Spacer()
                legendDot(color: Color(hex: "1E3A2A"), label: "Ahead")
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
                .foregroundColor(Color(hex: "4A4A4A"))
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color(hex: "4A4A4A"))
        }
    }

    // MARK: - X Axis Values

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
                .foregroundColor(Color(hex: "2A2A2A"))
            Text("Generate a plan to see\nyour mileage progression.")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "3A3A3A"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color(hex: "1A1A1A"))
        .cornerRadius(16)
    }
}
