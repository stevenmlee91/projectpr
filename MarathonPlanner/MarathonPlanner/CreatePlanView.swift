import SwiftUI

// MARK: - Keyboard Dismiss

extension UIApplication {
    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder),
                   to: nil, from: nil, for: nil)
    }
}

// MARK: - Create Plan View

struct CreatePlanView: View {
    @EnvironmentObject var store  : PlanStore
    @Environment(\.dismiss) var dismiss

    @FocusState private var nameFieldFocused: Bool

    @State private var selectedRaceType : RaceType = .marathon
    @State private var planName                    = ""
    @State private var raceDate         = Date().addingTimeInterval(
        60 * 60 * 24 * 112)
    @State private var settings         = UserSettings()
    @State private var goalHours        = 3
    @State private var goalMinutes      = 30
    @State private var isGenerating     = false

    private var availablePlanTypes: [PlanType] {
        PlanType.options(for: selectedRaceType)
    }
    private var availableLengths: [PlanLength] {
        PlanLength.options(for: selectedRaceType)
    }
    private var goalHourRange: [Int] {
        selectedRaceType == .halfMarathon
            ? Array(1...3) : Array(2...6)
    }

    var startDate: Date {
        var cal          = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.timeZone     = .current
        let weekday         = cal.component(.weekday, from: raceDate)
        let daysSinceMonday = (weekday + 5) % 7
        guard let raceWeekMonday = cal.date(
            byAdding: .day,
            value:    -daysSinceMonday,
            to:       cal.startOfDay(for: raceDate)
        ) else { return raceDate }
        return cal.date(
            byAdding: .weekOfYear,
            value:    -(settings.planLength.rawValue - 1),
            to:       raceWeekMonday
        ) ?? raceDate
    }

    private var isReadyToGenerate: Bool {
        !planName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    private let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; return f
    }()

    // MARK: - Duration Context
    // Shown below duration chips for half marathon plans only.
    // Guides the runner toward the right choice without overwhelming them.

    private var durationContextNote: String {
        switch settings.planLength {
        case .tenWeek:
            return "Focused build — works best with a solid running base already in place."
        case .twelveWeek:
            return "Standard — the most popular choice. Enough time to build confidently."
        case .sixteenWeek:
            return "Full build — maximum preparation. Recommended for first-timers."
        default:
            return ""
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                        .padding(.bottom, 32)
                    formContent
                    ReadinessCardIfNeeded(settings: settings)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                    generateButton
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.primary)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                nameFieldFocused = true
            }
        }
        .onChange(of: goalHours)        { _ in updateGoalTime() }
        .onChange(of: goalMinutes)      { _ in updateGoalTime() }
        .onChange(of: selectedRaceType) { _ in handleRaceTypeChange() }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NEW PLAN")
                .font(.system(size: 10, weight: .semibold,
                              design: .monospaced))
                .foregroundColor(.secondary)
                .kerning(1.5)
                .padding(.top, 28)

            Text("Create Your Plan")
                .font(.system(size: 32, weight: .light,
                              design: .serif))
                .foregroundColor(.primary)
                .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    TextField(planNamePlaceholder, text: $planName)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.primary)
                        .focused($nameFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { nameFieldFocused = false }
                        .tint(.primary)

                    if !planName.isEmpty {
                        Button {
                            planName         = ""
                            nameFieldFocused = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(Color(.systemGray3))
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            nameFieldFocused
                                ? Color(.label).opacity(0.3)
                                : Color.clear,
                            lineWidth: 1.5
                        )
                )
                .animation(.easeInOut(duration: 0.2),
                           value: nameFieldFocused)

                if planName.isEmpty && !nameFieldFocused {
                    Text("Give your plan a name to get started.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2),
                       value: planName.isEmpty)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Form Content

    private var formContent: some View {
        VStack(spacing: 0) {

            // 1. Race Type
            formSection("RACE TYPE") {
                VStack(spacing: 0) {
                    ForEach(RaceType.allCases, id: \.self) { type in
                        raceTypeRow(type)
                        if type != RaceType.allCases.last {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
            }

            // 2. Race Date
            formSection("RACE DATE") {
                VStack(spacing: 0) {
                    DatePicker("Race Date",
                               selection: $raceDate,
                               displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .foregroundColor(.primary)
                    Divider().padding(.vertical, 12)
                    HStack {
                        Label("Plan starts",
                              systemImage: "calendar")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(dateFmt.string(from: startDate))
                            .font(.system(size: 13,
                                          design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }
            }

            // 3. Duration
            // Half marathon: 3 options (10 / 12 / 16 weeks) with context note.
            // Marathon: 3 options (12 / 16 / 18 weeks), no note needed.
            formSection("DURATION") {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        ForEach(availableLengths) { length in
                            CreateDurationChip(
                                label:      length.label,
                                isSelected: settings.planLength == length,
                                onTap: {
                                    UIImpactFeedbackGenerator(style: .light)
                                        .impactOccurred()
                                    settings.planLength = length
                                }
                            )
                        }
                    }
                    // Context note — only shown for half marathon
                    if selectedRaceType == .halfMarathon
                        && !durationContextNote.isEmpty {
                        Divider()
                            .padding(.vertical, 10)
                        Text(durationContextNote)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .animation(.easeInOut(duration: 0.15),
                                       value: settings.planLength)
                    }
                }
            }

            // 4. Training Method
            formSection("TRAINING METHOD") {
                VStack(spacing: 0) {
                    ForEach(availablePlanTypes) { plan in
                        CreatePlanTypeRow(
                            plan:       plan,
                            isSelected: settings.planType == plan,
                            onTap: {
                                UIImpactFeedbackGenerator(style: .light)
                                    .impactOccurred()
                                settings.planType = plan
                                settings.resetScheduleForNewPlanType()
                            }
                        )
                        if plan != availablePlanTypes.last {
                            Divider().padding(.leading, 32)
                        }
                    }
                }
            }

            // 5. Goal Time
            formSection("GOAL TIME") {
                HStack(spacing: 0) {
                    Picker("", selection: $goalHours) {
                        ForEach(goalHourRange, id: \.self) { h in
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

            // 6. Base Mileage
            formSection("BASE MILEAGE") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(settings.baseMileage))")
                            .font(.system(size: 42, weight: .thin,
                                          design: .monospaced))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3),
                                       value: settings.baseMileage)
                        Text(settings.baseMileage == 0
                             ? "just getting started"
                             : "miles / week currently")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .animation(.easeInOut(duration: 0.2),
                                       value: settings.baseMileage == 0)
                    }
                    Spacer()
                    VStack(spacing: 8) {
                        Button {
                            if settings.baseMileage < 80 {
                                UIImpactFeedbackGenerator(style: .light)
                                    .impactOccurred()
                                settings.baseMileage += 5
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                                .background(Color(.systemFill))
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)

                        Button {
                            if settings.baseMileage > 0 {
                                UIImpactFeedbackGenerator(style: .light)
                                    .impactOccurred()
                                settings.baseMileage -= 5
                            }
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(
                                    settings.baseMileage == 0
                                        ? Color(.systemGray3)
                                        : .primary
                                )
                                .frame(width: 44, height: 44)
                                .background(Color(.systemFill))
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .disabled(settings.baseMileage == 0)
                    }
                }
            }

            // 7. Schedule
            scheduleSection
        }
        .onTapGesture {
            UIApplication.shared.dismissKeyboard()
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button(action: generatePlan) {
            HStack(spacing: 10) {
                if isGenerating {
                    ProgressView()
                        .tint(Color(.systemBackground))
                        .scaleEffect(0.85)
                } else {
                    Image(systemName: "figure.run")
                        .font(.system(size: 14, weight: .medium))
                }
                Text(isGenerating
                     ? "GENERATING..."
                     : "GENERATE PLAN")
                    .font(.system(size: 13, weight: .semibold,
                                  design: .monospaced))
                    .kerning(1.5)
            }
            .foregroundColor(
                isReadyToGenerate
                    ? Color(.systemBackground)
                    : Color(.systemBackground).opacity(0.4)
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isReadyToGenerate
                          ? Color(.label)
                          : Color(.systemGray3))
            )
            .animation(.easeInOut(duration: 0.2),
                       value: isReadyToGenerate)
        }
        .disabled(!isReadyToGenerate || isGenerating)
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    // MARK: - Form Section Builder

    private func formSection<Content: View>(
        _ header: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(header)
                .font(.system(size: 10, weight: .semibold,
                              design: .monospaced))
                .foregroundColor(.secondary)
                .kerning(1.5)
                .padding(.leading, 4)
                .padding(.bottom, 8)

            content()
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(14)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
        VStack(spacing: 0) {

            VStack(alignment: .leading, spacing: 8) {
                Text("WEEKLY SCHEDULE")
                    .font(.system(size: 10, weight: .semibold,
                                  design: .monospaced))
                    .foregroundColor(.secondary)
                    .kerning(1.5)

                Text(scheduleNote)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            scheduleBlock("LONG RUN DAY") {
                SingleDayPicker(
                    selected: $settings.schedule.longRunDay,
                    disabled: []
                )
            }

            if settings.planType != .higdon
                && settings.planType != .higdonHalfNovice {
                scheduleBlock(primaryWorkoutLabel) {
                    SingleDayPicker(
                        selected: $settings.schedule.workoutDay1,
                        disabled: [settings.schedule.longRunDay]
                    )
                }
            }

            if settings.planType == .hansons
                || settings.planType == .pfitz
                || settings.planType == .hansonsHalf {
                scheduleBlock("SECONDARY WORKOUT DAY (Q2)") {
                    SingleDayPicker(
                        selected: $settings.schedule.workoutDay2,
                        disabled: [
                            settings.schedule.longRunDay,
                            settings.schedule.workoutDay1
                        ]
                    )
                }
            }

            if settings.planType.usesMidweekLongRun {
                scheduleBlock("MIDWEEK LONGER RUN DAY") {
                    SingleDayPicker(
                        selected: $settings.schedule.midweekLongDay,
                        disabled: midweekDisabled()
                    )
                }
            }

            if settings.planType.usesCrossTraining {
                scheduleBlock("CROSS-TRAINING DAY (OPTIONAL)") {
                    CreateCrossTrainToggle(
                        schedule: $settings.schedule,
                        taken:    allAssignedDays()
                    )
                }
            }

            scheduleBlock(restDaysLabel) {
                VStack(alignment: .leading, spacing: 10) {
                    MultiDayPicker(
                        selected: $settings.schedule.restDays,
                        disabled: daysBlockedFromRest()
                    )
                    HStack(spacing: 5) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text(restGuidance)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }

            let issues = liveConflicts()
            if !issues.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName:
                                "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 12))
                        Text("SCHEDULE CONFLICTS")
                            .font(.system(size: 10,
                                          weight: .semibold,
                                          design: .monospaced))
                            .foregroundColor(.orange)
                            .kerning(2)
                    }
                    ForEach(issues, id: \.self) { msg in
                        HStack(alignment: .top, spacing: 6) {
                            Text("·").foregroundColor(.secondary)
                            Text(msg)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false,
                                           vertical: true)
                        }
                    }
                    Text("Auto-resolved when plan generates.")
                        .font(.system(size: 11))
                        .foregroundColor(Color(.tertiaryLabel))
                }
                .padding(14)
                .background(Color.orange.opacity(0.06))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.2),
                                lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }

    private func scheduleBlock<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 10, weight: .semibold,
                              design: .monospaced))
                .foregroundColor(.secondary)
                .kerning(2)
                .padding(.leading, 4)
            content()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Race Type Row

    private func raceTypeRow(_ type: RaceType) -> some View {
        let isSelected = selectedRaceType == type
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedRaceType = type
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected
                              ? Color(.label)
                              : Color(.systemFill))
                        .frame(width: 38, height: 38)
                    Image(systemName: type.icon)
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(isSelected
                                         ? Color(.systemBackground)
                                         : .secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.rawValue)
                        .font(.system(size: 15,
                                      weight: isSelected
                                      ? .semibold : .regular))
                        .foregroundColor(.primary)
                    Text(type.displayDistance)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(isSelected
                                ? Color(.label)
                                : Color(.systemFill),
                                lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle()
                            .fill(Color(.label))
                            .frame(width: 10, height: 10)
                    }
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Labels

    private var planNamePlaceholder: String {
        selectedRaceType == .halfMarathon
            ? "e.g. NYC Half 2026"
            : "e.g. Boston Marathon 2026"
    }

    private var primaryWorkoutLabel: String {
        switch settings.planType {
        case .higdonIntermediate, .higdonHalfIntermediate:
            return "TEMPO DAY"
        default:
            return "PRIMARY WORKOUT DAY (Q1)"
        }
    }

    private var scheduleNote: String {
        switch settings.planType {
        case .higdon:
            return "Novice: Long run is the anchor. 2 rest days recommended."
        case .higdonIntermediate:
            return "Intermediate: Long run + midweek + tempo + optional cross-training."
        case .hansons:
            return "Six days running. One quality session. One rest day only."
        case .pfitz:
            return "Six days running. Two quality days + medium-long run mid-week."
        case .higdonHalfNovice:
            return "Three days running. Long run is the anchor. 2–3 rest days."
        case .higdonHalfIntermediate:
            return "Four to five days running. Tempo + long run anchor the week."
        case .hansonsHalf:
            return "Six days running with cumulative fatigue. One rest day only."
        case .firstHalf:
            return "Four days running. Long run Saturday, easy Tuesday, steady Thursday. 2 rest days."
        }
    }

    private var restDaysLabel: String {
        switch settings.planType {
        case .hansons, .hansonsHalf:
            return "REST DAY (1 ONLY)"
        case .pfitz:
            return "REST DAY (1 MAXIMUM)"
        case .higdon, .higdonHalfNovice, .firstHalf:
            return "REST DAYS (SELECT 2)"
        case .higdonIntermediate, .higdonHalfIntermediate:
            return "REST DAY (1 MINIMUM)"
        }
    }

    private var restGuidance: String {
        switch settings.planType {
        case .hansons, .hansonsHalf:
            return "Runs 6 days/week by design. One rest day only."
        case .pfitz:
            return "Needs 5–6 running days. Limit rest to preserve volume."
        case .higdon, .higdonHalfNovice, .firstHalf:
            return "Two rest days help absorb training."
        case .higdonIntermediate, .higdonHalfIntermediate:
            return "One rest day minimum. Cross-training covers recovery."
        }
    }

    // MARK: - Schedule Helpers

    private func daysBlockedFromRest() -> [Weekday] {
        let s = settings.schedule
        let p = settings.planType
        var hardBlocked = Set<Weekday>()
        hardBlocked.insert(s.longRunDay)
        if p != .higdon && p != .higdonHalfNovice {
            hardBlocked.insert(s.workoutDay1)
        }
        if p.requiresTwoWorkoutDays { hardBlocked.insert(s.workoutDay2) }
        if p.usesMidweekLongRun     { hardBlocked.insert(s.midweekLongDay) }
        if p.usesCrossTraining, let ct = s.crossTrainDay {
            hardBlocked.insert(ct)
        }
        let maxRestDays = 7 - minimumRunDays(for: p)
        let currentRest = s.restDays.filter {
            !hardBlocked.contains($0)
        }.count
        var blocked = Array(hardBlocked)
        if currentRest >= maxRestDays {
            blocked += Weekday.allCases.filter {
                !hardBlocked.contains($0) && !s.restDays.contains($0)
            }
        }
        return blocked
    }

    private func minimumRunDays(for plan: PlanType) -> Int {
        switch plan {
        case .hansons, .hansonsHalf: return 6
        case .pfitz:                 return 5
        default:                     return 3
        }
    }

    private func midweekDisabled() -> [Weekday] {
        let s = settings.schedule
        var d: [Weekday] = [s.longRunDay]
        d += s.restDays
        if settings.planType != .higdon
            && settings.planType != .higdonHalfNovice {
            d.append(s.workoutDay1)
        }
        if settings.planType.requiresTwoWorkoutDays {
            d.append(s.workoutDay2)
        }
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
            issues.append(
                "\(s.longRunDay.fullName) is both a rest day " +
                "and your long run day.")
        }
        if p != .higdon && p != .higdonHalfNovice
            && s.restDays.contains(s.workoutDay1) {
            issues.append(
                "\(s.workoutDay1.fullName) is both a rest day " +
                "and a workout day.")
        }
        if p.requiresTwoWorkoutDays
            && s.restDays.contains(s.workoutDay2) {
            issues.append(
                "\(s.workoutDay2.fullName) is both a rest day " +
                "and a workout day.")
        }
        if p.requiresTwoWorkoutDays
            && s.workoutDay1 == s.workoutDay2 {
            issues.append("Q1 and Q2 are on the same day.")
        }
        if p.usesMidweekLongRun
            && s.midweekLongDay == s.longRunDay {
            issues.append(
                "Midweek run and long run are on the same day.")
        }
        return issues
    }

    // MARK: - Actions

    private func handleRaceTypeChange() {
        if let first = PlanType.options(for: selectedRaceType).first {
            settings.planType = first
            settings.resetScheduleForNewPlanType()
        }

        // CHANGED: Half marathon defaults to 12 weeks (Standard), not the first
        // option in the array (10 weeks). 12 weeks is the right default for most
        // runners — enough time to build confidently without over-committing.
        // Marathon keeps its first option (12 weeks).
        if selectedRaceType == .halfMarathon {
            settings.planLength = .twelveWeek
        } else if let first = PlanLength.options(for: selectedRaceType).first {
            settings.planLength = first
        }

        goalHours   = selectedRaceType == .halfMarathon ? 1 : 3
        goalMinutes = 45
        updateGoalTime()
    }

    private func updateGoalTime() {
        settings.goalTimeMinutes = goalHours * 60 + goalMinutes
    }

    private func generatePlan() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIApplication.shared.dismissKeyboard()
        updateGoalTime()
        isGenerating = true
        let capturedSettings = settings
        let capturedName     = planName.trimmingCharacters(
            in: .whitespaces)
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

struct CreatePlanTypeRow: View {
    let plan       : PlanType
    let isSelected : Bool
    let onTap      : () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected
                                ? Color.accentColor
                                : Color(.systemFill),
                                lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 10, height: 10)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.rawValue)
                        .font(.system(size: 14,
                                      weight: isSelected
                                      ? .semibold : .regular))
                        .foregroundColor(.primary)
                    Text(plan.description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
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
                              weight: isSelected
                              ? .semibold : .regular,
                              design: .monospaced))
                .foregroundColor(isSelected
                                 ? Color(.systemBackground)
                                 : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected
                            ? Color(.label)
                            : Color(.systemFill))
                .cornerRadius(10)
                .animation(.easeInOut(duration: 0.15),
                           value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct CreateCrossTrainToggle: View {
    @Binding var schedule : UserSchedule
    let taken             : [Weekday]

    var body: some View {
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
                                Weekday.allCases.first {
                                    !t.contains($0)
                                }
                        } else {
                            schedule.crossTrainDay = nil
                        }
                    }
                ))
                .labelsHidden()
            }
            if schedule.crossTrainDay != nil {
                Divider().padding(.vertical, 12)
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
                                .font(.system(
                                    size: 11,
                                    weight: isSel
                                        ? .semibold : .regular,
                                    design: .monospaced))
                                .foregroundColor(
                                    isDis
                                        ? Color(.tertiaryLabel)
                                        : isSel
                                            ? Color(.systemBackground)
                                            : .secondary
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    isDis
                                        ? Color(.tertiarySystemFill)
                                        : isSel
                                            ? Color(.label)
                                            : Color(.systemFill)
                                )
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(isDis)
                    }
                }
            }
        }
    }
}

struct CreateLabel: View {
    let title: String
    init(_ t: String) { title = t }
    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold,
                          design: .monospaced))
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
            .font(.system(size: 10, weight: .semibold,
                          design: .monospaced))
            .foregroundColor(.secondary)
            .kerning(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 20)
            .padding(.bottom, 8)
    }
}
