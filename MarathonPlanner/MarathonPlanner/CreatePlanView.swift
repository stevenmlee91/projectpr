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
    @EnvironmentObject var store : PlanStore
    @Environment(\.dismiss) var dismiss

    /// Called with the new plan's UUID just before the view dismisses.
    /// PlanListView uses this to push straight to the new plan.
    var onPlanCreated: ((UUID) -> Void)? = nil

    @FocusState private var nameFieldFocused: Bool

    @State private var step             = 0
    @State private var goingForward     = true
    @State private var selectedRaceType = RaceType.marathon
    @State private var planName         = ""
    @State private var raceDate         = Date().addingTimeInterval(60 * 60 * 24 * 112)
    @State private var settings         = UserSettings()
    @State private var goalHours        = 3
    @State private var goalMinutes      = 30
    @State private var isGenerating     = false

    private let totalSteps = 5

    private var availablePlanTypes: [PlanType] {
        PlanType.options(for: selectedRaceType)
    }
    private var availableLengths: [PlanLength] {
        PlanLength.options(for: selectedRaceType)
    }
    private var goalHourRange: [Int] {
        selectedRaceType == .halfMarathon ? Array(1...3) : Array(2...6)
    }
    private var isReadyToGenerate: Bool {
        !planName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var startDate: Date {
        var cal          = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2; cal.timeZone = .current
        let weekday         = cal.component(.weekday, from: raceDate)
        let daysSinceMonday = (weekday + 5) % 7
        guard let raceWeekMonday = cal.date(
            byAdding: .day, value: -daysSinceMonday,
            to: cal.startOfDay(for: raceDate)
        ) else { return raceDate }
        return cal.date(
            byAdding: .weekOfYear,
            value: -(settings.planLength.rawValue - 1),
            to: raceWeekMonday
        ) ?? raceDate
    }

    private let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; return f
    }()

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            Group {
                switch step {
                case 0: nameStep
                case 1: raceTypeStep
                case 2: methodStep
                case 3: fitnessStep
                case 4: scheduleStep
                case 5: finalStep
                default: nameStep
                }
            }
            .transition(pageTransition)
        }
        .onChange(of: goalHours)        { _ in updateGoalTime() }
        .onChange(of: goalMinutes)      { _ in updateGoalTime() }
        .onChange(of: selectedRaceType) { _ in handleRaceTypeChange() }
    }

    // MARK: - Transitions

    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: goingForward ? .trailing : .leading).combined(with: .opacity),
            removal:   .move(edge: goingForward ? .leading  : .trailing).combined(with: .opacity)
        )
    }

    private func advance() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        goingForward = true
        withAnimation(.easeInOut(duration: 0.3)) { step += 1 }
    }

    private func retreat() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        goingForward = false
        withAnimation(.easeInOut(duration: 0.3)) { step -= 1 }
    }

    // MARK: - Progress Bar

    private func progressBar(current: Int) -> some View {
        HStack(spacing: 5) {
            ForEach(1...totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= current ? Color.primary : Color(.systemFill))
                    .frame(height: 3)
                    .animation(.easeInOut(duration: 0.4), value: current)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 0: Name + Race Date

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("NEW PLAN")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .kerning(2)
                Spacer()
                Button("Cancel") { dismiss() }
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 36)

            Text("What race\nare we building\nfor?")
                .font(.system(size: 32, weight: .light, design: .serif))
                .foregroundColor(.primary)
                .lineSpacing(5)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)

            VStack(alignment: .leading, spacing: 8) {
                Text("PLAN NAME")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .kerning(1.5)
                HStack(spacing: 12) {
                    TextField("e.g. Boston Marathon 2026", text: $planName)
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                        .focused($nameFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { nameFieldFocused = false }
                        .tint(.primary)
                    if !planName.isEmpty {
                        Button {
                            planName = ""; nameFieldFocused = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(Color(.systemGray3))
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 16)
                .background(Color(.secondarySystemBackground)).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(nameFieldFocused ? Color(.label).opacity(0.25) : Color.clear,
                            lineWidth: 1.5))
                .animation(.easeInOut(duration: 0.2), value: nameFieldFocused)
            }
            .animation(.easeInOut(duration: 0.2), value: planName.isEmpty)
            .padding(.horizontal, 24).padding(.bottom, 16)

            VStack(alignment: .leading, spacing: 8) {
                Text("RACE DATE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary).kerning(1.5)
                VStack(spacing: 0) {
                    DatePicker("Race Date", selection: $raceDate,
                               displayedComponents: .date)
                        .datePickerStyle(.compact).foregroundColor(.primary)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                    Divider().padding(.horizontal, 16)
                    HStack {
                        Label("Plan starts", systemImage: "calendar")
                            .font(.system(size: 12)).foregroundColor(.secondary)
                        Spacer()
                        Text(dateFmt.string(from: startDate))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                .background(Color(.secondarySystemBackground)).cornerRadius(12)
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 0) {
                LinearGradient(colors: [Color(.systemBackground).opacity(0),
                                        Color(.systemBackground)],
                               startPoint: .top, endPoint: .bottom).frame(height: 28)
                Button {
                    nameFieldFocused = false; advance()
                } label: {
                    Text("Next")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(isReadyToGenerate
                                         ? Color(.systemBackground)
                                         : Color(.systemBackground).opacity(0.4))
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(isReadyToGenerate ? Color(.label) : Color(.systemGray3))
                        .cornerRadius(14)
                        .animation(.easeInOut(duration: 0.2), value: isReadyToGenerate)
                }
                .buttonStyle(.plain).disabled(!isReadyToGenerate)
                .padding(.horizontal, 24).padding(.bottom, 48)
                .background(Color(.systemBackground))
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                nameFieldFocused = true
            }
        }
        .onTapGesture { UIApplication.shared.dismissKeyboard() }
    }

    // MARK: - Step 1: Race Type

    private var raceTypeStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(step: 1, title: "What are you\ntraining for?", note: nil)
            VStack(spacing: 12) {
                ForEach(RaceType.allCases, id: \.self) { raceTypeCard($0) }
            }
            .padding(.horizontal, 24)
            Spacer()
            stepFooter(onBack: { retreat() }, onNext: { advance() }, nextLabel: "Next")
        }
    }

    private func raceTypeCard(_ type: RaceType) -> some View {
        let isSelected = selectedRaceType == type
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.15)) { selectedRaceType = type }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: type.icon)
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .frame(width: 32, alignment: .center)
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.rawValue)
                        .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(.primary)
                    Text(type.displayDistance)
                        .font(.system(size: 12, design: .monospaced)).foregroundColor(.secondary)
                }
                Spacer()
                ZStack {
                    Circle().stroke(isSelected ? Color.primary : Color(.tertiaryLabel),
                                    lineWidth: 1.5).frame(width: 22, height: 22)
                    if isSelected { Circle().fill(Color.primary).frame(width: 12, height: 12) }
                }
                .animation(.easeInOut(duration: 0.15), value: isSelected)
            }
            .padding(.horizontal, 20).padding(.vertical, 20)
            .background(Color(.secondarySystemBackground)).cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.primary.opacity(0.25) : Color.clear, lineWidth: 1.5))
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 2: Method

    private var methodStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(
                step: 2, title: "Choose your\napproach.",
                note: "The right plan isn't the hardest one. It's the one that fits how you actually train."
            )
            ScrollView(showsIndicators: false) {
                VStack(spacing: 1) {
                    ForEach(availablePlanTypes) { plan in
                        methodRow(plan)
                        if plan != availablePlanTypes.last {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .background(Color(.secondarySystemBackground)).cornerRadius(14)
                .padding(.horizontal, 24).padding(.bottom, 120)
            }
            stepFooter(onBack: { retreat() }, onNext: { advance() }, nextLabel: "Next")
        }
    }

    private func methodRow(_ plan: PlanType) -> some View {
        let isSelected = settings.planType == plan
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            settings.planType = plan
            settings.resetScheduleForNewPlanType()
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle().stroke(isSelected ? Color.primary : Color(.tertiaryLabel),
                                    lineWidth: 1.5).frame(width: 18, height: 18)
                    if isSelected { Circle().fill(Color.primary).frame(width: 10, height: 10) }
                }
                .padding(.top, 2)
                .animation(.easeInOut(duration: 0.15), value: isSelected)
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.rawValue)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(.primary)
                    Text(plan.description)
                        .font(.system(size: 11)).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2).lineLimit(3)
                }
                Spacer()
            }
            .padding(.horizontal, 20).padding(.vertical, 16).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 3: Fitness

    private var fitnessStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(step: 3, title: "Where are\nyou right now?", note: nil)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    baseMileageCard
                    goalTimeCard
                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 24)
            }
            stepFooter(onBack: { retreat() }, onNext: { advance() }, nextLabel: "Next")
        }
    }

    private var baseMileageCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CURRENT WEEKLY MILEAGE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary).kerning(1.5)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Int(settings.baseMileage))")
                        .font(.system(size: 52, weight: .thin, design: .monospaced))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: settings.baseMileage)
                    Text(settings.baseMileage == 0 ? "just getting started" : "miles per week, right now")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                        .animation(.easeInOut(duration: 0.2), value: settings.baseMileage)
                }
                Spacer()
                VStack(spacing: 8) {
                    Button {
                        if settings.baseMileage < 80 {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            settings.baseMileage += 5
                        }
                    } label: {
                        Image(systemName: "plus").font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary).frame(width: 44, height: 44)
                            .background(Color(.systemFill)).cornerRadius(10)
                    }.buttonStyle(.plain)
                    Button {
                        if settings.baseMileage > 0 {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            settings.baseMileage -= 5
                        }
                    } label: {
                        Image(systemName: "minus").font(.system(size: 15, weight: .medium))
                            .foregroundColor(settings.baseMileage == 0 ? Color(.systemGray3) : .primary)
                            .frame(width: 44, height: 44).background(Color(.systemFill)).cornerRadius(10)
                    }.buttonStyle(.plain).disabled(settings.baseMileage == 0)
                }
            }
            Text("Not what you want to run — what you actually run right now. Honesty here matters more than ambition.")
                .font(.system(size: 12)).foregroundColor(Color(.tertiaryLabel))
                .fixedSize(horizontal: false, vertical: true).lineSpacing(2)
        }
        .padding(20).background(Color(.secondarySystemBackground)).cornerRadius(14)
    }

    private var goalTimeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("GOAL TIME")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary).kerning(1.5)
            HStack(spacing: 0) {
                Picker("", selection: $goalHours) {
                    ForEach(goalHourRange, id: \.self) { h in Text("\(h)h").tag(h) }
                }.pickerStyle(.wheel).frame(maxWidth: .infinity)
                Text(":").font(.system(size: 24, weight: .thin)).foregroundColor(.secondary)
                Picker("", selection: $goalMinutes) {
                    ForEach([0,5,10,15,20,25,30,35,40,45,50,55], id: \.self) { m in
                        Text(String(format: "%02dm", m)).tag(m)
                    }
                }.pickerStyle(.wheel).frame(maxWidth: .infinity)
            }
            .frame(height: 110)
            Text("Set a goal that excites you and scares you a little. The plan will be built around it.")
                .font(.system(size: 12)).foregroundColor(Color(.tertiaryLabel))
                .fixedSize(horizontal: false, vertical: true).lineSpacing(2)
        }
        .padding(20).background(Color(.secondarySystemBackground)).cornerRadius(14)
    }

    // MARK: - Step 4: Schedule (inline)

    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(
                step: 4,
                title: "When do you\nwant to run?",
                note: "Pick which days work best for your training. The plan will fit itself around them."
            )
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    // Long run day
                    scheduleDayRow(
                        label:  "LONG RUN DAY",
                        note:   "Usually Saturday or Sunday. The week's hardest effort.",
                        days:   Weekday.displayOrder,
                        selected:    [settings.schedule.longRunDay],
                        blocked:     [],
                        multiSelect: false
                    ) { day in
                        settings.schedule.longRunDay = day
                        // Remove from rest days if accidentally overlapping
                        settings.schedule.restDays.removeAll { $0 == day }
                    }

                    // Q1 workout day — plans that have a quality day
                    if needsWorkoutDay1 {
                        scheduleDayRow(
                            label:  q1Label,
                            note:   "A separate day from your long run, mid-week works well.",
                            days:   Weekday.displayOrder,
                            selected:    [settings.schedule.workoutDay1],
                            blocked:     [settings.schedule.longRunDay],
                            multiSelect: false
                        ) { day in
                            settings.schedule.workoutDay1 = day
                            settings.schedule.restDays.removeAll { $0 == day }
                        }
                    }

                    // Q2 workout day — Hansons and Pfitz only
                    if needsWorkoutDay2 {
                        scheduleDayRow(
                            label:  "SECOND QUALITY DAY",
                            note:   "Keep at least one easy day between quality sessions.",
                            days:   Weekday.displayOrder,
                            selected:    [settings.schedule.workoutDay2],
                            blocked:     [settings.schedule.longRunDay,
                                         settings.schedule.workoutDay1],
                            multiSelect: false
                        ) { day in
                            settings.schedule.workoutDay2 = day
                            settings.schedule.restDays.removeAll { $0 == day }
                        }
                    }

                    // Rest days
                    scheduleDayRow(
                        label:  restDaysLabel,
                        note:   restDaysNote,
                        days:   Weekday.displayOrder,
                        selected:    settings.schedule.restDays,
                        blocked:     blockedFromRest,
                        multiSelect: true
                    ) { day in
                        toggleRestDay(day)
                    }

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 24)
            }
            stepFooter(onBack: { retreat() }, onNext: { advance() }, nextLabel: "Next")
        }
    }

    /// A single labeled row of 7 day-of-week buttons.
    private func scheduleDayRow(
        label       : String,
        note        : String,
        days        : [Weekday],
        selected    : [Weekday],
        blocked     : [Weekday],
        multiSelect : Bool,
        onTap       : @escaping (Weekday) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
                .kerning(1.5)

            HStack(spacing: 4) {
                ForEach(days, id: \.self) { day in
                    let isSel  = selected.contains(day)
                    let isBlk  = blocked.contains(day)
                    Button {
                        guard !isBlk else { return }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onTap(day)
                    } label: {
                        Text(day.name)
                            .font(.system(size: 11,
                                          weight: isSel ? .semibold : .regular,
                                          design: .monospaced))
                            .foregroundColor(
                                isBlk ? Color(.tertiaryLabel)
                                    : isSel ? Color(.systemBackground)
                                    : .primary
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(
                                isBlk ? Color(.tertiarySystemFill)
                                    : isSel ? Color(.label)
                                    : Color(.systemFill)
                            )
                            .cornerRadius(8)
                            .animation(.easeInOut(duration: 0.12), value: isSel)
                    }
                    .buttonStyle(.plain)
                    .disabled(isBlk)
                }
            }

            Text(note)
                .font(.system(size: 11))
                .foregroundColor(Color(.tertiaryLabel))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }

    // MARK: - Step 5: Duration + Generate

    private var finalStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(step: 5, title: "Last few\ndetails.", note: nil)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    durationCard
                    Spacer().frame(height: 120)
                }
                .padding(.horizontal, 24)
            }
            generateFooter
        }
    }

    private var durationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PLAN LENGTH")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary).kerning(1.5)
            HStack(spacing: 8) {
                ForEach(availableLengths) { length in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        settings.planLength = length
                    } label: {
                        Text(length.label)
                            .font(.system(size: 12,
                                          weight: settings.planLength == length ? .semibold : .regular,
                                          design: .monospaced))
                            .foregroundColor(settings.planLength == length
                                             ? Color(.systemBackground) : .secondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(settings.planLength == length ? Color(.label) : Color(.systemFill))
                            .cornerRadius(10)
                            .animation(.easeInOut(duration: 0.15), value: settings.planLength == length)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20).background(Color(.secondarySystemBackground)).cornerRadius(14)
    }

    private var generateFooter: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Color(.systemBackground).opacity(0),
                                    Color(.systemBackground)],
                           startPoint: .top, endPoint: .bottom).frame(height: 28)
            HStack(spacing: 12) {
                Button { retreat() } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 14, weight: .medium)).foregroundColor(.primary)
                        .frame(width: 52, height: 52).background(Color(.systemFill)).cornerRadius(14)
                }.buttonStyle(.plain)

                Button(action: generatePlan) {
                    HStack(spacing: 10) {
                        if isGenerating {
                            ProgressView().tint(Color(.systemBackground)).scaleEffect(0.85)
                        } else {
                            Image(systemName: "figure.run").font(.system(size: 14, weight: .medium))
                        }
                        Text(isGenerating ? "BUILDING..." : "BUILD MY PLAN")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .kerning(1.5)
                    }
                    .foregroundColor(Color(.systemBackground))
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(Color(.label)).cornerRadius(14)
                }
                .buttonStyle(.plain).disabled(isGenerating)
            }
            .padding(.horizontal, 24).padding(.bottom, 48)
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Shared Components

    private func stepHeader(step: Int, title: String, note: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if step == 1 {
                HStack {
                    Spacer()
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 15)).foregroundColor(.primary)
                }
                .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 8)
            } else {
                Spacer().frame(height: 20)
            }
            progressBar(current: step).padding(.bottom, 32)
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 32, weight: .light, design: .serif))
                    .foregroundColor(.primary).lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                if let note {
                    Text(note)
                        .font(.system(size: 13)).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true).lineSpacing(3)
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 28)
        }
    }

    private func stepFooter(
        onBack    : @escaping () -> Void,
        onNext    : @escaping () -> Void,
        nextLabel : String
    ) -> some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Color(.systemBackground).opacity(0),
                                    Color(.systemBackground)],
                           startPoint: .top, endPoint: .bottom).frame(height: 28)
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 14, weight: .medium)).foregroundColor(.primary)
                        .frame(width: 52, height: 52).background(Color(.systemFill)).cornerRadius(14)
                }.buttonStyle(.plain)
                Button(action: onNext) {
                    Text(nextLabel)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(.systemBackground))
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(Color(.label)).cornerRadius(14)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 24).padding(.bottom, 48)
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Schedule Helpers

    private var needsWorkoutDay1: Bool {
        settings.planType != .higdon
            && settings.planType != .higdonHalfNovice
            && settings.planType != .firstHalf
    }

    private var needsWorkoutDay2: Bool {
        settings.planType == .hansons
            || settings.planType == .pfitz
            || settings.planType == .hansonsHalf
    }

    private var q1Label: String {
        switch settings.planType {
        case .higdonIntermediate, .higdonHalfIntermediate: return "TEMPO DAY"
        default: return "QUALITY DAY"
        }
    }

    private var restDaysLabel: String {
        switch settings.planType {
        case .hansons, .hansonsHalf:    return "REST DAY"
        case .pfitz:                    return "REST DAY"
        default:                        return "REST DAYS"
        }
    }

    private var restDaysNote: String {
        switch settings.planType {
        case .hansons, .hansonsHalf:    return "Runs 6 days a week by design. One rest day only."
        case .pfitz:                    return "5–6 running days. Limit rest to preserve volume."
        case .higdon, .higdonHalfNovice, .firstHalf:
                                        return "Two rest days help absorb training. Select two."
        default:                        return "At least one full rest day per week."
        }
    }

    private var blockedFromRest: [Weekday] {
        var blocked = Set<Weekday>()
        blocked.insert(settings.schedule.longRunDay)
        if needsWorkoutDay1 { blocked.insert(settings.schedule.workoutDay1) }
        if needsWorkoutDay2 { blocked.insert(settings.schedule.workoutDay2) }
        return Array(blocked)
    }

    private func toggleRestDay(_ day: Weekday) {
        if settings.schedule.restDays.contains(day) {
            settings.schedule.restDays.removeAll { $0 == day }
        } else {
            settings.schedule.restDays.append(day)
        }
    }

    // MARK: - Plan Generation

    private func generatePlan() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        updateGoalTime()
        isGenerating = true
        let capturedSettings = settings
        let capturedName     = planName.trimmingCharacters(in: .whitespaces)
        let capturedDate     = raceDate
        DispatchQueue.global(qos: .userInitiated).async {
            let rawPlan = createSavedPlan(
                name:     capturedName,
                raceDate: capturedDate,
                settings: capturedSettings
            )
            let (plan, _) = PlanCorrector.autocorrect(rawPlan)
            DispatchQueue.main.async {
                store.savePlan(plan)
                isGenerating = false
                onPlanCreated?(plan.id)
                dismiss()
            }
        }
    }

    // MARK: - Helpers

    private func handleRaceTypeChange() {
        if let first = PlanType.options(for: selectedRaceType).first {
            settings.planType = first
            settings.resetScheduleForNewPlanType()
        }
        if selectedRaceType == .halfMarathon {
            settings.planLength = .twelveWeek
            goalHours = 1; goalMinutes = 45
        } else {
            if let first = PlanLength.options(for: selectedRaceType).first {
                settings.planLength = first
            }
            goalHours = 3; goalMinutes = 30
        }
        updateGoalTime()
    }

    private func updateGoalTime() {
        settings.goalTimeMinutes = goalHours * 60 + goalMinutes
    }
}
