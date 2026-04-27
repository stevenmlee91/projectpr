import SwiftUI

struct CreatePlanView: View {
    @EnvironmentObject var store  : PlanStore
    @Environment(\.dismiss) var dismiss

    @State private var planName     = ""
    @State private var raceDate     = Date().addingTimeInterval(60 * 60 * 24 * 112)
    @State private var settings     = UserSettings()
    @State private var goalHours    = 3
    @State private var goalMinutes  = 30
    @State private var isGenerating = false

    var startDate: Date {
        Calendar.current.date(
            byAdding: .weekOfYear,
            value: -settings.planLength.rawValue,
            to: raceDate
        ) ?? raceDate
    }

    private let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; return f
    }()

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        Group {
                            // ── Header ───────────────────────────────
                            VStack(alignment: .leading, spacing: 4) {
                                Text("NEW PLAN")
                                    .font(.system(size: 11, weight: .semibold,
                                                  design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .kerning(3)
                                Text("Create Training Plan")
                                    .font(.system(size: 28, weight: .light,
                                                  design: .serif))
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                            .padding(.bottom, 28)

                            // ── Plan Name ────────────────────────────
                            CreateLabel("PLAN NAME")
                            ZStack {
                                Color(.secondarySystemBackground)
                                TextField("e.g. Sydney Marathon 2026",
                                          text: $planName)
                                    .foregroundColor(.primary)
                                    .padding(16)
                            }
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)

                            // ── Race Date ────────────────────────────
                            CreateLabel("RACE DATE")
                            ZStack {
                                Color(.secondarySystemBackground)
                                VStack(spacing: 0) {
                                    DatePicker("Race Date",
                                               selection: $raceDate,
                                               displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .foregroundColor(.primary)
                                        .padding(16)
                                    Divider()
                                    HStack {
                                        Text("Plan starts")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(dateFmt.string(from: startDate))
                                            .font(.system(size: 12,
                                                          design: .monospaced))
                                            .foregroundColor(.primary)
                                    }
                                    .padding(16)
                                }
                            }
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)

                            // ── Training Method ──────────────────────
                            CreateLabel("TRAINING METHOD")
                            VStack(spacing: 1) {
                                ForEach(PlanType.allCases) { plan in
                                    CreatePlanTypeRow(
                                        plan:       plan,
                                        isSelected: settings.planType == plan,
                                        onTap: {
                                            settings.planType = plan
                                            settings.resetScheduleForNewPlanType()
                                        }
                                    )
                                }
                            }
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }

                        Group {
                            // ── Duration ─────────────────────────────
                            CreateLabel("DURATION")
                            HStack(spacing: 10) {
                                ForEach(PlanLength.allCases) { length in
                                    CreateDurationChip(
                                        label:      length.label,
                                        isSelected: settings.planLength == length,
                                        onTap:      { settings.planLength = length }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)

                            // ── Goal Time ────────────────────────────
                            CreateLabel("GOAL TIME")
                            ZStack {
                                Color(.secondarySystemBackground)
                                HStack(spacing: 0) {
                                    Picker("", selection: $goalHours) {
                                        ForEach(2...6, id: \.self) { h in
                                            Text("\(h)h").tag(h)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(maxWidth: .infinity)

                                    Text(":")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 24, weight: .thin))

                                    Picker("", selection: $goalMinutes) {
                                        ForEach(
                                            [0,5,10,15,20,25,30,35,40,45,50,55],
                                            id: \.self
                                        ) { m in
                                            Text(String(format: "%02dm", m)).tag(m)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(maxWidth: .infinity)
                                }
                                .frame(height: 110)
                            }
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)

                            // ── Base Mileage ─────────────────────────
                            CreateLabel("BASE MILEAGE")
                            ZStack {
                                Color(.secondarySystemBackground)
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(Int(settings.baseMileage))")
                                            .font(.system(size: 36, weight: .thin,
                                                          design: .monospaced))
                                            .foregroundColor(.primary)
                                        Text("miles / week currently")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    VStack(spacing: 10) {
                                        Button {
                                            if settings.baseMileage < 80 {
                                                settings.baseMileage += 5
                                            }
                                        } label: {
                                            Image(systemName: "plus")
                                                .foregroundColor(.primary)
                                                .frame(width: 38, height: 38)
                                                .background(Color(.tertiarySystemBackground))
                                                .cornerRadius(8)
                                        }
                                        Button {
                                            if settings.baseMileage > 10 {
                                                settings.baseMileage -= 5
                                            }
                                        } label: {
                                            Image(systemName: "minus")
                                                .foregroundColor(.primary)
                                                .frame(width: 38, height: 38)
                                                .background(Color(.tertiarySystemBackground))
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                                .padding(18)
                            }
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }

                        // ── Weekly Schedule ───────────────────────────
                        Group {
                            CreateLabel("WEEKLY SCHEDULE")

                            // Philosophy note
                            ZStack {
                                Color(.secondarySystemBackground)
                                HStack(spacing: 12) {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 14))
                                    Text(scheduleNote)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(14)
                            }
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)

                            // Long Run Day
                            CreateScheduleLabel("LONG RUN DAY")
                            SingleDayPicker(
                                selected: $settings.schedule.longRunDay,
                                disabled: []
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)

                            // Primary Workout Day
                            if settings.planType != .higdon {
                                CreateScheduleLabel(
                                    settings.planType == .higdonIntermediate
                                        ? "TEMPO DAY"
                                        : "PRIMARY WORKOUT DAY (Q1)"
                                )
                                SingleDayPicker(
                                    selected: $settings.schedule.workoutDay1,
                                    disabled: [settings.schedule.longRunDay]
                                )
                                .padding(.horizontal, 16)
                                .padding(.bottom, 20)
                            }

                            // Secondary Workout Day
                            if settings.planType == .hansons
                                || settings.planType == .pfitz
                                || settings.planType == .jackDaniels {
                                CreateScheduleLabel("SECONDARY WORKOUT DAY (Q2)")
                                SingleDayPicker(
                                    selected: $settings.schedule.workoutDay2,
                                    disabled: [
                                        settings.schedule.longRunDay,
                                        settings.schedule.workoutDay1
                                    ]
                                )
                                .padding(.horizontal, 16)
                                .padding(.bottom, 20)
                            }
                        }

                        Group {
                            // Midweek Longer Run Day
                            if settings.planType.usesMidweekLongRun {
                                CreateScheduleLabel("MIDWEEK LONGER RUN DAY")
                                SingleDayPicker(
                                    selected: $settings.schedule.midweekLongDay,
                                    disabled: midweekDisabled()
                                )
                                .padding(.horizontal, 16)
                                .padding(.bottom, 20)
                            }

                            // Cross-Training
                            if settings.planType.usesCrossTraining {
                                CreateScheduleLabel("CROSS-TRAINING DAY (OPTIONAL)")
                                CreateCrossTrainToggle(
                                    schedule: $settings.schedule,
                                    taken: allAssignedDays()
                                )
                                .padding(.horizontal, 16)
                                .padding(.bottom, 20)
                            }

                            // Rest Days
                            CreateScheduleLabel(restDaysLabel)
                            MultiDayPicker(
                                selected: $settings.schedule.restDays,
                                disabled: daysBlockedFromRest()
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 6)

                            HStack(spacing: 6) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text(restGuidance)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)

                            // Live conflict warnings
                            let issues = liveConflicts()
                            if !issues.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                            .font(.system(size: 12))
                                        Text("CONFLICTS")
                                            .font(.system(size: 10,
                                                          weight: .semibold,
                                                          design: .monospaced))
                                            .foregroundColor(.orange)
                                            .kerning(2)
                                    }
                                    ForEach(issues, id: \.self) { msg in
                                        HStack(alignment: .top, spacing: 6) {
                                            Text("•")
                                                .foregroundColor(.secondary)
                                            Text(msg)
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                                .fixedSize(horizontal: false,
                                                           vertical: true)
                                        }
                                    }
                                    Text("These are auto-resolved when the plan generates.")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                .padding(14)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 20)
                            }

                            Spacer().frame(height: 110)
                        }
                    }
                }

                // ── Generate Button ───────────────────────────────────
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [Color(.systemBackground).opacity(0),
                                 Color(.systemBackground)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 30)

                    Button(action: generatePlan) {
                        HStack(spacing: 10) {
                            Image(systemName: "figure.run")
                                .font(.system(size: 14, weight: .medium))
                            Text(isGenerating ? "GENERATING..." : "GENERATE PLAN")
                                .font(.system(size: 13, weight: .semibold,
                                              design: .monospaced))
                                .kerning(2)
                        }
                        .foregroundColor(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color(.label))
                        .cornerRadius(14)
                    }
                    .disabled(isGenerating ||
                              planName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                    .background(Color(.systemBackground))
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.primary)
                }
            }
        }
        .onChange(of: goalHours)   { _ in updateGoalTime() }
        .onChange(of: goalMinutes) { _ in updateGoalTime() }
    }

    // MARK: - Schedule Descriptions

    private var scheduleNote: String {
        switch settings.planType {
        case .higdon:
            return "Novice: Long run is the anchor. 2 rest days recommended. Midweek run builds endurance."
        case .higdonIntermediate:
            return "Intermediate: Long run + midweek run + tempo + optional cross-training. 1 rest day minimum."
        case .hansons:
            return "Six days running. ONE quality day per week: speed weeks 1–5, then Strength/MP runs. 1 rest day only."
        case .pfitz:
            return "Six days running. Two quality days + medium-long run mid-week. High aerobic demand."
        case .jackDaniels:
            return "Q1 and Q2 anchor the week. All other days strictly easy. Space quality days apart."
        }
    }

    private var restDaysLabel: String {
        switch settings.planType {
        case .hansons:            return "REST DAY (1 ONLY — HANSONS)"
        case .pfitz:              return "REST DAY (1 MAXIMUM)"
        case .higdon:             return "REST DAYS (SELECT 2)"
        case .higdonIntermediate: return "REST DAY (1 MINIMUM)"
        case .jackDaniels:        return "REST DAYS (1–2)"
        }
    }

    private var restGuidance: String {
        switch settings.planType {
        case .hansons:
            return "Hansons runs 6 days/week by design. One rest day only."
        case .pfitz:
            return "Pfitz needs 5–6 running days. Limit rest to preserve volume."
        case .higdon:
            return "Two rest days help absorb training. Select any two free days."
        case .higdonIntermediate:
            return "One rest day minimum. Cross-training covers the other recovery day."
        case .jackDaniels:
            return "One or two rest days. Keep Q1 and Q2 separated by at least one easy day."
        }
    }

    private func daysBlockedFromRest() -> [Weekday] {
        let s = settings.schedule
        let p = settings.planType

        var hardBlocked = Set<Weekday>()
        hardBlocked.insert(s.longRunDay)
        if p != .higdon             { hardBlocked.insert(s.workoutDay1) }
        if p.requiresTwoWorkoutDays { hardBlocked.insert(s.workoutDay2) }
        if p.usesMidweekLongRun     { hardBlocked.insert(s.midweekLongDay) }
        if p.usesCrossTraining, let ct = s.crossTrainDay { hardBlocked.insert(ct) }

        let minRunDays  = minimumRunDays(for: p)
        let maxRestDays = 7 - minRunDays
        let currentRest = s.restDays.filter { !hardBlocked.contains($0) }.count

        var blocked = Array(hardBlocked)

        if currentRest >= maxRestDays {
            let cannotAdd = Weekday.allCases.filter {
                !hardBlocked.contains($0) && !s.restDays.contains($0)
            }
            blocked += cannotAdd
        }

        return blocked
    }

    private func minimumRunDays(for plan: PlanType) -> Int {
        switch plan {
        case .hansons:            return 6
        case .pfitz:              return 5
        case .higdon:             return 4
        case .higdonIntermediate: return 4
        case .jackDaniels:        return 4
        }
    }

    private func midweekDisabled() -> [Weekday] {
        let s = settings.schedule
        var d: [Weekday] = [s.longRunDay]
        d += s.restDays
        if settings.planType != .higdon             { d.append(s.workoutDay1) }
        if settings.planType.requiresTwoWorkoutDays { d.append(s.workoutDay2) }
        return d
    }

    private func allAssignedDays() -> [Weekday] {
        let s = settings.schedule
        var t: [Weekday] = [s.longRunDay, s.workoutDay1,
                            s.workoutDay2, s.midweekLongDay]
        t += s.restDays
        if let ct = s.crossTrainDay { t.append(ct) }
        return t
    }

    private func liveConflicts() -> [String] {
        var issues: [String] = []
        let s = settings.schedule
        let p = settings.planType

        if s.restDays.contains(s.longRunDay) {
            issues.append("\(s.longRunDay.fullName) is both a rest day and your long run day.")
        }
        if p != .higdon && s.restDays.contains(s.workoutDay1) {
            issues.append("\(s.workoutDay1.fullName) is both a rest day and a workout day.")
        }
        if p.requiresTwoWorkoutDays && s.restDays.contains(s.workoutDay2) {
            issues.append("\(s.workoutDay2.fullName) is both a rest day and a workout day.")
        }
        if p.requiresTwoWorkoutDays && s.workoutDay1 == s.workoutDay2 {
            issues.append("Workout Day 1 and Workout Day 2 are the same day.")
        }
        if p.usesMidweekLongRun && s.midweekLongDay == s.longRunDay {
            issues.append("Midweek run and long run are on the same day.")
        }
        return issues
    }

    // MARK: - Actions

    private func updateGoalTime() {
        settings.goalTimeMinutes = goalHours * 60 + goalMinutes
    }

    private func generatePlan() {
        updateGoalTime()
        isGenerating = true

        let capturedSettings = settings
        let capturedName     = planName.trimmingCharacters(in: .whitespaces)
        let capturedDate     = raceDate

        DispatchQueue.global(qos: .userInitiated).async {
            let plan = createSavedPlan(
                name:     capturedName,
                raceDate: capturedDate,
                settings: capturedSettings
            )
            DispatchQueue.main.async {
                store.savePlan(plan)
                isGenerating = false
                dismiss()
            }
        }
    }
}

// MARK: - Sub-components

struct CreateLabel: View {
    let title: String
    init(_ t: String) { title = t }
    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(.secondary)
            .kerning(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 20)
            .padding(.bottom, 8)
    }
}

struct CreateScheduleLabel: View {
    let title: String
    init(_ t: String) { title = t }
    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(.secondary)
            .kerning(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 20)
            .padding(.bottom, 8)
    }
}

struct CreatePlanTypeRow: View {
    let plan       : PlanType
    let isSelected : Bool
    let onTap      : () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Radio circle — uses primary/secondary so it works in both modes
                Circle()
                    .stroke(
                        isSelected ? Color.accentColor : Color(.systemFill),
                        lineWidth: 1.5
                    )
                    .background(
                        Circle().fill(isSelected
                                      ? Color.accentColor.opacity(0.15)
                                      : Color.clear)
                    )
                    .frame(width: 16, height: 16)

                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.rawValue)
                        .font(.system(size: 14,
                                      weight: isSelected ? .semibold : .regular))
                        .foregroundColor(.primary)
                    Text(plan.description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected
                        ? Color(.systemFill)
                        : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

struct CreateDurationChip: View {
    let label      : String
    let isSelected : Bool
    let onTap      : () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 12,
                              weight: isSelected ? .semibold : .regular,
                              design: .monospaced))
                .foregroundColor(isSelected
                                 ? Color(.systemBackground)
                                 : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected
                            ? Color(.label)
                            : Color(.secondarySystemBackground))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct CreateCrossTrainToggle: View {
    @Binding var schedule : UserSchedule
    let taken             : [Weekday]

    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Include Cross-Training Day")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                        Text("Cycling, swimming, elliptical, yoga")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { schedule.crossTrainDay != nil },
                        set: { on in
                            if on {
                                let t = Set(taken)
                                schedule.crossTrainDay =
                                    Weekday.allCases.first { !t.contains($0) }
                            } else {
                                schedule.crossTrainDay = nil
                            }
                        }
                    ))
                    .labelsHidden()
                }
                .padding(16)

                if schedule.crossTrainDay != nil {
                    Divider()
                    HStack(spacing: 5) {
                        ForEach(Weekday.allCases) { day in
                            let isSel = schedule.crossTrainDay == day
                            let isDis = taken.contains(day)
                                && schedule.crossTrainDay != day
                            Button {
                                guard !isDis else { return }
                                schedule.crossTrainDay = day
                            } label: {
                                Text(day.name)
                                    .font(.system(size: 11,
                                                  weight: isSel ? .semibold : .regular,
                                                  design: .monospaced))
                                    .foregroundColor(
                                        isDis ? Color(.tertiaryLabel) :
                                        isSel ? Color(.systemBackground) :
                                                .secondary
                                    )
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .background(
                                        isDis ? Color(.tertiarySystemFill) :
                                        isSel ? Color(.label) :
                                                Color(.tertiarySystemBackground)
                                    )
                                    .cornerRadius(7)
                            }
                            .buttonStyle(.plain)
                            .disabled(isDis)
                        }
                    }
                    .padding(10)
                }
            }
        }
        .cornerRadius(12)
    }
}
