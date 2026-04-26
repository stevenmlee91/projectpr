import SwiftUI

struct SetupView: View {
    @Binding var settings  : UserSettings
    var onGenerate         : () -> Void

    @State private var goalHours   = 3
    @State private var goalMinutes = 30

    private var scheduleSummary: String {
        let s    = settings.schedule
        let rest = s.restDays.isEmpty
            ? "None"
            : s.restDays.map { $0.name }.joined(separator: ", ")
        return "Long run: \(s.longRunDay.name)  •  Rest: \(rest)"
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Color(.systemBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        Group {
                            // ── Header ───────────────────────────────
                            VStack(alignment: .leading, spacing: 4) {
                                Text("MARATHON")
                                    .font(.system(size: 11, weight: .semibold,
                                                  design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .kerning(3)
                                Text("Training Plan")
                                    .font(.system(size: 32, weight: .light,
                                                  design: .serif))
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.top, 60)
                            .padding(.bottom, 36)

                            // ── Plan Type ────────────────────────────
                            SetupSectionHeader("PLAN TYPE")
                            VStack(spacing: 1) {
                                ForEach(PlanType.allCases) { plan in
                                    SetupPlanTypeRow(
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
                            .padding(.bottom, 28)

                            // ── Plan Length ──────────────────────────
                            SetupSectionHeader("DURATION")
                            HStack(spacing: 10) {
                                ForEach(PlanLength.allCases) { length in
                                    SetupDurationChip(
                                        label:      length.label,
                                        isSelected: settings.planLength == length,
                                        onTap:      { settings.planLength = length }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 28)

                            // ── Goal Time ────────────────────────────
                            SetupSectionHeader("GOAL TIME")
                            ZStack {
                                Color(.secondarySystemBackground)
                                VStack(spacing: 0) {
                                    HStack(spacing: 0) {
                                        Picker("", selection: $goalHours) {
                                            ForEach(2...6, id: \.self) { h in
                                                Text("\(h)").tag(h)
                                            }
                                        }
                                        .pickerStyle(.wheel)
                                        .frame(maxWidth: .infinity)


                                        Text(":")
                                            .font(.system(size: 28, weight: .thin))
                                            .foregroundColor(.secondary)

                                        Picker("", selection: $goalMinutes) {
                                            ForEach(
                                                [0,5,10,15,20,25,30,35,40,45,50,55],
                                                id: \.self
                                            ) { m in
                                                Text(String(format: "%02d", m)).tag(m)
                                            }
                                        }
                                        .pickerStyle(.wheel)
                                        .frame(maxWidth: .infinity)


                                        Text(":00")
                                            .font(.system(size: 20, weight: .thin))
                                            .foregroundColor(.secondary)
                                            .padding(.trailing, 12)
                                    }
                                    .frame(height: 120)

                                    Divider().background(Color(.tertiarySystemBackground))

                                    Text("h   :   mm   :   ss")
                                        .font(.system(size: 10, weight: .medium,
                                                      design: .monospaced))
                                        .foregroundColor(Color(hex: "3E3E3E"))
                                        .kerning(2)
                                        .padding(.vertical, 10)
                                }
                            }
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 28)
                            .onChange(of: goalHours)   { _ in updateGoalTime() }
                            .onChange(of: goalMinutes) { _ in updateGoalTime() }
                        }

                        Group {
                            // ── Base Mileage ─────────────────────────
                            SetupSectionHeader("BASE MILEAGE")
                            ZStack {
                                Color(.secondarySystemBackground)
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(Int(settings.baseMileage))")
                                            .font(.system(size: 40, weight: .thin,
                                                          design: .monospaced))
                                            .foregroundColor(.primary)
                                        Text("miles / week currently")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    VStack(spacing: 12) {
                                        Button {
                                            if settings.baseMileage < 80 {
                                                settings.baseMileage += 5
                                            }
                                        } label: {
                                            Image(systemName: "plus")
                                                .font(.system(size: 16, weight: .light))
                                                .foregroundColor(.primary)
                                                .frame(width: 40, height: 40)
                                                .background(Color(.tertiarySystemBackground))
                                                .cornerRadius(8)
                                        }
                                        Button {
                                            if settings.baseMileage > 10 {
                                                settings.baseMileage -= 5
                                            }
                                        } label: {
                                            Image(systemName: "minus")
                                                .font(.system(size: 16, weight: .light))
                                                .foregroundColor(.primary)
                                                .frame(width: 40, height: 40)
                                                .background(Color(.tertiarySystemBackground))
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                                .padding(20)
                            }
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 28)

                            // ── Weekly Schedule ───────────────────────
                            // NavigationLink passes $settings so that
                            // all edits in ScheduleSetupView write directly
                            // back into the same UserSettings struct.
                            SetupSectionHeader("WEEKLY SCHEDULE")
                            NavigationLink(
                                destination: ScheduleSetupView(settings: $settings)
                            ) {
                                ZStack {
                                    Color(.secondarySystemBackground)
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("Customize Schedule")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.primary)
                                            Text(scheduleSummary)
                                                .font(.system(size: 11,
                                                              design: .monospaced))
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(Color(hex: "3A3A3A"))
                                    }
                                    .padding(16)
                                }
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 28)

                            Spacer().frame(height: 110)
                        }
                    }
                }

                // ── Generate Button ───────────────────────────────
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 32)

                    Button {
                        updateGoalTime()
                        onGenerate()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "figure.run")
                                .font(.system(size: 15, weight: .medium))
                            Text("GENERATE PLAN")
                                .font(.system(size: 13, weight: .semibold,
                                              design: .monospaced))
                                .kerning(2)
                        }
                        .foregroundColor(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .cornerRadius(14)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                    .background(Color(.systemBackground))
                }
            }
            .onAppear { syncPickersToSettings() }
        }

    }

    private func updateGoalTime() {
        settings.goalTimeMinutes = goalHours * 60 + goalMinutes
    }

    private func syncPickersToSettings() {
        goalHours   = settings.goalTimeMinutes / 60
        goalMinutes = settings.goalTimeMinutes % 60
    }
}

// MARK: - SetupView Sub-components
// Prefixed "Setup" to avoid collision with identically-named
// components in other files.

struct SetupSectionHeader: View {
    let title: String
    init(_ t: String) { title = t }
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

struct SetupPlanTypeRow: View {
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
                        .font(.system(size: 15, weight: isSelected ? .medium : .regular))
                        .foregroundColor(isSelected ? .white : Color(hex: "9A9A9A"))
                    Text(plan.description)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "4A4A4A"))
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? Color(hex: "222222") : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

struct SetupDurationChip: View {
    let label      : String
    let isSelected : Bool
    let onTap      : () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 13,
                              weight: isSelected ? .semibold : .regular,
                              design: .monospaced))
                .foregroundColor(isSelected ? Color(.systemBackground) : Color(hex: "5E5E5E"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.white : Color(.secondarySystemBackground))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Color Extension
// Keep only one copy of this across your whole project.
// If another file already has it, delete it from there.

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
