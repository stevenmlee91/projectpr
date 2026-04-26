import SwiftUI

// MARK: - Schedule Setup View
//
// Every picker and chip writes DIRECTLY into settings.schedule
// using $settings.schedule.fieldName bindings.
// There are no intermediate @State copies. No data loss possible.

struct ScheduleSetupView: View {
    @Binding var settings: UserSettings

    private var plan: PlanType { settings.planType }

    private var conflicts: [String] {
        var issues: [String] = []
        let s = settings.schedule

        if s.restDays.contains(s.longRunDay) {
            issues.append("\(s.longRunDay.fullName) is set as both a rest day and your long run day.")
        }
        if plan != .higdon && s.restDays.contains(s.workoutDay1) {
            issues.append("\(s.workoutDay1.fullName) is set as both a rest day and Workout Day 1.")
        }
        if plan.requiresTwoWorkoutDays && s.restDays.contains(s.workoutDay2) {
            issues.append("\(s.workoutDay2.fullName) is set as both a rest day and Workout Day 2.")
        }
        if plan.requiresTwoWorkoutDays && s.workoutDay1 == s.workoutDay2 {
            issues.append("Workout Day 1 and Workout Day 2 are the same day (\(s.workoutDay1.fullName)).")
        }
        if plan.usesMidweekLongRun && s.midweekLongDay == s.longRunDay {
            issues.append("Midweek longer run and long run are both on \(s.longRunDay.fullName).")
        }
        if let ct = s.crossTrainDay, s.restDays.contains(ct) {
            issues.append("\(ct.fullName) is set as both a rest day and cross-training day.")
        }
        return issues
    }

    var body: some View {
        ZStack {
            Color(hex: "0F0F0F").ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    Group {
                        headerView
                        longRunSection
                        workoutDaySection
                    }
                    Group {
                        restDaySection
                        advancedSection
                        conflictView
                        Spacer().frame(height: 50)
                    }
                }
            }
        }
        .navigationTitle("Weekly Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .colorScheme(.dark)
    }

    // MARK: Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WEEKLY SCHEDULE")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "5E5E5E"))
                .kerning(3)
            Text("Choose Your Days")
                .font(.system(size: 26, weight: .light, design: .serif))
                .foregroundColor(.white)
            Text(planNote)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "5E5E5E"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 28)
    }

    private var planNote: String {
        switch plan {
        case .higdon:
            return "Novice: Long run + midweek run + 2 rest days. Simple and consistent."
        case .higdonIntermediate:
            return "Intermediate: Long run + midweek run + tempo + optional cross-training + 1 rest day."
        case .hansons:
            return "Six days running, one quality day per week. Speed first, then Strength/MP runs."
        case .pfitz:
            return "Six days running, two quality days + a medium-long run mid-week. High aerobic demand."
        case .jackDaniels:
            return "Two anchor quality sessions (Q1 & Q2). All other days strictly easy."
        }
    }

    // MARK: Long Run Day

    private var longRunSection: some View {
        VStack(spacing: 0) {
            ScheduleLabel("LONG RUN DAY")
            // Single-select — binding writes directly into schedule
            SingleDayPicker(
                selected: $settings.schedule.longRunDay,
                disabled: []
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: Workout Days

    private var workoutDaySection: some View {
        VStack(spacing: 0) {
            // Primary quality day (hidden for Higdon Novice — no quality work)
            if plan != .higdon {
                ScheduleLabel(plan == .higdonIntermediate
                    ? "TEMPO DAY"
                    : "PRIMARY WORKOUT DAY (Q1)")
                SingleDayPicker(
                    selected: $settings.schedule.workoutDay1,
                    disabled: [settings.schedule.longRunDay]
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }

            // Secondary quality day (Hansons, Pfitz, Daniels)
            if plan == .hansons || plan == .pfitz || plan == .jackDaniels {
                ScheduleLabel("SECONDARY WORKOUT DAY (Q2)")
                SingleDayPicker(
                    selected: $settings.schedule.workoutDay2,
                    disabled: [settings.schedule.longRunDay,
                               settings.schedule.workoutDay1]
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: Rest Days

    private var restDaySection: some View {
        VStack(spacing: 0) {
            ScheduleLabel(restLabel)

            // Multi-select — binding writes array directly into schedule.restDays
            MultiDayPicker(
                selected: $settings.schedule.restDays,
                disabled: blockedFromRest()
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // Helper note
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "3A3A3A"))
                Text("Days already assigned to a run cannot be rest days.")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "3A3A3A"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private var restLabel: String {
        if plan.allowsZeroRestDays { return "REST DAYS (OPTIONAL)" }
        if plan == .higdon         { return "REST DAYS (2 RECOMMENDED)" }
        return "REST DAYS (1 MINIMUM)"
    }

    // MARK: Advanced

    private var advancedSection: some View {
        VStack(spacing: 0) {
            // Midweek longer run day — Higdon + Pfitz
            if plan.usesMidweekLongRun {
                ScheduleLabel("MIDWEEK LONGER RUN DAY")
                SingleDayPicker(
                    selected: $settings.schedule.midweekLongDay,
                    disabled: midweekDisabled()
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }

            // Cross-training toggle — Higdon Intermediate only
            if plan.usesCrossTraining {
                ScheduleLabel("CROSS-TRAINING DAY (OPTIONAL)")
                CrossTrainToggle(
                    schedule: $settings.schedule,
                    taken: allTaken()
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: Conflict Banner

    private var conflictView: some View {
        Group {
            if !conflicts.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 13))
                        Text("CONFLICTS DETECTED")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.orange)
                            .kerning(2)
                    }
                    ForEach(conflicts, id: \.self) { msg in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•").foregroundColor(Color(hex: "5E5E5E"))
                            Text(msg)
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "9A9A9A"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Text("These will be auto-resolved when you generate your plan.")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "4A4A4A"))
                        .padding(.top, 2)
                }
                .padding(16)
                .background(Color(hex: "1A1A1A"))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: Helpers

    private func blockedFromRest() -> [Weekday] {
        var b = [settings.schedule.longRunDay,
                 settings.schedule.midweekLongDay]
        if plan != .higdon             { b.append(settings.schedule.workoutDay1) }
        if plan.requiresTwoWorkoutDays { b.append(settings.schedule.workoutDay2) }
        if let ct = settings.schedule.crossTrainDay { b.append(ct) }
        return b
    }

    private func midweekDisabled() -> [Weekday] {
        var d = [settings.schedule.longRunDay]
        d += settings.schedule.restDays
        if plan != .higdon             { d.append(settings.schedule.workoutDay1) }
        if plan.requiresTwoWorkoutDays { d.append(settings.schedule.workoutDay2) }
        return d
    }

    private func allTaken() -> [Weekday] {
        var t = [settings.schedule.longRunDay,
                 settings.schedule.workoutDay1,
                 settings.schedule.workoutDay2,
                 settings.schedule.midweekLongDay]
        t += settings.schedule.restDays
        if let ct = settings.schedule.crossTrainDay { t.append(ct) }
        return t
    }
}

// MARK: - Single Day Picker
// Tapping a chip sets it as the selection.
// Binding<Weekday> writes directly into the parent struct field.

struct SingleDayPicker: View {
    @Binding var selected : Weekday
    let disabled          : [Weekday]

    var body: some View {
        ZStack {
            Color(hex: "1A1A1A")
            HStack(spacing: 5) {
                ForEach(Weekday.allCases) { day in
                    let isSel = selected == day
                    let isDis = disabled.contains(day)
                    Button {
                        guard !isDis else { return }
                        selected = day
                    } label: {
                        Text(day.name)
                            .font(.system(size: 11,
                                          weight: isSel ? .semibold : .regular,
                                          design: .monospaced))
                            .foregroundColor(chipText(isSel, isDis))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(chipBg(isSel, isDis))
                            .cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDis)
                }
            }
            .padding(10)
        }
        .cornerRadius(12)
    }

    func chipText(_ sel: Bool, _ dis: Bool) -> Color {
        dis ? Color(hex: "2A2A2A") : sel ? Color(hex: "0F0F0F") : Color(hex: "5E5E5E")
    }
    func chipBg(_ sel: Bool, _ dis: Bool) -> Color {
        dis ? Color(hex: "1C1C1C") : sel ? .white : Color(hex: "242424")
    }
}

// MARK: - Multi Day Picker
// Tapping a chip toggles it in/out of the selection array.
// Binding<[Weekday]> writes directly into schedule.restDays.

struct MultiDayPicker: View {
    @Binding var selected : [Weekday]
    let disabled          : [Weekday]

    var body: some View {
        ZStack {
            Color(hex: "1A1A1A")
            HStack(spacing: 5) {
                ForEach(Weekday.allCases) { day in
                    let isSel = selected.contains(day)
                    let isDis = disabled.contains(day)
                    Button {
                        guard !isDis else { return }
                        if isSel {
                            selected.removeAll { $0 == day }
                        } else {
                            selected.append(day)
                        }
                    } label: {
                        Text(day.name)
                            .font(.system(size: 11,
                                          weight: isSel ? .semibold : .regular,
                                          design: .monospaced))
                            .foregroundColor(chipText(isSel, isDis))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(chipBg(isSel, isDis))
                            .cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDis)
                }
            }
            .padding(10)
        }
        .cornerRadius(12)
    }

    func chipText(_ sel: Bool, _ dis: Bool) -> Color {
        dis ? Color(hex: "2A2A2A") : sel ? Color(hex: "0F0F0F") : Color(hex: "5E5E5E")
    }
    func chipBg(_ sel: Bool, _ dis: Bool) -> Color {
        dis ? Color(hex: "1C1C1C") : sel ? .white : Color(hex: "242424")
    }
}

// MARK: - Cross Train Toggle

struct CrossTrainToggle: View {
    @Binding var schedule : UserSchedule
    let taken             : [Weekday]

    var body: some View {
        ZStack {
            Color(hex: "1A1A1A")
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Include Cross-Training Day")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                        Text("Cycling, swimming, elliptical, yoga")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "5E5E5E"))
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { schedule.crossTrainDay != nil },
                        set: { on in
                            if on {
                                let t = Set(taken)
                                schedule.crossTrainDay = Weekday.allCases.first { !t.contains($0) }
                            } else {
                                schedule.crossTrainDay = nil
                            }
                        }
                    ))
                    .labelsHidden()
                    .tint(.white)
                }
                .padding(16)

                if schedule.crossTrainDay != nil {
                    Divider().background(Color(hex: "2A2A2A"))
                    HStack(spacing: 5) {
                        ForEach(Weekday.allCases) { day in
                            let isSel = schedule.crossTrainDay == day
                            let isDis = taken.contains(day) && schedule.crossTrainDay != day
                            Button {
                                guard !isDis else { return }
                                schedule.crossTrainDay = day
                            } label: {
                                Text(day.name)
                                    .font(.system(size: 11,
                                                  weight: isSel ? .semibold : .regular,
                                                  design: .monospaced))
                                    .foregroundColor(
                                        isDis ? Color(hex: "2A2A2A") :
                                        isSel ? Color(hex: "0F0F0F") :
                                                Color(hex: "5E5E5E"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .background(
                                        isDis ? Color(hex: "1C1C1C") :
                                        isSel ? Color.white :
                                                Color(hex: "242424"))
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

// MARK: - Section Label

struct ScheduleLabel: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(Color(hex: "3E3E3E"))
            .kerning(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 20)
            .padding(.bottom, 8)
    }
}
