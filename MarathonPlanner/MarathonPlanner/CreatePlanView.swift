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
        let weeks = settings.planLength.rawValue
        return Calendar.current.date(byAdding: .weekOfYear, value: -weeks, to: raceDate) ?? raceDate
    }

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0F0F0F").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {

                        // ── Group 1 ──────────────────────────────────
                        Group {
                            // Header
                            VStack(alignment: .leading, spacing: 4) {
                                Text("NEW PLAN")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundColor(Color(hex: "5E5E5E"))
                                    .kerning(3)
                                Text("Create Training Plan")
                                    .font(.system(size: 28, weight: .light, design: .serif))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                            .padding(.bottom, 28)

                            // Plan Name
                            CreateSectionHeader("PLAN NAME")
                            ZStack {
                                Color(hex: "1A1A1A")
                                TextField("e.g. Sydney Marathon 2026", text: $planName)
                                    .foregroundColor(.white)
                                    .padding(16)
                                    .colorScheme(.dark)
                            }
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)

                            // Race Date
                            CreateSectionHeader("RACE DATE")
                            ZStack {
                                Color(hex: "1A1A1A")
                                VStack(spacing: 0) {
                                    DatePicker(
                                        "Race Date",
                                        selection: $raceDate,
                                        displayedComponents: .date
                                    )
                                    .datePickerStyle(.compact)
                                    .colorScheme(.dark)
                                    .foregroundColor(.white)
                                    .padding(16)

                                    Divider().background(Color(hex: "2A2A2A"))

                                    HStack {
                                        Text("Plan starts")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(hex: "5E5E5E"))
                                        Spacer()
                                        Text(dateFormatter.string(from: startDate))
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(.white)
                                    }
                                    .padding(16)
                                }
                            }
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)

                            // Plan Type
                            CreateSectionHeader("TRAINING METHOD")
                            VStack(spacing: 1) {
                                ForEach(PlanType.allCases) { plan in
                                    CreatePlanTypeRow(
                                        plan:       plan,
                                        isSelected: settings.planType == plan,
                                        onTap:      { settings.planType = plan }
                                    )
                                }
                            }
                            .background(Color(hex: "1A1A1A"))
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }

                        // ── Group 2 ──────────────────────────────────
                        Group {
                            // Plan Length
                            CreateSectionHeader("DURATION")
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

                            // Goal Time
                            CreateSectionHeader("GOAL TIME")
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
                                    .colorScheme(.dark)
                                }
                                .frame(height: 110)
                            }
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)

                            // Base Mileage
                            CreateSectionHeader("BASE MILEAGE")
                            ZStack {
                                Color(hex: "1A1A1A")
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(Int(settings.baseMileage))")
                                            .font(.system(size: 36, weight: .thin, design: .monospaced))
                                            .foregroundColor(.white)
                                        Text("miles / week currently")
                                            .font(.system(size: 11))
                                            .foregroundColor(Color(hex: "5E5E5E"))
                                    }
                                    Spacer()
                                    VStack(spacing: 10) {
                                        Button(action: {
                                            if settings.baseMileage < 80 {
                                                settings.baseMileage += 5
                                            }
                                        }) {
                                            Image(systemName: "plus")
                                                .foregroundColor(.white)
                                                .frame(width: 38, height: 38)
                                                .background(Color(hex: "2A2A2A"))
                                                .cornerRadius(8)
                                        }
                                        Button(action: {
                                            if settings.baseMileage > 10 {
                                                settings.baseMileage -= 5
                                            }
                                        }) {
                                            Image(systemName: "minus")
                                                .foregroundColor(.white)
                                                .frame(width: 38, height: 38)
                                                .background(Color(hex: "2A2A2A"))
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                                .padding(18)
                            }
                            .cornerRadius(12)
                            .padding(.horizontal, 16)

                            Spacer().frame(height: 110)
                        }
                    }
                }

                // ── Generate Button (pinned bottom) ───────────────
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [Color(hex: "0F0F0F").opacity(0), Color(hex: "0F0F0F")],
                        startPoint: .top,
                        endPoint:   .bottom
                    )
                    .frame(height: 30)

                    Button(action: generatePlan) {
                        HStack(spacing: 10) {
                            Image(systemName: "figure.run")
                                .font(.system(size: 14, weight: .medium))
                            Text(isGenerating ? "GENERATING..." : "GENERATE PLAN")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .kerning(2)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .cornerRadius(14)
                    }
                    .disabled(isGenerating || planName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                    .background(Color(hex: "0F0F0F"))
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        .colorScheme(.dark)
        .onChange(of: goalHours)   { _ in updateGoalTime() }
        .onChange(of: goalMinutes) { _ in updateGoalTime() }
    }

    // MARK: - Helpers

    func updateGoalTime() {
        settings.goalTimeMinutes = goalHours * 60 + goalMinutes
    }

    func generatePlan() {
        updateGoalTime()
        isGenerating = true
        DispatchQueue.global(qos: .userInitiated).async {
            let plan = createSavedPlan(
                name:     planName.trimmingCharacters(in: .whitespaces),
                raceDate: raceDate,
                settings: settings
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

struct CreateSectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(Color(hex: "3E3E3E"))
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
                Circle()
                    .stroke(isSelected ? Color.white : Color(hex: "3A3A3A"), lineWidth: 1.5)
                    .background(Circle().fill(isSelected ? Color.white : Color.clear))
                    .frame(width: 16, height: 16)

                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.rawValue)
                        .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                        .foregroundColor(isSelected ? .white : Color(hex: "9A9A9A"))
                    Text(plan.description)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "4A4A4A"))
                        .lineLimit(2)
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

struct CreateDurationChip: View {
    let label      : String
    let isSelected : Bool
    let onTap      : () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular, design: .monospaced))
                .foregroundColor(isSelected ? .black : Color(hex: "5E5E5E"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.white : Color(hex: "1A1A1A"))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
