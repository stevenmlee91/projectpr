import SwiftUI

// MARK: - URL + Identifiable

extension URL: Identifiable {
    public var id: String { absoluteString }
}

// MARK: - Saved Plan View

struct SavedPlanView: View {
    let plan: SavedPlan
    @EnvironmentObject var store: PlanStore
    @State private var showingEdit    = false
    @State private var shareURL: URL? = nil

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
            .filter { $0.isTrackable }
        guard !trackable.isEmpty else { return 0 }
        let done = trackable.filter {
            $0.completionStatus == .completed
                || $0.completionStatus == .modified
        }.count
        return Double(done) / Double(trackable.count)
    }

    private var currentWeekNumber: Int {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        return livePlan.weeks.first { week in
            week.days.contains {
                cal.isDate($0.date, inSameDayAs: today)
            }
        }?.weekNumber ?? 1
    }

    private var currentWeekID: UUID? {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        return livePlan.weeks.first { week in
            week.days.contains {
                cal.isDate($0.date, inSameDayAs: today)
            }
        }?.id
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    planHeader
                    completionBanner
                    PlanPhilosophyCard(plan: livePlan)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
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
                HStack(spacing: 16) {
                    if !store.isPrimary(livePlan) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                store.setPrimary(livePlan)
                            }
                        } label: {
                            Image(systemName: "bolt")
                                .foregroundColor(.primary)
                        }
                    } else {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.primary)
                    }
                    Button { showingEdit = true } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditPlanView(plan: livePlan).environmentObject(store)
        }
        .sheet(item: $shareURL) { url in
            SPVShareSheet(items: [url])
        }
    }

    // MARK: - Header

    private var planHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(livePlan.planType.uppercased())
                .eyebrow()
                .kerning(1.5)
            Text(livePlan.name)
                .font(.displayTitle(28))
                .foregroundColor(.primary)
            HStack(spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("STARTS")
                        .eyebrow(size: 9)
                        .kerning(1.5)
                    Text(dateFormatter.string(from: livePlan.startDate))
                        .font(.caption())
                        .foregroundColor(.secondary)
                }
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("RACE DAY")
                        .eyebrow(size: 9)
                        .kerning(1.5)
                    Text(dateFormatter.string(from: livePlan.raceDate))
                        .font(.caption())
                        .foregroundColor(.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.xxl)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.xl)
    }

    // MARK: - Completion Banner

    private var completionBanner: some View {
        let pct = overallCompletion
        return ZStack {
            Color(.secondarySystemBackground)
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color(.tertiarySystemBackground),
                                lineWidth: 4)
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
                        .foregroundColor(.secondary)
                        .kerning(1.5)
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

    func exportPDF() {
        let captured = livePlan
        DispatchQueue.global(qos: .userInitiated).async {
            let url = PDFExporter.exportPlan(captured)
            DispatchQueue.main.async { shareURL = url }
        }
    }

    func exportCalendar() {
        let captured = livePlan
        DispatchQueue.global(qos: .userInitiated).async {
            let url = ICSExporter.exportPlan(captured)
            DispatchQueue.main.async { shareURL = url }
        }
    }

    // MARK: - Weeks List

    private var weeksList: some View {
        VStack(spacing: 8) {
            ForEach(livePlan.weeks) { week in
                NavigationLink(value: WeekNavID(id: week.id)) {
                    SPVWeekRow(
                        week:          week,
                        isCurrentWeek: week.id == currentWeekID
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
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
    let week          : SavedWeek
    var isCurrentWeek : Bool = false

    // Use enum comparison — no string matching
    private var isRaceWeek: Bool { week.phase == .race }

    private let shortDate: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()

    var weekStart: Date? { sortedDays(week.days).first?.date }
    var weekEnd:   Date? { sortedDays(week.days).last?.date  }

    private var currentWeekAccent: Color { Color(hex: "0A84FF") }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                HStack(spacing: 8) {
                    Text("Week \(week.weekNumber)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isCurrentWeek
                                         ? currentWeekAccent : .primary)
                    if isCurrentWeek && !isRaceWeek {
                        Text("THIS WEEK")
                            .font(.system(size: 9, weight: .bold,
                                          design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(currentWeekAccent)
                            .cornerRadius(4)
                    }
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
                // Display phaseLabel for methodology-specific names
                Text(week.phaseLabel)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(
                        isRaceWeek    ? Color.orange :
                        isCurrentWeek ? currentWeekAccent.opacity(0.8) :
                                        .secondary
                    )
                Spacer()
                if let s = weekStart, let e = weekEnd {
                    Text("\(shortDate.string(from: s)) – "
                         + "\(shortDate.string(from: e))")
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
        .background(
            isCurrentWeek && !isRaceWeek
                ? currentWeekAccent.opacity(0.06)
                : isRaceWeek
                    ? Color.yellow.opacity(0.08)
                    : Color(.secondarySystemBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isCurrentWeek && !isRaceWeek
                        ? currentWeekAccent.opacity(0.35)
                        : isRaceWeek
                            ? Color.yellow.opacity(0.5)
                            : Color.clear,
                    lineWidth: 1.5
                )
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
        let order = ["Monday", "Tuesday", "Wednesday",
                     "Thursday", "Friday", "Saturday", "Sunday"]
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
        case "Rest":
            return Color(.tertiarySystemBackground)
        case "Recovery Run":
            return Color(hex: "34C759")
        case "Easy Run", "Easy + Strides", "Shakeout Run":
            return Color(hex: "30D158")
        case "Long Run", "Long Run w/ MP Finish",
             "Medium-Long Run", "Midweek Longer Run":
            return Color(hex: "0A84FF")
        case "Tempo Run", "Strength (MP)", "Marathon Pace":
            return Color(hex: "FF9F0A")
        case "Lactate Threshold", "Cruise Intervals",
             "Speed Work", "Interval Work", "Repetition Work":
            return Color(hex: "FF453A")
        case "Cross-Training":
            return Color(hex: "BF5AF2")
        case "Race Day 🏁":
            return Color.yellow
        default:
            return Color(.systemFill)
        }
    }
}

// MARK: - Week Detail View

struct SPVWeekDetailView: View {
    let planID : UUID
    let week   : SavedWeek
    @EnvironmentObject var store: PlanStore

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"; return f
    }()

    private var liveWeek: SavedWeek {
        store.plans
            .first { $0.id == planID }?
            .weeks.first { $0.id == week.id }
        ?? week
    }

    // Use enum comparison — no string matching
    private var isRaceWeek: Bool { liveWeek.phase == .race }

    private var raceType: RaceType {
        store.plans.first { $0.id == planID }?.settings.raceType ?? .marathon
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
                            SPVDayRow(day:           day,
                                      planID:        planID,
                                      weekID:        liveWeek.id,
                                      dateFormatter: dateFormatter,
                                      raceType:      raceType)
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
                        // Display phaseLabel for methodology-specific name
                        Text(liveWeek.phaseLabel)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(isRaceWeek
                                             ? .yellow
                                             : Color(.secondaryLabel))
                        if isRaceWeek {
                            Image(systemName: "flag.checkered")
                                .foregroundColor(.orange)
                                .font(.system(size: 12))
                        }
                    }
                    Text(String(format: "%.1f mi planned",
                                liveWeek.totalMiles))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color(.tertiarySystemBackground),
                                lineWidth: 3)
                    Circle()
                        .trim(from: 0,
                              to: liveWeek.completionPercentage)
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
        let order = ["Monday", "Tuesday", "Wednesday",
                     "Thursday", "Friday", "Saturday", "Sunday"]
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
    let raceType      : RaceType
    @EnvironmentObject var store: PlanStore

    @State private var showingActualMiles = false
    @State private var actualMilesInput   = ""
    @State private var isEditingNote      = false
    @State private var noteInput          = ""
    @FocusState private var noteFocused   : Bool

    init(day: SavedDay, planID: UUID, weekID: UUID,
         dateFormatter: DateFormatter,
         raceType: RaceType = .marathon) {
        self.day           = day
        self.planID        = planID
        self.weekID        = weekID
        self.dateFormatter = dateFormatter
        self.raceType      = raceType
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(day.date)
    }

    var dotColor: Color {
        switch day.workoutType {
        case "Rest":
            return .gray
        case "Recovery Run":
            return Color(hex: "34C759")
        case "Easy Run", "Easy + Strides", "Shakeout Run":
            return Color(hex: "30D158")
        case "Long Run", "Long Run w/ MP Finish",
             "Medium-Long Run", "Midweek Longer Run":
            return Color(hex: "0A84FF")
        case "Tempo Run", "Strength (MP)", "Marathon Pace":
            return Color(hex: "FF9F0A")
        case "Lactate Threshold", "Cruise Intervals",
             "Speed Work", "Interval Work", "Repetition Work":
            return Color(hex: "FF453A")
        case "Cross-Training":
            return Color(hex: "BF5AF2")
        default:
            return Color(hex: "3A3A3A")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if isToday {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: "0A84FF"))
                        .frame(width: 6, height: 6)
                    Text("TODAY")
                        .font(.system(size: 9, weight: .bold,
                                      design: .monospaced))
                        .foregroundColor(Color(hex: "0A84FF"))
                        .kerning(1)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 2)
            }

            HStack(alignment: .top, spacing: 14) {

                ZStack {
                    if isToday {
                        Circle()
                            .stroke(dotColor.opacity(0.25), lineWidth: 3)
                            .frame(width: 18, height: 18)
                    }
                    Circle()
                        .fill(day.isRestDay
                              ? Color(.tertiarySystemFill)
                              : dotColor)
                        .frame(width: 10, height: 10)
                }
                .frame(width: 18, height: 18)
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(dateFormatter.string(from: day.date))
                            .font(.system(
                                size: 14,
                                weight: isToday ? .bold : .semibold))
                            .foregroundColor(
                                day.isRestDay
                                    ? .secondary
                                    : isToday
                                        ? Color(hex: "0A84FF")
                                        : .primary
                            )
                        Spacer()
                        milesView
                    }

                    Text(day.displayWorkoutType(raceType: raceType))
                        .font(.system(size: 12))
                        .foregroundColor(
                            day.isRestDay
                                ? Color(.tertiaryLabel)
                                : completionColor ?? dotColor
                        )

                    Text(day.description)
                        .font(.system(size: 11))
                        .foregroundColor(
                            day.isRestDay
                                ? Color(.tertiaryLabel)
                                : .secondary
                        )
                        .fixedSize(horizontal: false, vertical: true)

                    if day.paceNote != "—" && !day.paceNote.isEmpty
                        && !day.isRestDay {
                        Text("Target: \(day.paceNote)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "0A84FF"))
                    }

                    if !day.isRestDay
                        && (day.completionStatus == .completed
                            || day.completionStatus == .modified
                            || day.completionStatus == .skipped) {
                        noteSection
                    }
                }

                if day.isRestDay {
                    RestDayMarker()
                } else {
                    WorkoutCompletionButton(
                        status:     day.completionStatus,
                        isRestDay:  day.isRestDay,
                        onComplete: {
                            let next: CompletionStatus =
                                day.completionStatus == .completed
                                    ? .notStarted : .completed
                            if next == .completed {
                                CompletionHaptics.complete()
                            } else {
                                CompletionHaptics.uncomplete()
                            }
                            store.updateCompletion(
                                planID: planID,
                                weekID: weekID,
                                dayID:  day.id,
                                status: next
                            )
                            if next == .notStarted {
                                isEditingNote = false
                                noteInput     = ""
                            }
                        },
                        onSkip: {
                            let next: CompletionStatus =
                                day.completionStatus == .skipped
                                    ? .notStarted : .skipped
                            CompletionHaptics.skip()
                            store.updateCompletion(
                                planID: planID,
                                weekID: weekID,
                                dayID:  day.id,
                                status: next
                            )
                            if next == .notStarted {
                                isEditingNote = false
                                noteInput     = ""
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, isToday ? 10 : 14)

            if !day.isRestDay
                && (day.completionStatus == .modified
                    || showingActualMiles) {
                actualMilesRow
            }

            if !day.isRestDay && day.miles > 0
                && !showingActualMiles
                && day.completionStatus != .skipped {
                Button {
                    actualMilesInput = day.actualMiles
                        .map { String(format: "%.1f", $0) } ?? ""
                    showingActualMiles.toggle()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                        Text("Log actual miles")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .background(rowBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isToday
                        ? Color(hex: "0A84FF").opacity(0.35)
                        : Color.clear,
                    lineWidth: 1.5
                )
        )
        .cornerRadius(12)
        .contentShape(Rectangle())
        .id(day.id)
        .animation(.easeInOut(duration: 0.2),
                   value: day.completionStatus)
    }

    // MARK: Note Section

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let note = day.completionNote,
               !note.isEmpty, !isEditingNote {
                Button {
                    noteInput     = note
                    isEditingNote = true
                    noteFocused   = true
                } label: {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "note.text")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(note)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "pencil")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

            } else if !isEditingNote {
                Button {
                    noteInput     = ""
                    isEditingNote = true
                    noteFocused   = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Add note")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
            }

            if isEditingNote {
                VStack(spacing: 6) {
                    TextField("How did it go?",
                              text: $noteInput, axis: .vertical)
                        .font(.system(size: 12))
                        .lineLimit(2...4)
                        .focused($noteFocused)
                        .padding(10)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(8)

                    HStack(spacing: 8) {
                        Button {
                            isEditingNote = false
                            noteFocused   = false
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        if let existing = day.completionNote,
                           !existing.isEmpty {
                            Button {
                                store.saveNote(planID: planID,
                                               weekID: weekID,
                                               dayID:  day.id,
                                               note:   "")
                                noteInput     = ""
                                isEditingNote = false
                                noteFocused   = false
                            } label: {
                                Text("Clear")
                                    .font(.system(size: 11,
                                                  weight: .medium))
                                    .foregroundColor(Color(hex: "FF453A"))
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            let trimmed = noteInput.trimmingCharacters(
                                in: .whitespacesAndNewlines)
                            store.saveNote(planID: planID,
                                           weekID: weekID,
                                           dayID:  day.id,
                                           note:   trimmed)
                            isEditingNote = false
                            noteFocused   = false
                            UIImpactFeedbackGenerator(style: .light)
                                .impactOccurred()
                        } label: {
                            Text("Save")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(hex: "30D158"))
                                .cornerRadius(7)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.top, 2)
    }

    // MARK: Miles View

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

    // MARK: Actual Miles Row

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
                    store.updateCompletion(
                        planID: planID,
                        weekID: weekID,
                        dayID:  day.id,
                        status: .modified,
                        actual: miles
                    )
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

    // MARK: Styling

    private var rowBackground: Color {
        if day.isRestDay {
            return Color(.secondarySystemBackground).opacity(0.6)
        }
        if isToday && day.completionStatus == .notStarted {
            return Color(hex: "0A84FF").opacity(0.06)
        }
        switch day.completionStatus {
        case .completed:  return Color(.systemGreen).opacity(0.10)
        case .skipped:    return Color(.systemRed).opacity(0.08)
        case .modified:   return Color(.systemBlue).opacity(0.10)
        case .notStarted: return Color(.secondarySystemBackground)
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

// MARK: - Race Day Row

struct SPVRaceDayRow: View {
    let day           : SavedDay
    let dateFormatter : DateFormatter

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                Text("RACE DAY")
                    .font(.label())
                    .foregroundColor(.black)
                    .kerning(1.5)
                Spacer()
                Text(dateFormatter.string(from: day.date))
                    .font(.caption())
                    .foregroundColor(.black)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(Color.yellow)

            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text(String(format: "%.1f miles", day.miles))
                        .font(.metric(22))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(day.miles > 20 ? "🏅 42.2 km" : "🏅 21.1 km")
                        .font(.appBody())
                        .foregroundColor(.secondary)
                }
                Text(day.description)
                    .font(.appBody())
                    .foregroundColor(Color(.secondaryLabel))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
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
    func makeUIViewController(
        context: Context
    ) -> UIActivityViewController {
        UIActivityViewController(activityItems: items,
                                 applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController,
                                context: Context) {}
}
