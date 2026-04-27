import SwiftUI

// MARK: - Saved Plan View

struct SavedPlanView: View {
    let plan: SavedPlan
    @EnvironmentObject var store: PlanStore
    @State private var showingEdit    = false
    @State private var showShareSheet = false
    @State private var exportItems: [Any] = []

    private var livePlan: SavedPlan {
        store.plans.first { $0.id == plan.id } ?? plan
    }

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; return f
    }()

    private var overallCompletion: Double {
        guard let current = store.plans.first(where: { $0.id == plan.id })
        else { return 0 }
        let trackable = current.weeks
            .flatMap { $0.days }
            .filter { $0.workoutType != "Rest" }
        guard !trackable.isEmpty else { return 0 }
        let done = trackable.filter {
            $0.completionStatus == .completed || $0.completionStatus == .modified
        }.count
        return Double(done) / Double(trackable.count)
    }

    private var currentWeekNumber: Int {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        return livePlan.weeks.first { week in
            week.days.contains { cal.isDate($0.date, inSameDayAs: today) }
        }?.weekNumber ?? 1
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    planHeader
                    completionBanner
                    exportButtons
                    WeeklyMileageChartView(
                        plan:           livePlan,
                        currentWeekNum: currentWeekNumber
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                    weeksList
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingEdit = true } label: {
                    Image(systemName: "pencil").foregroundColor(.primary)
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditPlanView(plan: livePlan).environmentObject(store)
        }
        .sheet(isPresented: $showShareSheet) {
            SPVShareSheet(items: exportItems)
        }
    }

    // MARK: - Header

    private var planHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(livePlan.planType.uppercased())
                .font(.system(size: 10, weight: .semibold,
                              design: .monospaced))
                .foregroundColor(.secondary)
                .kerning(3)
            Text(livePlan.name)
                .font(.system(size: 28, weight: .light, design: .serif))
                .foregroundColor(.primary)
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("STARTS")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color(hex: "3E3E3E")).kerning(2)
                    Text(dateFormatter.string(from: livePlan.startDate))
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "9A9A9A"))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("RACE DAY")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color(hex: "3E3E3E")).kerning(2)
                    Text(dateFormatter.string(from: livePlan.raceDate))
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }

    // MARK: - Completion Banner

    private var completionBanner: some View {
        let pct = overallCompletion
        return ZStack {
            Color(.secondarySystemBackground)
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color(.tertiarySystemBackground), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: pct)
                        .stroke(Color(hex: "30D158"),
                                style: StrokeStyle(lineWidth: 4,
                                                   lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: pct)
                    Text("\(Int(pct * 100))%")
                        .font(.system(size: 11, weight: .semibold,
                                      design: .monospaced))
                        .foregroundColor(.primary)
                }
                .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text("TRAINING PROGRESS")
                        .font(.system(size: 10, weight: .semibold,
                                      design: .monospaced))
                        .foregroundColor(Color(hex: "3E3E3E"))
                        .kerning(2)
                    Text(progressLabel(pct))
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                }
                Spacer()
            }
            .padding(16)
        }
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private func progressLabel(_ pct: Double) -> String {
        switch pct {
        case 0:       return "Training starts here. You've got this."
        case ..<0.25: return "Early days — keep showing up."
        case ..<0.5:  return "Building momentum."
        case ..<0.75: return "Halfway there. Stay consistent."
        case ..<1.0:  return "Almost done. Taper strong."
        default:      return "Training complete. Race day ready."
        }
    }

    // MARK: - Export

    private var exportButtons: some View {
        HStack(spacing: 10) {
            SPVExportButton(label: "PDF",
                            icon:  "doc.richtext",
                            action: exportPDF)
            SPVExportButton(label: "CALENDAR",
                            icon:  "calendar.badge.plus",
                            action: exportCalendar)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    // MARK: - Weeks List

    private var weeksList: some View {
        VStack(spacing: 8) {
            ForEach(livePlan.weeks) { week in
                NavigationLink(value: WeekNavID(id: week.id)) {
                    SPVWeekRow(week: week)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }

    func exportPDF() {
        exportItems = [PDFExporter.exportPlan(livePlan)]
        showShareSheet = true
    }

    func exportCalendar() {
        exportItems = [ICSExporter.exportPlan(livePlan)]
        showShareSheet = true
    }
}

// MARK: - Export Button

struct SPVExportButton: View {
    let label  : String
    let icon   : String
    let action : () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 13))
                Text(label)
                    .font(.system(size: 11, weight: .semibold,
                                  design: .monospaced))
                    .kerning(1)
            }
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.tertiarySystemBackground), lineWidth: 1))
            .cornerRadius(10)
        }
    }
}

// MARK: - Week Row

struct SPVWeekRow: View {
    let week: SavedWeek

    private var isRaceWeek: Bool { week.phase.contains("Race Week") }

    private let shortDate: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()

    var weekStart: Date? { sortedDays(week.days).first?.date }
    var weekEnd:   Date? { sortedDays(week.days).last?.date  }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Text("Week \(week.weekNumber)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    if isRaceWeek {
                        Text("RACE WEEK")
                            .font(.system(size: 9, weight: .bold,
                                          design: .monospaced))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.yellow)
                            .cornerRadius(4)
                    }
                }
                Spacer()
                Text(String(format: "%.1f mi", week.totalMiles))
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
            }

            HStack {
                Text(week.phase)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(isRaceWeek
                                     ? Color.orange
                                     : .secondary)
                Spacer()
                if let s = weekStart, let e = weekEnd {
                    Text("\(shortDate.string(from: s)) – \(shortDate.string(from: e))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(.secondaryLabel))
                }
            }

            HStack(spacing: 5) {
                ForEach(sortedDays(week.days)) { day in
                    DotView(day: day)
                }
            }

            completionBar
        }
        .padding(16)
        .background(isRaceWeek
                    ? Color.yellow.opacity(0.08)
                    : Color(.secondarySystemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isRaceWeek ? Color.yellow.opacity(0.5) : Color.clear,
                        lineWidth: 1.5)
        )
        .cornerRadius(12)
    }

    private var completionBar: some View {
        let pct   = week.completionPercentage
        let done  = week.completedDayCount
        let total = week.trackableDayCount
        return VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.tertiarySystemBackground))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor(pct))
                        .frame(width: geo.size.width * pct, height: 4)
                        .animation(.easeInOut(duration: 0.3), value: pct)
                }
            }
            .frame(height: 4)
            Text("\(done) of \(total) workouts done")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(.secondaryLabel))
        }
    }

    private func barColor(_ pct: Double) -> Color {
        switch pct {
        case 1.0:    return Color(hex: "30D158")
        case 0.5...: return Color(hex: "0A84FF")
        default:     return Color(hex: "3A3A3A")
        }
    }

    func sortedDays(_ days: [SavedDay]) -> [SavedDay] {
        let order = ["Monday","Tuesday","Wednesday",
                     "Thursday","Friday","Saturday","Sunday"]
        return days.sorted { a, b in
            let i0 = order.firstIndex(of: a.weekday) ?? 7
            let i1 = order.firstIndex(of: b.weekday) ?? 7
            return i0 < i1
        }
    }
}

// MARK: - Dot View

struct DotView: View {
    let day: SavedDay

    var body: some View {
        ZStack {
            Circle()
                .fill(baseDotColor)
                .frame(width: 9, height: 9)
            if day.completionStatus == .completed
                || day.completionStatus == .modified {
                Circle()
                    .fill(Color(hex: "30D158"))
                    .frame(width: 9, height: 9)
            } else if day.completionStatus == .skipped {
                Circle()
                    .fill(Color(hex: "FF453A").opacity(0.6))
                    .frame(width: 9, height: 9)
            }
        }
    }

    var baseDotColor: Color {
        switch day.workoutType {
        case "Rest":                                   return Color(.tertiarySystemBackground)
        case "Recovery Run":                           return Color(hex: "34C759")
        case "Easy Run", "Easy + Strides",
             "Shakeout Run":                           return Color(hex: "30D158")
        case "Long Run", "Long Run w/ MP Finish",
             "Medium-Long Run", "Midweek Longer Run":  return Color(hex: "0A84FF")
        case "Tempo Run", "Strength (MP)",
             "Marathon Pace":                          return Color(hex: "FF9F0A")
        case "Lactate Threshold", "Cruise Intervals",
             "Speed Work", "Interval Work",
             "Repetition Work":                       return Color(hex: "FF453A")
        case "Cross-Training":                        return Color(hex: "BF5AF2")
        case "Race Day 🏁":                           return Color.yellow
        default:                                      return Color(.systemFill)
        }
    }
}

// MARK: - Week Detail View

struct SPVWeekDetailView: View {
    let planID : UUID
    let week   : SavedWeek
    @EnvironmentObject var store: PlanStore

    @State private var localWeek: SavedWeek

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"; return f
    }()

    init(planID: UUID, week: SavedWeek) {
        self.planID = planID
        self.week   = week
        _localWeek  = State(initialValue: week)
    }

    private var liveWeek: SavedWeek {
        store.plans
            .first { $0.id == planID }?
            .weeks.first { $0.id == week.id }
        ?? week
    }

    private var isRaceWeek: Bool {
        liveWeek.phase.contains("Race Week")
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 8) {
                    weekSummaryCard
                    ForEach(sortedDays(liveWeek.days)) { day in
                        if day.workoutType == "Race Day 🏁" {
                            SPVRaceDayRow(day: day,
                                         dateFormatter: dateFormatter)
                        } else {
                            SPVDayRow(day: day,
                                      planID: planID,
                                      weekID: liveWeek.id,
                                      dateFormatter: dateFormatter)
                                .environmentObject(store)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Week \(liveWeek.weekNumber)")
        .navigationBarTitleDisplayMode(.inline)

    }

    private var weekSummaryCard: some View {
        ZStack {
            Color(.secondarySystemBackground)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(liveWeek.phase)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(isRaceWeek
                                             ? .yellow : Color(.secondaryLabel))
                        if isRaceWeek {
                            Image(systemName: "flag.checkered")
                                .foregroundColor(.orange)
                                .font(.system(size: 12))
                        }
                    }
                    Text(String(format: "%.1f mi planned",
                                liveWeek.totalMiles))
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "3E3E3E"))
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color(.tertiarySystemBackground), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: liveWeek.completionPercentage)
                        .stroke(Color(hex: "30D158"),
                                style: StrokeStyle(lineWidth: 3,
                                                   lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3),
                                   value: liveWeek.completionPercentage)
                    Text("\(Int(liveWeek.completionPercentage * 100))%")
                        .font(.system(size: 10, weight: .semibold,
                                      design: .monospaced))
                        .foregroundColor(.primary)
                }
                .frame(width: 44, height: 44)
            }
            .padding(16)
        }
        .cornerRadius(12)
    }

    func sortedDays(_ days: [SavedDay]) -> [SavedDay] {
        let order = ["Monday","Tuesday","Wednesday",
                     "Thursday","Friday","Saturday","Sunday"]
        return days.sorted { a, b in
            let i0 = order.firstIndex(of: a.weekday) ?? 7
            let i1 = order.firstIndex(of: b.weekday) ?? 7
            return i0 < i1
        }
    }
}

// MARK: - Day Row

struct SPVDayRow: View {
    let day           : SavedDay
    let planID        : UUID
    let weekID        : UUID
    let dateFormatter : DateFormatter
    @EnvironmentObject var store: PlanStore

    @State private var showingActualMiles = false
    @State private var actualMilesInput   = ""
    @State private var showingNoteSheet   = false

    var dotColor: Color {
        switch day.workoutType {
        case "Rest":                                   return .gray
        case "Recovery Run":                           return Color(hex: "34C759")
        case "Easy Run", "Easy + Strides",
             "Shakeout Run":                           return Color(hex: "30D158")
        case "Long Run", "Long Run w/ MP Finish",
             "Medium-Long Run", "Midweek Longer Run":  return Color(hex: "0A84FF")
        case "Tempo Run", "Strength (MP)",
             "Marathon Pace":                          return Color(hex: "FF9F0A")
        case "Lactate Threshold", "Cruise Intervals",
             "Speed Work", "Interval Work",
             "Repetition Work":                       return Color(hex: "FF453A")
        case "Cross-Training":                        return Color(hex: "BF5AF2")
        default:                                      return Color(hex: "3A3A3A")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 10, height: 10)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(dateFormatter.string(from: day.date))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(day.isToday
                                             ? Color(hex: "0A84FF") : .primary)
                        if day.isToday {
                            Text("TODAY")
                                .font(.system(size: 9, weight: .bold,
                                              design: .monospaced))
                                .foregroundColor(.black)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color(hex: "0A84FF"))
                                .cornerRadius(3)
                        }
                        Spacer()
                        milesView
                    }

                    Text(day.workoutType)
                        .font(.system(size: 12))
                        .foregroundColor(completionColor ?? dotColor)

                    Text(day.description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if day.paceNote != "—" && !day.paceNote.isEmpty {
                        Text("Target: \(day.paceNote)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "0A84FF"))
                    }

                    // Note preview
                    if let note = day.completionNote, !note.isEmpty {
                        Button {
                            showingNoteSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "note.text")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text(note)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "6A6A6A"))
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity,
                                           alignment: .leading)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }

                completionButtons
                    .contentShape(Rectangle())
            }
            .padding(14)

            if day.completionStatus == .modified || showingActualMiles {
                actualMilesRow
            }
        }
        .background(rowBackground)
        .cornerRadius(12)
        .contentShape(Rectangle())
        .id(day.id)
        .sheet(isPresented: $showingNoteSheet) {
            NoteEditorSheet(
                day:    day,
                planID: planID,
                weekID: weekID
            )
            .environmentObject(store)
        }
    }

    private var milesView: some View {
        Group {
            if let actual = day.actualMiles,
               day.completionStatus == .modified {
                HStack(spacing: 4) {
                    Text(String(format: "%.1f", actual))
                        .foregroundColor(Color(hex: "30D158"))
                        .font(.system(size: 13, weight: .semibold))
                    Text("/ \(String(format: "%.1f", day.miles)) mi")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                }
            } else if day.miles > 0 {
                Text(String(format: "%.1f mi", day.miles))
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
            }
        }
    }

    private var completionButtons: some View {
        VStack(spacing: 4) {
            Button {
                let next: CompletionStatus =
                    day.completionStatus == .completed ? .notStarted : .completed
                store.updateCompletion(planID: planID, weekID: weekID,
                                       dayID: day.id, status: next)
                if next == .completed {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showingNoteSheet = true
                    }
                }
            } label: {
                Image(systemName: day.completionStatus == .completed
                      ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 26))
                    .foregroundColor(day.completionStatus == .completed
                                     ? Color(hex: "30D158")
                                     : Color(hex: "3A3A3A"))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                let next: CompletionStatus =
                    day.completionStatus == .skipped ? .notStarted : .skipped
                store.updateCompletion(planID: planID, weekID: weekID,
                                       dayID: day.id, status: next)
            } label: {
                Image(systemName: day.completionStatus == .skipped
                      ? "xmark.circle.fill" : "minus.circle")
                    .font(.system(size: 20))
                    .foregroundColor(day.completionStatus == .skipped
                                     ? Color(hex: "FF453A")
                                     : Color(hex: "3A3A3A"))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if day.miles > 0 {
                Button {
                    actualMilesInput = day.actualMiles
                        .map { String(format: "%.1f", $0) } ?? ""
                    showingActualMiles.toggle()
                } label: {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "3A3A3A"))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var actualMilesRow: some View {
        HStack(spacing: 12) {
            Text("Actual miles:")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            TextField("0.0", text: $actualMilesInput)
                .keyboardType(.decimalPad)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 60)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(6)
            Button("Save") {
                if let miles = Double(actualMilesInput) {
                    store.updateCompletion(planID: planID, weekID: weekID,
                                          dayID: day.id, status: .modified,
                                          actual: miles)
                }
                showingActualMiles = false
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Color(hex: "30D158"))
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }

    private var rowBackground: Color {
        switch day.completionStatus {
        case .completed:  return Color(.systemGreen).opacity(0.10)
        case .skipped:    return Color(.systemRed).opacity(0.08)
        case .modified:   return Color(.systemBlue).opacity(0.10)
        case .notStarted: return day.isToday
            ? Color(.systemBlue).opacity(0.08)
            : Color(.secondarySystemBackground)
        }
    }

    private var completionColor: Color? {
        switch day.completionStatus {
        case .completed:  return Color(hex: "30D158")
        case .skipped:    return Color(hex: "FF453A")
        case .modified:   return Color(hex: "0A84FF")
        case .notStarted: return nil
        }
    }
}

// MARK: - Note Editor Sheet
//
// @FocusState lives here — only created when sheet is presented.
// Never instantiated during list rendering, which was causing the freeze.

struct NoteEditorSheet: View {
    let day    : SavedDay
    let planID : UUID
    let weekID : UUID
    @EnvironmentObject var store: PlanStore
    @Environment(\.dismiss) var dismiss

    @State private var noteInput = ""
    @FocusState private var focused: Bool

    private let limit = 250

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "3A3A3A"))
                    .frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                VStack(alignment: .leading, spacing: 6) {
                    Text("HOW DID IT FEEL?")
                        .font(.system(size: 11, weight: .semibold,
                                      design: .monospaced))
                        .foregroundColor(.secondary)
                        .kerning(2)
                    Text(day.workoutType)
                        .font(.system(size: 18, weight: .light,
                                      design: .serif))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 24)

                ZStack(alignment: .topLeading) {
                    if noteInput.isEmpty {
                        Text("Legs felt strong, negative split, shin a bit tight...")
                            .font(.system(size: 14))
                            .foregroundColor(Color(.tertiaryLabel))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $noteInput)
                        .focused($focused)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .onChange(of: noteInput) { val in
                            if val.count > limit {
                                noteInput = String(val.prefix(limit))
                            }
                        }
                }
                .frame(minHeight: 140)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(14)
                .padding(.horizontal, 16)

                HStack {
                    Text("\(noteInput.count)/\(limit)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(noteInput.count > limit - 20
                                         ? Color(hex: "FF453A")
                                         : Color(hex: "3A3A3A"))
                    Spacer()
                }
                .padding(.horizontal, 24)

                HStack(spacing: 12) {
                    Button("Skip") {
                        dismiss()
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .buttonStyle(.plain)

                    Button {
                        store.saveNote(planID: planID, weekID: weekID,
                                       dayID: day.id, note: noteInput)
                        dismiss()
                    } label: {
                        Text("Save Note")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "30D158"))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

                Spacer()
            }
        }

        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .onAppear {
            noteInput = day.completionNote ?? ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focused = true
            }
        }
    }
}

// MARK: - Race Day Row

struct SPVRaceDayRow: View {
    let day           : SavedDay
    let dateFormatter : DateFormatter

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                Text("RACE DAY")
                    .font(.system(size: 13, weight: .black,
                                  design: .monospaced))
                    .foregroundColor(.black)
                    .kerning(3)
                Spacer()
                Text(dateFormatter.string(from: day.date))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.yellow)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("26.2 miles")
                        .font(.system(size: 22, weight: .thin,
                                      design: .monospaced))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("🏅 42.2 km")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Text(day.description)
                    .font(.system(size: 12))
                    .foregroundColor(Color(.secondaryLabel))
                    .fixedSize(horizontal: false, vertical: true)
                if !day.paceNote.isEmpty && day.paceNote != "—" {
                    HStack(spacing: 6) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 11))
                            .foregroundColor(.yellow)
                        Text(day.paceNote)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.yellow)
                    }
                }
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "FF453A"))
                    Text("You trained for this. Run free.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "FF453A"))
                }
            }
            .padding(16)
            .background(Color.yellow.opacity(0.06))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.6), lineWidth: 1.5)
        )
        .cornerRadius(12)
    }
}

// MARK: - Share Sheet

struct SPVShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items,
                                 applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController,
                                context: Context) {}
}
