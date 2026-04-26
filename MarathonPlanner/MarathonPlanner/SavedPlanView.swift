import SwiftUI

// MARK: - Saved Plan View

struct SavedPlanView: View {
    let plan             : SavedPlan
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

    var body: some View {
        ZStack {
            Color(hex: "0F0F0F").ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    planHeader
                    exportButtons
                    weeksList
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .colorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingEdit = true } label: {
                    Image(systemName: "pencil").foregroundColor(.white)
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

    private var planHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(livePlan.planType.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "5E5E5E"))
                .kerning(3)

            Text(livePlan.name)
                .font(.system(size: 28, weight: .light, design: .serif))
                .foregroundColor(.white)

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
                        .foregroundColor(.white)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }

    private var exportButtons: some View {
        HStack(spacing: 10) {
            SPVExportButton(label: "PDF",
                            icon: "doc.richtext",
                            action: exportPDF)
            SPVExportButton(label: "CALENDAR",
                            icon: "calendar.badge.plus",
                            action: exportCalendar)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    private var weeksList: some View {
        VStack(spacing: 8) {
            ForEach(livePlan.weeks) { week in
                NavigationLink(destination: SPVWeekDetailView(week: week)) {
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
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .kerning(1)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(hex: "1A1A1A"))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: "2A2A2A"), lineWidth: 1))
            .cornerRadius(10)
        }
    }
}

// MARK: - Week Row

struct SPVWeekRow: View {
    let week: SavedWeek

    private var isRaceWeek: Bool {
        week.phase.contains("Race Week")
    }

    private let shortDate: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()

    var weekStart: Date? { sortedDays(week.days).first?.date }
    var weekEnd:   Date? { sortedDays(week.days).last?.date  }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Week label + optional race badge
                HStack(spacing: 8) {
                    Text("Week \(week.weekNumber)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

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
                    .foregroundColor(Color(hex: "5E5E5E"))
                    .font(.system(size: 13))
            }

            HStack {
                Text(week.phase)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(isRaceWeek
                                     ? Color.yellow.opacity(0.7)
                                     : Color(hex: "4A4A4A"))
                Spacer()
                if let s = weekStart, let e = weekEnd {
                    Text("\(shortDate.string(from: s)) – \(shortDate.string(from: e))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(hex: "4A4A4A"))
                }
            }

            // Day dots — Monday-first order
            HStack(spacing: 5) {
                ForEach(sortedDays(week.days)) { day in
                    Circle()
                        .fill(dotColor(for: day.workoutType))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(16)
        .background(isRaceWeek
                     ? Color(hex: "2A2500")   // warm tint for race week
                     : Color(hex: "1A1A1A"))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isRaceWeek ? Color.yellow.opacity(0.4) : Color.clear,
                        lineWidth: 1)
        )
        .cornerRadius(12)
    }

    // Sort days Monday-first for display
    func sortedDays(_ days: [SavedDay]) -> [SavedDay] {
        let order = ["Monday","Tuesday","Wednesday",
                     "Thursday","Friday","Saturday","Sunday"]
        return days.sorted { a, b in
            let i0 = order.firstIndex(of: a.weekday) ?? 7
            let i1 = order.firstIndex(of: b.weekday) ?? 7
            return i0 < i1
        }
    }

    func dotColor(for type: String) -> Color {
        switch type {
        case "Rest":                                    return Color(hex: "2A2A2A")
        case "Recovery Run":                            return Color(hex: "34C759")
        case "Easy Run", "Easy + Strides":             return Color(hex: "30D158")
        case "Long Run", "Long Run w/ MP Finish",
             "Medium-Long Run", "Midweek Longer Run":  return Color(hex: "0A84FF")
        case "Tempo Run", "Strength (MP)",
             "Marathon Pace":                           return Color(hex: "FF9F0A")
        case "Lactate Threshold", "Cruise Intervals",
             "Speed Work", "Interval Work",
             "Repetition Work":                        return Color(hex: "FF453A")
        case "Cross-Training":                         return Color(hex: "BF5AF2")
        case "Shakeout Run":    return Color(hex: "30D158")
        case "Race Day 🏁":                            return Color.yellow
        default:                                       return Color(hex: "3A3A3A")
        }
    }
}

// MARK: - Week Detail View

struct SPVWeekDetailView: View {
    let week: SavedWeek

    private var isRaceWeek: Bool { week.phase.contains("Race Week") }

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"; return f
    }()

    var body: some View {
        ZStack {
            Color(hex: "0F0F0F").ignoresSafeArea()
            ScrollView {
                VStack(spacing: 8) {
                    // Week summary card
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(week.phase)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(isRaceWeek
                                                     ? .yellow
                                                     : Color(hex: "5E5E5E"))
                                if isRaceWeek {
                                    Image(systemName: "flag.checkered")
                                        .foregroundColor(.yellow)
                                        .font(.system(size: 12))
                                }
                            }
                            Text(String(format: "%.1f mi total", week.totalMiles))
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "3E3E3E"))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                    // Days — Monday-first
                    ForEach(sortedDays(week.days)) { day in
                        if day.workoutType == "Race Day 🏁" {
                            SPVRaceDayRow(day: day, dateFormatter: dateFormatter)
                        } else {
                            SPVDayRow(day: day, dateFormatter: dateFormatter)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Week \(week.weekNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .colorScheme(.dark)
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

// MARK: - Race Day Row (premium highlight)

struct SPVRaceDayRow: View {
    let day           : SavedDay
    let dateFormatter : DateFormatter

    var body: some View {
        VStack(spacing: 0) {
            // Gold header bar
            HStack(spacing: 10) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                Text("RACE DAY")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
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

            // Body
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("26.2 miles")
                        .font(.system(size: 22, weight: .thin,
                                      design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    Text("🏅 42.2 km")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "5E5E5E"))
                }

                Text(day.description)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "9A9A9A"))
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
            .background(Color(hex: "1A1200"))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.6), lineWidth: 1.5)
        )
        .cornerRadius(12)
    }
}

// MARK: - Regular Day Row

struct SPVDayRow: View {
    let day           : SavedDay
    let dateFormatter : DateFormatter

    var dotColor: Color {
        switch day.workoutType {
        case "Rest":                                    return .gray
        case "Recovery Run":                            return Color(hex: "34C759")
        case "Easy Run", "Easy + Strides":             return Color(hex: "30D158")
        case "Long Run", "Long Run w/ MP Finish",
             "Medium-Long Run", "Midweek Longer Run":  return Color(hex: "0A84FF")
        case "Tempo Run", "Strength (MP)",
             "Marathon Pace":                           return Color(hex: "FF9F0A")
        case "Lactate Threshold", "Cruise Intervals",
             "Speed Work", "Interval Work",
             "Repetition Work":                        return Color(hex: "FF453A")
        case "Cross-Training":                         return Color(hex: "BF5AF2")
        case "Shakeout Run":    return Color(hex: "30D158")
        default:                                       return Color(hex: "3A3A3A")
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(dateFormatter.string(from: day.date))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    if day.miles > 0 {
                        Text(String(format: "%.1f mi", day.miles))
                            .foregroundColor(Color(hex: "5E5E5E"))
                            .font(.system(size: 13))
                    }
                }

                Text(day.workoutType)
                    .font(.system(size: 12))
                    .foregroundColor(dotColor)

                Text(day.description)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "5E5E5E"))
                    .fixedSize(horizontal: false, vertical: true)

                if day.paceNote != "—" && !day.paceNote.isEmpty {
                    Text("Target: \(day.paceNote)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "0A84FF"))
                }
            }
        }
        .padding(14)
        .background(Color(hex: "1A1A1A"))
        .cornerRadius(12)
    }
}

// MARK: - Share Sheet

struct SPVShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
