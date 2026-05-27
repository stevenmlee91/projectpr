import SwiftUI

// MARK: - Navigation IDs

struct PlanNavID: Hashable { let id: UUID }
struct WeekNavID: Hashable { let id: UUID }

// MARK: - Plan Sort Order
// Delete this block if you have PlanSortOrder.swift as a separate file.

enum PlanSortOrder: String, CaseIterable, Identifiable {
    case name         = "Name"
    case earliestPlan = "Earliest First"
    case latestPlan   = "Latest First"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .name:         return "textformat.abc"
        case .earliestPlan: return "arrow.up.calendar"
        case .latestPlan:   return "arrow.down.calendar"
        }
    }
}

// MARK: - Plan List View

struct PlanListView: View {
    @EnvironmentObject var store: PlanStore
    @State private var showingCreate = false
    @AppStorage("planSortOrder") private var sortOrder: PlanSortOrder = .earliestPlan

    var sortedOtherPlans: [SavedPlan] {
        let others = store.plans.filter { !store.isPrimary($0) }
        switch sortOrder {
        case .name:
            return others.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .earliestPlan:
            return others.sorted { $0.raceDate < $1.raceDate }
        case .latestPlan:
            return others.sorted { $0.raceDate > $1.raceDate }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                if store.plans.isEmpty {
                    emptyState
                } else {
                    planList
                }
            }
            .navigationTitle("My Plans")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreate = true }) {
                        Image(systemName: "plus")
                            .fontWeight(.medium)
                    }
                }
                if store.plans.count > 1 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            ForEach(PlanSortOrder.allCases) { order in
                                Button {
                                    sortOrder = order
                                } label: {
                                    Label(
                                        order.rawValue,
                                        systemImage: sortOrder == order
                                            ? "checkmark"
                                            : order.icon
                                    )
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease")
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCreate) {
                CreatePlanView().environmentObject(store)
            }
            .navigationDestination(for: PlanNavID.self) { nav in
                if let plan = store.plans.first(where: { $0.id == nav.id }) {
                    SavedPlanView(plan: plan).environmentObject(store)
                }
            }
            .navigationDestination(for: WeekNavID.self) { nav in
                let matchingPlan = store.plans.first { p in
                    p.weeks.contains { $0.id == nav.id }
                }
                let matchingWeek = matchingPlan?.weeks.first { $0.id == nav.id }
                if let p = matchingPlan, let w = matchingWeek {
                    SPVWeekDetailView(planID: p.id, week: w).environmentObject(store)
                }
            }
        }
    }

    // MARK: - Empty State

    var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(width: 80, height: 80)
                Image(systemName: "figure.run")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(Color(.tertiaryLabel))
            }

            VStack(spacing: 6) {
                Text("No Plans Yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                Text("Create a training plan to get started")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }

            Button(action: { showingCreate = true }) {
                Text("Create Plan")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Plan List

    var planList: some View {
        ScrollView {
            VStack(spacing: 0) {

                // Active Plan
                if let primary = store.primaryPlan {
                    VStack(alignment: .leading, spacing: 10) {
                        listSectionHeader("ACTIVE")
                        NavigationLink(value: PlanNavID(id: primary.id)) {
                            ActivePlanCard(plan: primary)
                                .environmentObject(store)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }

                // Other Plans
                if !sortedOtherPlans.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            listSectionHeader("OTHER PLANS")
                            Spacer()
                            Text(sortOrder.rawValue)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        VStack(spacing: 1) {
                            ForEach(Array(sortedOtherPlans.enumerated()),
                                    id: \.element.id) { index, plan in
                                NavigationLink(value: PlanNavID(id: plan.id)) {
                                    OtherPlanRow(plan: plan, index: index,
                                                 isLast: index == sortedOtherPlans.count - 1)
                                        .environmentObject(store)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 16)
                }

                Spacer().frame(height: 40)
            }
        }
    }

    private func listSectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(.secondary)
            .kerning(1.5)
    }
}

// MARK: - Active Plan Card

struct ActivePlanCard: View {
    let plan: SavedPlan
    @EnvironmentObject var store: PlanStore

    private var daysUntilRace: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(),
                                                to: plan.raceDate).day ?? 0)
    }

    private var raceDateString: String {
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: plan.raceDate)
    }

    private var progressFraction: Double {
        let totalDays = plan.weeks.flatMap { $0.days }.filter { $0.isTrackable }
        let doneDays  = totalDays.filter {
            $0.completionStatus == .completed || $0.completionStatus == .modified
        }
        guard !totalDays.isEmpty else { return 0 }
        return Double(doneDays.count) / Double(totalDays.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Top: name + race date
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: "30D158"))
                        .frame(width: 7, height: 7)
                    Text("ACTIVE")
                        .font(.system(size: 10, weight: .semibold,
                                      design: .monospaced))
                        .foregroundColor(Color(hex: "30D158"))
                        .kerning(1.5)
                }
                Text(plan.name)
                    .font(.displayTitle(22))
                    .foregroundColor(.primary)
                HStack(spacing: 6) {
                    Text(plan.planType)
                        .font(.caption())
                        .foregroundColor(Color(.tertiaryLabel))
                    Text("·")
                        .foregroundColor(Color(.quaternaryLabel))
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(raceDateString)
                        .font(.caption())
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 16)

            Divider().padding(.horizontal, 16)

            // Bottom: countdown + progress
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(daysUntilRace)")
                            .font(.metric(30))
                            .foregroundColor(.primary)
                        Text("days to race")
                            .font(.caption())
                            .foregroundColor(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(.systemFill))
                                .frame(height: 3)
                            Capsule()
                                .fill(Color(hex: "30D158"))
                                .frame(width: geo.size.width * progressFraction,
                                       height: 3)
                        }
                    }
                    .frame(height: 3)
                    .padding(.top, 8)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(.quaternaryLabel))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contextMenu {
            Button(role: .destructive) {
                store.deletePlan(plan)
            } label: {
                Label("Delete Plan", systemImage: "trash")
            }
        }
    }
}

// MARK: - Other Plan Row

struct OtherPlanRow: View {
    let plan   : SavedPlan
    let index  : Int
    let isLast : Bool
    @EnvironmentObject var store: PlanStore

    private var daysUntilRace: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(),
                                                to: plan.raceDate).day ?? 0)
    }

    private var raceMonthYear: String {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f.string(from: plan.raceDate)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Index circle
                ZStack {
                    Circle()
                        .fill(Color(.tertiarySystemGroupedBackground))
                        .frame(width: 36, height: 36)
                    Text("\(index + 1)")
                        .font(.metricCaption(13))
                        .foregroundColor(.secondary)
                }

                // Plan info
                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    Text("\(plan.planType) · \(raceMonthYear)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Days + chevron
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(daysUntilRace)")
                        .font(.metricCaption(15))
                        .foregroundColor(.primary)
                    Text("days")
                        .font(.caption())
                        .foregroundColor(Color(.tertiaryLabel))
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(.quaternaryLabel))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))

            if !isLast {
                Divider()
                    .padding(.leading, 64)
            }
        }
        .contextMenu {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.setPrimary(plan)
                }
            } label: {
                Label("Set as Active Plan", systemImage: "bolt.fill")
            }
            Button(role: .destructive) {
                store.deletePlan(plan)
            } label: {
                Label("Delete Plan", systemImage: "trash")
            }
        }
    }
}
