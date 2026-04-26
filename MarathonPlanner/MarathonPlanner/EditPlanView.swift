import SwiftUI

struct EditPlanView: View {
    @EnvironmentObject var store : PlanStore
    @Environment(\.dismiss) var dismiss

    let plan: SavedPlan

    @State private var editedSettings : UserSettings
    @State private var goalHours      : Int
    @State private var goalMinutes    : Int
    @State private var isSaving       = false
    @State private var showPreview    = false

    init(plan: SavedPlan) {
        self.plan = plan
        _editedSettings = State(initialValue: plan.settings)
        let h = plan.settings.goalTimeMinutes / 60
        let m = plan.settings.goalTimeMinutes % 60
        _goalHours   = State(initialValue: h)
        _goalMinutes = State(initialValue: m)
    }

    private var requiresFullRegen: Bool {
        editedSettings.goalTimeMinutes != plan.settings.goalTimeMinutes
        || editedSettings.baseMileage  != plan.settings.baseMileage
        || editedSettings.planType     != plan.settings.planType
        || editedSettings.planLength   != plan.settings.planLength
    }

    private var hasAnyChange: Bool {
        editedSettings.goalTimeMinutes != plan.settings.goalTimeMinutes
        || editedSettings.baseMileage  != plan.settings.baseMileage
        || editedSettings.planType     != plan.settings.planType
        || editedSettings.planLength   != plan.settings.planLength
        || editedSettings.schedule     != plan.settings.schedule
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0F0F0F").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        Group {
                            editHeader
                            planTypeSection
                            goalTimeSection
                            baseMileageSection
                            planLengthSection
                        }
                        Group {
                            longRunDaySection
                            primaryWorkoutSection
                            secondaryWorkoutSection
                        }
                        Group {
                            midweekLongSection
                            crossTrainSection
                            restDaysSection
                        }
                        Group {
                            conflictWarningsView
                            if showPreview { previewSection }
                            saveSection
                            Spacer().frame(height: 60)
                        }
                    }
                }
            }
            .navigationTitle("Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        .colorScheme(.dark)
        .onChange(of: goalHours)   { _ in syncGoalTime() }
        .onChange(of: goalMinutes) { _ in syncGoalTime() }
    }

    // MARK: - Header

    private var editHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EDITING")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "5E5E5E"))
                .kerning(3)
            Text(plan.name)
                .font(.system(size: 24, weight: .light, design: .serif))
                .foregroundColor(.white)

            if requiresFullRegen {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Text("Changes will trigger a full plan regeneration")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
                .padding(.top, 4)
            } else if hasAnyChange {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "30D158"))
                    Text("Workouts will reflow onto new days")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "30D158"))
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }

    // MARK: - Plan Type

    private var planTypeSection: some View {
        VStack(spacing: 0) {
            EditLabel("PLAN TYPE")
            VStack(spacing: 1) {
                ForEach(PlanType.allCases) { p in
                    EditPlanTypeRow(
                        plan:       p,
                        isSelected: editedSettings.planType == p,
                        onTap: {
                            editedSettings.planType = p
                            editedSettings.resetScheduleForNewPlanType()
                        }
                    )
                }
            }
            .background(Color(hex: "1A1A1A"))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Goal Time

    private var goalTimeSection: some View {
        VStack(spacing: 0) {
            EditLabel("GOAL TIME")
            ZStack {
                Color(hex: "1A1A1A")
                HStack(spacing: 0) {
                    Picker("", selection: $goalHours) {
                        ForEach(2...6, id: \.self) { h in
                            Text("\(h)h").tag(h)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .colorScheme(.dark)

                    Text(":")
                        .foregroundColor(Color(hex: "5E5E5E"))
                        .font(.system(size: 22, weight: .thin))

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
                    .colorScheme(.dark)
                }
                .frame(height: 100)
            }
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Base Mileage

    private var baseMileageSection: some View {
        VStack(spacing: 0) {
            EditLabel("BASE MILEAGE")
            ZStack {
                Color(hex: "1A1A1A")
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(editedSettings.baseMileage))")
                            .font(.system(size: 36, weight: .thin,
                                          design: .monospaced))
                            .foregroundColor(.white)
                        Text("miles / week")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "5E5E5E"))
                    }
                    Spacer()
                    VStack(spacing: 10) {
                        Button {
                            if editedSettings.baseMileage < 80 {
                                editedSettings.baseMileage += 5
                            }
                        } label: {
                            Image(systemName: "plus")
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Color(hex: "2A2A2A"))
                                .cornerRadius(8)
                        }
                        Button {
                            if editedSettings.baseMileage > 10 {
                                editedSettings.baseMileage -= 5
                            }
                        } label: {
                            Image(systemName: "minus")
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Color(hex: "2A2A2A"))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(16)
            }
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Plan Length

    private var planLengthSection: some View {
        VStack(spacing: 0) {
            EditLabel("PLAN LENGTH")
            HStack(spacing: 10) {
                ForEach(PlanLength.allCases) { length in
                    EditDurationChip(
                        label:      length.label,
                        isSelected: editedSettings.planLength == length,
                        onTap:      { editedSettings.planLength = length }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Long Run Day

    private var longRunDaySection: some View {
        VStack(spacing: 0) {
            EditLabel("WEEKLY SCHEDULE")
            EditScheduleLabel("LONG RUN DAY")
            SingleDayPicker(
                selected: $editedSettings.schedule.longRunDay,
                disabled: []
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
    }

    // MARK: - Primary Workout Day

    private var primaryWorkoutSection: some View {
        Group {
            if editedSettings.planType != .higdon {
                EditScheduleLabel(
                    editedSettings.planType == .higdonIntermediate
                        ? "TEMPO DAY"
                        : "PRIMARY WORKOUT DAY (Q1)"
                )
                SingleDayPicker(
                    selected: $editedSettings.schedule.workoutDay1,
                    disabled: [editedSettings.schedule.longRunDay]
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }
        }
    }

    // MARK: - Secondary Workout Day

    private var secondaryWorkoutSection: some View {
        Group {
            if editedSettings.planType == .hansons
                || editedSettings.planType == .pfitz
                || editedSettings.planType == .jackDaniels {
                EditScheduleLabel("SECONDARY WORKOUT DAY (Q2)")
                SingleDayPicker(
                    selected: $editedSettings.schedule.workoutDay2,
                    disabled: [
                        editedSettings.schedule.longRunDay,
                        editedSettings.schedule.workoutDay1
                    ]
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }
        }
    }

    // MARK: - Midweek Long Run

    private var midweekLongSection: some View {
        Group {
            if editedSettings.planType.usesMidweekLongRun {
                EditScheduleLabel("MIDWEEK LONGER RUN DAY")
                SingleDayPicker(
                    selected: $editedSettings.schedule.midweekLongDay,
                    disabled: midweekDisabled()
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }
        }
    }

    // MARK: - Cross Train

    private var crossTrainSection: some View {
        Group {
            if editedSettings.planType.usesCrossTraining {
                EditScheduleLabel("CROSS-TRAINING DAY (OPTIONAL)")
                EditCrossTrainToggle(
                    schedule: $editedSettings.schedule,
                    taken:    allAssigned()
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }
        }
    }

    // MARK: - Rest Days

    private var restDaysSection: some View {
        VStack(spacing: 0) {
            EditScheduleLabel(restLabel)
            MultiDayPicker(
                selected: $editedSettings.schedule.restDays,
                disabled: daysBlockedFromRest()
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 6)

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "3A3A3A"))
                Text("Days with assigned runs cannot be rest days.")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "3A3A3A"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Conflict Warnings

    private var conflictWarningsView: some View {
        let issues = liveConflicts()
        return Group {
            if !issues.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 12))
                        Text("CONFLICTS")
                            .font(.system(size: 10, weight: .semibold,
                                          design: .monospaced))
                            .foregroundColor(.orange)
                            .kerning(2)
                    }
                    ForEach(issues, id: \.self) { msg in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .foregroundColor(Color(hex: "5E5E5E"))
                            Text(msg)
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "9A9A9A"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Text("Auto-resolved when saved.")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "4A4A4A"))
                }
                .padding(14)
                .background(Color(hex: "1A1A1A"))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PREVIEW CHANGES")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "3E3E3E"))
                .kerning(3)
                .padding(.leading, 20)
                .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 8) {
                let notes = buildChangeNotes()
                if notes.isEmpty {
                    Text("No changes made yet.")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "4A4A4A"))
                } else {
                    ForEach(notes, id: \.self) { note in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "5E5E5E"))
                                .padding(.top, 2)
                            Text(note)
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "9A9A9A"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(hex: "1A1A1A"))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Save Section

    private var saveSection: some View {
        VStack(spacing: 12) {
            Button {
                showPreview.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: showPreview ? "eye.slash" : "eye")
                        .font(.system(size: 13))
                    Text(showPreview ? "HIDE PREVIEW" : "PREVIEW CHANGES")
                        .font(.system(size: 12, weight: .semibold,
                                      design: .monospaced))
                        .kerning(1)
                }
                .foregroundColor(Color(hex: "9A9A9A"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(hex: "1A1A1A"))
                .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .disabled(!hasAnyChange)

            Button(action: saveChanges) {
                HStack(spacing: 10) {
                    if isSaving {
                        ProgressView()
                            .tint(.black)
                            .scaleEffect(0.8)
                        Text("SAVING...")
                            .font(.system(size: 13, weight: .semibold,
                                          design: .monospaced))
                            .kerning(1)
                    } else {
                        Image(systemName: requiresFullRegen
                              ? "arrow.triangle.2.circlepath"
                              : "checkmark")
                            .font(.system(size: 14, weight: .medium))
                        Text(requiresFullRegen
                             ? "REGENERATE PLAN"
                             : "SAVE CHANGES")
                            .font(.system(size: 13, weight: .semibold,
                                          design: .monospaced))
                            .kerning(1)
                    }
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(hasAnyChange ? Color.white : Color(hex: "2A2A2A"))
                .cornerRadius(14)
            }
            .disabled(!hasAnyChange || isSaving)
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Save Logic

    private func saveChanges() {
        syncGoalTime()
        isSaving = true

        let captured = editedSettings
        let original = plan

        DispatchQueue.global(qos: .userInitiated).async {
            let updatedPlan: SavedPlan

            if original.settings.onlyScheduleDiffers(from: captured) {
                updatedPlan = store.reflowSchedule(
                    original,
                    newSchedule: captured.schedule
                )
            } else {
                updatedPlan = store.regeneratePlan(
                    original,
                    newSettings: captured
                )
            }

            DispatchQueue.main.async {
                store.savePlan(updatedPlan)
                isSaving = false
                dismiss()
            }
        }
    }

    // MARK: - Change Notes

    private func buildChangeNotes() -> [String] {
        var notes: [String] = []
        let old = plan.settings
        let new = editedSettings

        if old.planType != new.planType {
            notes.append("Plan type: \(old.planType.rawValue) → \(new.planType.rawValue) (full regeneration)")
        }
        if old.goalTimeMinutes != new.goalTimeMinutes {
            notes.append("Goal time: \(old.goalTimeFormatted) → \(new.goalTimeFormatted)")
        }
        if old.baseMileage != new.baseMileage {
            notes.append("Base mileage: \(Int(old.baseMileage)) → \(Int(new.baseMileage)) mpw")
        }
        if old.planLength != new.planLength {
            notes.append("Plan length: \(old.planLength.rawValue) → \(new.planLength.rawValue) weeks")
        }
        if old.schedule.longRunDay != new.schedule.longRunDay {
            notes.append("Long run: \(old.schedule.longRunDay.fullName) → \(new.schedule.longRunDay.fullName)")
        }
        if old.schedule.workoutDay1 != new.schedule.workoutDay1 {
            notes.append("Workout Day 1: \(old.schedule.workoutDay1.fullName) → \(new.schedule.workoutDay1.fullName)")
        }
        if old.schedule.workoutDay2 != new.schedule.workoutDay2 {
            notes.append("Workout Day 2: \(old.schedule.workoutDay2.fullName) → \(new.schedule.workoutDay2.fullName)")
        }
        let oldRest = old.schedule.restDays.map { $0.name }.sorted().joined(separator: ", ")
        let newRest = new.schedule.restDays.map { $0.name }.sorted().joined(separator: ", ")
        if oldRest != newRest {
            let oldStr = oldRest.isEmpty ? "None" : oldRest
            let newStr = newRest.isEmpty ? "None" : newRest
            notes.append("Rest days: \(oldStr) → \(newStr)")
        }
        return notes
    }

    // MARK: - Schedule Helpers

    private var restLabel: String {
        switch editedSettings.planType {
        case .hansons:            return "REST DAY (1 ONLY)"
        case .pfitz:              return "REST DAY (1 MAXIMUM)"
        case .higdon:             return "REST DAYS (SELECT 2)"
        case .higdonIntermediate: return "REST DAY (1 MINIMUM)"
        case .jackDaniels:        return "REST DAYS (1–2)"
        }
    }

    private func daysBlockedFromRest() -> [Weekday] {
        let s = editedSettings.schedule
        let p = editedSettings.planType
        var hard = Set<Weekday>()
        hard.insert(s.longRunDay)
        if p != .higdon             { hard.insert(s.workoutDay1) }
        if p.requiresTwoWorkoutDays { hard.insert(s.workoutDay2) }
        if p.usesMidweekLongRun     { hard.insert(s.midweekLongDay) }
        if p.usesCrossTraining, let ct = s.crossTrainDay { hard.insert(ct) }

        let minRun  = minimumRunDays(for: p)
        let maxRest = 7 - minRun
        let curRest = s.restDays.filter { !hard.contains($0) }.count
        var blocked = Array(hard)
        if curRest >= maxRest {
            blocked += Weekday.allCases.filter {
                !hard.contains($0) && !s.restDays.contains($0)
            }
        }
        return blocked
    }

    private func minimumRunDays(for plan: PlanType) -> Int {
        switch plan {
        case .hansons: return 6
        case .pfitz:   return 5
        default:       return 4
        }
    }

    private func midweekDisabled() -> [Weekday] {
        let s = editedSettings.schedule
        var d = [s.longRunDay] + s.restDays
        if editedSettings.planType != .higdon {
            d.append(s.workoutDay1)
        }
        if editedSettings.planType.requiresTwoWorkoutDays {
            d.append(s.workoutDay2)
        }
        return d
    }

    private func allAssigned() -> [Weekday] {
        let s = editedSettings.schedule
        var t = [s.longRunDay, s.workoutDay1, s.workoutDay2, s.midweekLongDay]
        t += s.restDays
        if let ct = s.crossTrainDay { t.append(ct) }
        return t
    }

    private func liveConflicts() -> [String] {
        var issues: [String] = []
        let s = editedSettings.schedule
        let p = editedSettings.planType

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
            issues.append("Workout Day 1 and Day 2 are the same (\(s.workoutDay1.fullName)).")
        }
        if p.usesMidweekLongRun && s.midweekLongDay == s.longRunDay {
            issues.append("Midweek run and long run are on the same day (\(s.longRunDay.fullName)).")
        }
        return issues
    }

    private func syncGoalTime() {
        editedSettings.goalTimeMinutes = goalHours * 60 + goalMinutes
    }
}

// MARK: - Sub-components

struct EditLabel: View {
    let t: String
    init(_ t: String) { self.t = t }
    var body: some View {
        Text(t)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(Color(hex: "3E3E3E"))
            .kerning(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 20)
            .padding(.bottom, 8)
    }
}

struct EditScheduleLabel: View {
    let t: String
    init(_ t: String) { self.t = t }
    var body: some View {
        Text(t)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(Color(hex: "4A4A4A"))
            .kerning(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 20)
            .padding(.bottom, 8)
    }
}

struct EditPlanTypeRow: View {
    let plan       : PlanType
    let isSelected : Bool
    let onTap      : () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Circle()
                    .stroke(isSelected ? Color.white : Color(hex: "3A3A3A"),
                            lineWidth: 1.5)
                    .background(Circle().fill(isSelected ? Color.white : Color.clear))
                    .frame(width: 16, height: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.rawValue)
                        .font(.system(size: 14,
                                      weight: isSelected ? .medium : .regular))
                        .foregroundColor(isSelected ? .white : Color(hex: "9A9A9A"))
                    Text(plan.description)
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "4A4A4A"))
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color(hex: "222222") : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

struct EditDurationChip: View {
    let label      : String
    let isSelected : Bool
    let onTap      : () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 12,
                              weight: isSelected ? .semibold : .regular,
                              design: .monospaced))
                .foregroundColor(isSelected ? .black : Color(hex: "5E5E5E"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.white : Color(hex: "1A1A1A"))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct EditCrossTrainToggle: View {
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
                                schedule.crossTrainDay =
                                    Weekday.allCases.first { !t.contains($0) }
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
                                        isDis ? Color(hex: "2A2A2A") :
                                        isSel ? Color(hex: "0F0F0F") :
                                                Color(hex: "5E5E5E"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
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
