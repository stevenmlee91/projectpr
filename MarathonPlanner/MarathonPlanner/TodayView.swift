import SwiftUI

// MARK: - Today View

struct TodayView: View {
    @EnvironmentObject var store: PlanStore

    private var todayContext: TodayContext? {
        TodayContext.find(in: store.plans, primaryID: store.primaryPlanID)
    }
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        if let ctx = todayContext {
                            todayHeader(ctx: ctx)
                            TodayWorkoutCard(ctx: ctx)
                                .environmentObject(store)
                            WeekProgressCard(ctx: ctx)
                                .environmentObject(store)
                            WeeklyMileageChartView(
                                plan:           ctx.plan,
                                currentWeekNum: ctx.weekNumber
                            )
                            RaceCountdownCard(ctx: ctx)
                        } else {
                            emptyState
                        }
                        Spacer().frame(height: 32)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)

            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("TODAY")
                        .font(.system(size: 12, weight: .semibold,
                                      design: .monospaced))
                        .foregroundColor(.secondary)
                        .kerning(4)
                }
            }
        }

    }

    private func todayHeader(ctx: TodayContext) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formattedDate())
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .kerning(2)
            Text(ctx.plan.name)
                .font(.system(size: 24, weight: .light, design: .serif))
                .foregroundColor(.primary)
            Text("Week \(ctx.weekNumber) of \(ctx.totalWeeks)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(hex: "4A4A4A"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private func formattedDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date()).uppercased()
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 60)
            Image(systemName: "figure.run")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundColor(Color(.tertiarySystemBackground))
            VStack(spacing: 8) {
                Text("No active plan")
                    .font(.system(size: 20, weight: .light, design: .serif))
                    .foregroundColor(.secondary)
                Text("Create a training plan to see\nyour daily workouts here.")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "3A3A3A"))
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Today Workout Card

struct TodayWorkoutCard: View {
    let ctx: TodayContext
    @EnvironmentObject var store: PlanStore

    @State private var showingActualMiles = false
    @State private var actualMilesInput   = ""
    @State private var showingNoteSheet   = false

    private var liveDay: SavedDay {
        store.plans
            .first { $0.id == ctx.plan.id }?
            .weeks.first { $0.id == ctx.week.id }?
            .days.first { $0.id == ctx.day.id }
        ?? ctx.day
    }

    private var status: CompletionStatus { liveDay.completionStatus }

    var body: some View {
        VStack(spacing: 0) {
            workoutTypeBar
            VStack(alignment: .leading, spacing: 16) {
                milesAndPace
                descriptionText
                if !liveDay.paceNote.isEmpty && liveDay.paceNote != "—" {
                    paceNote
                }
                if let note = liveDay.completionNote, !note.isEmpty {
                    Button {
                        showingNoteSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "note.text")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text(note)
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "6A6A6A"))
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "pencil")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "3A3A3A"))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                completionControls
                if showingActualMiles { actualMilesRow }
            }
            .padding(20)
        }
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cardBorder, lineWidth: 1.5)
        )
        .cornerRadius(16)
        .sheet(isPresented: $showingNoteSheet) {
            NoteEditorSheet(
                day:    liveDay,
                planID: ctx.plan.id,
                weekID: ctx.week.id
            )
            .environmentObject(store)
        }
    }

    // MARK: Type Bar

    private var workoutTypeBar: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(workoutColor)
                .frame(width: 8, height: 8)
            Text(liveDay.workoutType.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(workoutColor)
                .kerning(2)
            Spacer()
            statusBadge
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.tertiarySystemBackground))
    }

    private var statusBadge: some View {
        Group {
            switch status {
            case .completed:
                Label("DONE", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "30D158"))
            case .skipped:
                Label("SKIPPED", systemImage: "xmark.circle.fill")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "FF453A"))
            case .modified:
                Label("MODIFIED", systemImage: "pencil.circle.fill")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "0A84FF"))
            case .notStarted:
                if liveDay.workoutType == "Rest" {
                    Label("REST DAY", systemImage: "moon.fill")
                        .font(.system(size: 10, weight: .bold,
                                      design: .monospaced))
                        .foregroundColor(.secondary)
                } else {
                    Text("NOT STARTED")
                        .font(.system(size: 10, weight: .bold,
                                      design: .monospaced))
                        .foregroundColor(Color(hex: "3A3A3A"))
                }
            }
        }
    }

    // MARK: Miles and Pace

    private var milesAndPace: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Group {
                if liveDay.miles > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.1f", liveDay.miles))
                            .font(.system(size: 52, weight: .thin,
                                          design: .monospaced))
                            .foregroundColor(.primary)
                        Text("miles")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                } else if liveDay.workoutType == "Rest" {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: "moon.stars")
                            .font(.system(size: 36, weight: .ultraLight))
                            .foregroundColor(Color(hex: "3A3A3A"))
                        Text("Full rest day")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                } else if liveDay.workoutType == "Cross-Training" {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: "figure.cross.training")
                            .font(.system(size: 36, weight: .ultraLight))
                            .foregroundColor(Color(hex: "BF5AF2"))
                        Text("45–60 minutes")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                } else if liveDay.workoutType == "Race Day 🏁" {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("26.2")
                            .font(.system(size: 52, weight: .thin,
                                          design: .monospaced))
                            .foregroundColor(.yellow)
                        Text("miles — RACE DAY")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.yellow)
                    }
                }
            }
            Spacer()
            if let actual = liveDay.actualMiles, status == .modified {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f", actual))
                        .font(.system(size: 28, weight: .thin,
                                      design: .monospaced))
                        .foregroundColor(Color(hex: "0A84FF"))
                    Text("actual")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var descriptionText: some View {
        Text(liveDay.description)
            .font(.system(size: 13))
            .foregroundColor(Color(hex: "7A7A7A"))
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(3)
    }

    private var paceNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "speedometer")
                .font(.system(size: 12))
                .foregroundColor(workoutColor)
            Text(liveDay.paceNote)
                .font(.system(size: 12, weight: .medium,
                              design: .monospaced))
                .foregroundColor(workoutColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(workoutColor.opacity(0.08))
        .cornerRadius(8)
    }

    // MARK: Completion Controls

    private var completionControls: some View {
        Group {
            if liveDay.workoutType == "Rest"
                || liveDay.workoutType == "Race Day 🏁" {
                EmptyView()
            } else {
                HStack(spacing: 10) {
                    Button {
                        let next: CompletionStatus =
                            status == .completed ? .notStarted : .completed
                        store.updateCompletion(
                            planID: ctx.plan.id,
                            weekID: ctx.week.id,
                            dayID:  liveDay.id,
                            status: next
                        )
                        if next == .completed {
                            DispatchQueue.main.asyncAfter(
                                deadline: .now() + 0.4) {
                                showingNoteSheet = true
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: status == .completed
                                  ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                            Text(status == .completed
                                 ? "Completed" : "Mark Complete")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(status == .completed ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(status == .completed
                                    ? Color(hex: "30D158")
                                    : Color(.systemFill))
                        .cornerRadius(12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        let next: CompletionStatus =
                            status == .skipped ? .notStarted : .skipped
                        store.updateCompletion(
                            planID: ctx.plan.id,
                            weekID: ctx.week.id,
                            dayID:  liveDay.id,
                            status: next
                        )
                    } label: {
                        Image(systemName: status == .skipped
                              ? "xmark.circle.fill" : "minus.circle")
                            .font(.system(size: 20))
                            .foregroundColor(status == .skipped
                                             ? Color(hex: "FF453A")
                                             : Color(hex: "3A3A3A"))
                            .frame(width: 48, height: 48)
                            .contentShape(Rectangle())
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    if liveDay.miles > 0 {
                        Button {
                            actualMilesInput = liveDay.actualMiles
                                .map { String(format: "%.1f", $0) } ?? ""
                            showingActualMiles.toggle()
                        } label: {
                            Image(systemName: "pencil.circle")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "3A3A3A"))
                                .frame(width: 48, height: 48)
                                .contentShape(Rectangle())
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
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
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
            Button("Save") {
                if let miles = Double(actualMilesInput) {
                    store.updateCompletion(
                        planID: ctx.plan.id,
                        weekID: ctx.week.id,
                        dayID:  liveDay.id,
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
        .padding(.top, 4)
    }

    // MARK: Styling

    private var workoutColor: Color {
        switch liveDay.workoutType {
        case "Rest":                                   return Color(hex: "3A3A3A")
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
        case "Race Day 🏁":                           return .yellow
        default:                                      return Color(hex: "5E5E5E")
        }
    }

    private var cardBackground: Color {
        switch status {
        case .completed:  return Color(.systemGreen).opacity(0.12)
        case .skipped:    return Color(.systemRed).opacity(0.10)
        case .modified:   return Color(.systemBlue).opacity(0.10)
        case .notStarted:
            if liveDay.workoutType == "Race Day 🏁" {
                return Color(.systemYellow).opacity(0.10)
            }
            return Color(.secondarySystemBackground)
        }
    }

    private var cardBorder: Color {
        switch status {
        case .completed:  return Color(hex: "30D158").opacity(0.5)
        case .skipped:    return Color(hex: "FF453A").opacity(0.5)
        case .modified:   return Color(hex: "0A84FF").opacity(0.5)
        case .notStarted:
            if liveDay.workoutType == "Race Day 🏁" {
                return Color.yellow.opacity(0.6)
            }
            return Color(.separator)
        }
    }
}

// MARK: - Week Progress Card

struct WeekProgressCard: View {
    let ctx: TodayContext
    @EnvironmentObject var store: PlanStore

    private var liveWeek: SavedWeek {
        store.plans
            .first { $0.id == ctx.plan.id }?
            .weeks.first { $0.id == ctx.week.id }
        ?? ctx.week
    }

    private var pct: Double { liveWeek.completionPercentage }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("WEEK \(ctx.weekNumber)")
                        .font(.system(size: 10, weight: .semibold,
                                      design: .monospaced))
                        .foregroundColor(.secondary)
                        .kerning(3)
                    Text(liveWeek.phase)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color(.tertiarySystemBackground), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: pct)
                        .stroke(Color(hex: "30D158"),
                                style: StrokeStyle(lineWidth: 3,
                                                   lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.4), value: pct)
                    Text("\(Int(pct * 100))%")
                        .font(.system(size: 11, weight: .semibold,
                                      design: .monospaced))
                        .foregroundColor(.primary)
                }
                .frame(width: 52, height: 52)
            }

            HStack(spacing: 6) {
                ForEach(sortedDays(liveWeek.days)) { day in
                    dayDot(day: day)
                }
            }

            HStack {
                Text(String(format: "%.0f mi planned", liveWeek.totalMiles))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(hex: "4A4A4A"))
                Spacer()
                Text("\(liveWeek.completedDayCount) of "
                     + "\(liveWeek.trackableDayCount) workouts done")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(hex: "4A4A4A"))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }

    private func dayDot(day: SavedDay) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(dotBg(day))
                    .frame(width: 28, height: 28)
                if day.id == ctx.day.id {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 28, height: 28)
                }
                dotIcon(day)
            }
            Text(String(day.weekday.prefix(1)))
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(Color(hex: "3A3A3A"))
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func dotIcon(_ day: SavedDay) -> some View {
        switch day.completionStatus {
        case .completed:
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.black)
        case .skipped:
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.primary)
        case .modified:
            Image(systemName: "pencil")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.black)
        case .notStarted:
            EmptyView()
        }
    }

    private func dotBg(_ day: SavedDay) -> Color {
        switch day.completionStatus {
        case .completed: return Color(hex: "30D158")
        case .skipped:   return Color(hex: "FF453A")
        case .modified:  return Color(hex: "0A84FF")
        case .notStarted:
            return day.workoutType == "Rest"
                ? Color(.tertiarySystemFill)
                : Color(.systemFill)
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

// MARK: - Race Countdown Card

struct RaceCountdownCard: View {
    let ctx: TodayContext

    private var daysUntilRace: Int {
        max(0, Calendar.current.dateComponents(
            [.day], from: Date(), to: ctx.plan.raceDate).day ?? 0)
    }

    private var label: String {
        switch daysUntilRace {
        case 0:       return "Race day is today. Go run your marathon."
        case 1:       return "Race day is tomorrow. Trust your training."
        case 2...6:   return "Race week. Protect your legs. Stay sharp."
        case 7...14:  return "Final stretch. The hay is in the barn."
        case 15...21: return "Three weeks out. Taper is working."
        default:      return "Keep building. Every session counts."
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("RACE DAY")
                    .font(.system(size: 9, weight: .semibold,
                                  design: .monospaced))
                    .foregroundColor(Color(hex: "3E3E3E"))
                    .kerning(3)
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "7A7A7A"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(daysUntilRace)")
                    .font(.system(size: 36, weight: .thin,
                                  design: .monospaced))
                    .foregroundColor(.primary)
                Text("days")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(hex: "3E3E3E"))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }
}

// MARK: - Today Context

struct TodayContext {
    let plan       : SavedPlan
    let week       : SavedWeek
    let day        : SavedDay
    let weekNumber : Int
    let totalWeeks : Int

    // Now reads from primary plan only.
    // Pass the store so we can read primaryPlan directly.
    static func find(in plans: [SavedPlan],
                     primaryID: UUID?) -> TodayContext? {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())

        // Use primary plan if set, otherwise fall back to first active plan
        let plan: SavedPlan?
        if let id = primaryID,
           let primary = plans.first(where: { $0.id == id }) {
            plan = primary
        } else {
            plan = plans.filter { p in
                let start = cal.startOfDay(for: p.startDate)
                let end   = cal.startOfDay(for: p.raceDate)
                return today >= start && today <= end
            }.sorted { $0.raceDate < $1.raceDate }.first
        }

        guard let plan = plan else { return nil }

        guard let week = plan.weeks.first(where: { week in
            week.days.contains { cal.isDate($0.date, inSameDayAs: today) }
        }) else { return nil }

        guard let day = week.days.first(where: {
            cal.isDate($0.date, inSameDayAs: today)
        }) else { return nil }

        return TodayContext(
            plan:       plan,
            week:       week,
            day:        day,
            weekNumber: week.weekNumber,
            totalWeeks: plan.weeks.count
        )
    }
}
