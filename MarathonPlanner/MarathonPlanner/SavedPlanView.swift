import SwiftUI

// MARK: - Saved Plan Detail View

struct SavedPlanView: View {
    let plan: SavedPlan
    @State private var showingExportSheet = false
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    @State private var exportItems: [Any] = []

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        ZStack {
            Color(hex: "0F0F0F").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Plan header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(plan.planType.uppercased())
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(hex: "5E5E5E"))
                            .kerning(3)

                        Text(plan.name)
                            .font(.system(size: 28, weight: .light, design: .serif))
                            .foregroundColor(.white)

                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("STARTS")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(Color(hex: "3E3E3E"))
                                    .kerning(2)
                                Text(dateFormatter.string(from: plan.startDate))
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "9A9A9A"))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("RACE DAY")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(Color(hex: "3E3E3E"))
                                    .kerning(2)
                                Text(dateFormatter.string(from: plan.raceDate))
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 24)

                    // Export buttons
                    HStack(spacing: 10) {
                        ExportButton(
                            label: "PDF",
                            icon: "doc.richtext",
                            action: { exportPDF() }
                        )
                        ExportButton(
                            label: "CALENDAR",
                            icon: "calendar.badge.plus",
                            action: { exportCalendar() }
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)

                    // Weeks list
                    VStack(spacing: 8) {
                        ForEach(plan.weeks) { week in
                            NavigationLink(destination: SavedWeekDetailView(week: week)) {
                                SavedWeekRow(week: week)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .colorScheme(.dark)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: exportItems)
        }
    }

    func exportPDF() {
        let url = PDFExporter.exportPlan(plan)
        exportItems = [url]
        showShareSheet = true
    }

    func exportCalendar() {
        let url = ICSExporter.exportPlan(plan)
        exportItems = [url]
        showShareSheet = true
    }
}

// MARK: - Export Button

struct ExportButton: View {
    let label  : String
    let icon   : String
    let action : () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .kerning(1)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(hex: "1A1A1A"))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(hex: "2A2A2A"), lineWidth: 1)
            )
            .cornerRadius(10)
        }
    }
}

// MARK: - Saved Week Row

struct SavedWeekRow: View {
    let week: SavedWeek

    private let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    var weekStart: Date? { week.days.first?.date }
    var weekEnd:   Date? { week.days.last?.date  }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Week \(week.weekNumber)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text(String(format: "%.0f mi", week.totalMiles))
                    .foregroundColor(Color(hex: "5E5E5E"))
                    .font(.system(size: 13))
            }

            HStack {
                Text(week.phase)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(hex: "4A4A4A"))
                Spacer()
                if let s = weekStart, let e = weekEnd {
                    Text("\(shortDate.string(from: s)) – \(shortDate.string(from: e))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(hex: "4A4A4A"))
                }
            }

            // Day dots
            HStack(spacing: 5) {
                ForEach(week.days) { day in
                    Circle()
                        .fill(dotColor(for: day.workoutType))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(16)
        .background(Color(hex: "1A1A1A"))
        .cornerRadius(12)
    }

    func dotColor(for type: String) -> Color {
        switch type {
        case "Rest":            return Color(hex: "2A2A2A")
        case "Recovery Run":    return Color(hex: "34C759")
        case "Easy Run",
             "Easy + Strides":  return Color(hex: "30D158")
        case "Long Run",
             "Long Run w/ MP Finish",
             "Medium-Long Run": return Color(hex: "0A84FF")
        case "Tempo Run",
             "Strength (MP)",
             "Marathon Pace":   return Color(hex: "FF9F0A")
        case "Lactate Threshold",
             "Cruise Intervals",
             "Speed Work",
             "Interval Work",
             "Repetition Work": return Color(hex: "FF453A")
        default:                return Color(hex: "3A3A3A")
        }
    }
}

// MARK: - Saved Week Detail View

struct SavedWeekDetailView: View {
    let week: SavedWeek

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    var body: some View {
        ZStack {
            Color(hex: "0F0F0F").ignoresSafeArea()
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(week.days) { day in
                        SavedDayRow(day: day, dateFormatter: dateFormatter)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Week \(week.weekNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .colorScheme(.dark)
    }
}

// MARK: - Saved Day Row

struct SavedDayRow: View {
    let day           : SavedDay
    let dateFormatter : DateFormatter

    var dotColor: Color {
        switch day.workoutType {
        case "Rest":             return .gray
        case "Recovery Run":     return Color(hex: "34C759")
        case "Easy Run":         return Color(hex: "30D158")
        case "Long Run",
             "Long Run w/ MP Finish",
             "Medium-Long Run":  return Color(hex: "0A84FF")
        case "Tempo Run",
             "Strength (MP)",
             "Marathon Pace":    return Color(hex: "FF9F0A")
        case "Lactate Threshold",
             "Cruise Intervals",
             "Speed Work",
             "Interval Work",
             "Repetition Work":  return Color(hex: "FF453A")
        default:                 return Color(hex: "3A3A3A")
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

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
