import SwiftUI

// MARK: - Navigation IDs

struct PlanNavID: Hashable { let id: UUID }
struct WeekNavID: Hashable { let id: UUID }

// MARK: - Plan Sort Order

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

    @State private var navPath         = NavigationPath()
    @State private var newPlanID       : UUID? = nil
    @State private var showingCreate   = false
    @State private var isEditing       = false
    @State private var selectedIDs     : Set<UUID> = []
    @State private var showDeleteAlert = false

    @AppStorage("planSortOrder")
    private var sortOrder: PlanSortOrder = .earliestPlan

    // Sort by startDate so "earliest" means the plan whose block began first.
    var sortedOtherPlans: [SavedPlan] {
        let others = store.plans.filter { !store.isPrimary($0) }
        switch sortOrder {
        case .name:
            return others.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .earliestPlan:
            return others.sorted { $0.startDate < $1.startDate }
        case .latestPlan:
            return others.sorted { $0.startDate > $1.startDate }
        }
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                if store.plans.isEmpty {
                    emptyState
                } else {
                    planList
                }
            }
            .navigationTitle(isEditing ? selectionTitle : "My Plans")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .bottom) {
                if isEditing { deleteBar }
            }
            .alert("Delete Plans", isPresented: $showDeleteAlert) {
                Button(
                    "Delete \(selectedIDs.count) Plan\(selectedIDs.count == 1 ? "" : "s")",
                    role: .destructive
                ) { deleteSelected() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(selectedIDs.count == 1
                     ? "This will permanently delete the selected plan. This action cannot be undone."
                     : "This will permanently delete \(selectedIDs.count) plans. This action cannot be undone.")
            }
            .sheet(isPresented: $showingCreate, onDismiss: {
                if let id = newPlanID {
                    navPath.append(PlanNavID(id: id))
                    newPlanID = nil
                }
            }) {
                CreatePlanView(onPlanCreated: { id in newPlanID = id })
                    .environmentObject(store)
            }
            .navigationDestination(for: PlanNavID.self) { nav in
                if let plan = store.plans.first(where: { $0.id == nav.id }) {
                    SavedPlanView(plan: plan).environmentObject(store)
                }
            }
            .navigationDestination(for: WeekNavID.self) { nav in
                let matchingPlan = store.plans.first { $0.weeks.contains { $0.id == nav.id } }
                let matchingWeek = matchingPlan?.weeks.first { $0.id == nav.id }
                if let p = matchingPlan, let w = matchingWeek {
                    SPVWeekDetailView(planID: p.id, week: w).environmentObject(store)
                }
            }
            .onChange(of: isEditing) { editing in
                if !editing { selectedIDs.removeAll() }
            }
        }
        .onAppear {
            if let id = store.pendingOpenPlanID {
                navPath.append(PlanNavID(id: id))
                store.pendingOpenPlanID = nil
            }
        }
    }

    // MARK: - Helpers

    private var selectionTitle: String {
        selectedIDs.isEmpty ? "Select Plans" : "\(selectedIDs.count) Selected"
    }

    private func toggleSelection(_ id: UUID) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
            if selectedIDs.contains(id) { selectedIDs.remove(id) }
            else                        { selectedIDs.insert(id) }
        }
    }

    private func deleteSelected() {
        let toDelete = store.plans.filter { selectedIDs.contains($0.id) }
        withAnimation(.easeInOut(duration: 0.25)) {
            toDelete.forEach { store.deletePlan($0) }
            selectedIDs.removeAll()
            if store.plans.isEmpty { isEditing = false }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isEditing {
            ToolbarItem(placement: .navigationBarLeading) {
                let allSelected = selectedIDs.count == store.plans.count
                Button(allSelected ? "Deselect All" : "Select All") {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        if allSelected { selectedIDs.removeAll() }
                        else           { selectedIDs = Set(store.plans.map { $0.id }) }
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    withAnimation(.easeInOut(duration: 0.2)) { isEditing = false }
                }
                .fontWeight(.semibold)
            }
        } else {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingCreate = true } label: {
                    Image(systemName: "plus").fontWeight(.medium)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    // Sort options
                    Section("Sort") {
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
                    }
                    // Edit
                    if store.plans.count > 0 {
                        Section {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isEditing = true
                                }
                            } label: {
                                Label("Select Plans", systemImage: "checkmark.circle")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").fontWeight(.medium)
                }
            }
        }
    }

    // MARK: - Delete Bar

    private var deleteBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button(role: .destructive) {
                guard !selectedIDs.isEmpty else { return }
                showDeleteAlert = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                    Text(selectedIDs.isEmpty
                         ? "Select plans to delete"
                         : "Delete \(selectedIDs.count) Plan\(selectedIDs.count == 1 ? "" : "s")")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(selectedIDs.isEmpty ? .secondary : .red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .disabled(selectedIDs.isEmpty)
            .background(.regularMaterial)
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
            Button { showingCreate = true } label: {
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

                // ── Active Plan ───────────────────────────────────
                if let primary = store.primaryPlan {
                    VStack(alignment: .leading, spacing: 10) {
                        listSectionHeader("ACTIVE")
                        planRow(for: primary, isPrimary: true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }

                // ── Other Plans ───────────────────────────────────
                if !sortedOtherPlans.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            listSectionHeader("OTHER PLANS")
                            Spacer()
                            if !isEditing {
                                Text(sortOrder.rawValue)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        VStack(spacing: 1) {
                            ForEach(Array(sortedOtherPlans.enumerated()),
                                    id: \.element.id) { index, plan in
                                otherPlanRow(
                                    plan:   plan,
                                    index:  index,
                                    isLast: index == sortedOtherPlans.count - 1
                                )
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

    // Builds either a tappable-for-navigation row or a tappable-for-selection row.
    @ViewBuilder
    private func planRow(for plan: SavedPlan, isPrimary: Bool) -> some View {
        let selected = selectedIDs.contains(plan.id)
        if isEditing {
            Button { toggleSelection(plan.id) } label: {
                ActivePlanCard(plan: plan, isEditing: true, isSelected: selected)
                    .environmentObject(store)
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: PlanNavID(id: plan.id)) {
                ActivePlanCard(plan: plan, isEditing: false, isSelected: false)
                    .environmentObject(store)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func otherPlanRow(for plan: SavedPlan, index: Int, isLast: Bool) -> some View {
        // Renamed to avoid conflict with the two-arg version above
        otherPlanRow(plan: plan, index: index, isLast: isLast)
    }

    @ViewBuilder
    private func otherPlanRow(plan: SavedPlan, index: Int, isLast: Bool) -> some View {
        let selected = selectedIDs.contains(plan.id)
        if isEditing {
            Button { toggleSelection(plan.id) } label: {
                OtherPlanRow(
                    plan:       plan,
                    index:      index,
                    isLast:     isLast,
                    isEditing:  true,
                    isSelected: selected
                )
                .environmentObject(store)
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: PlanNavID(id: plan.id)) {
                OtherPlanRow(
                    plan:       plan,
                    index:      index,
                    isLast:     isLast,
                    isEditing:  false,
                    isSelected: false
                )
                .environmentObject(store)
            }
            .buttonStyle(.plain)
        }
    }

    private func listSectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(.secondary)
            .kerning(1.5)
    }
}

// MARK: - Selection Indicator

struct SelectionCircle: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.accentColor : Color.clear)
                .frame(width: 26, height: 26)
            Circle()
                .stroke(
                    isSelected ? Color.accentColor : Color(.tertiaryLabel),
                    lineWidth: 1.5
                )
                .frame(width: 26, height: 26)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Active Plan Card

struct ActivePlanCard: View {
    let plan       : SavedPlan
    let isEditing  : Bool
    let isSelected : Bool
    @EnvironmentObject var store: PlanStore

    private var daysUntilRace: Int {
        max(0, Calendar.current.dateComponents(
            [.day], from: Date(), to: plan.raceDate).day ?? 0)
    }

    private var raceDateString: String {
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: plan.raceDate)
    }

    private var progressFraction: Double {
        let total = plan.weeks.flatMap { $0.days }.filter { $0.isTrackable }
        let done  = total.filter {
            $0.completionStatus == .completed || $0.completionStatus == .modified
        }
        guard !total.isEmpty else { return 0 }
        return Double(done.count) / Double(total.count)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
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
                    if !isEditing {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(.quaternaryLabel))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? Color.accentColor : Color.clear,
                        lineWidth: 2
                    )
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isSelected)

            // Selection indicator overlay (top-leading)
            if isEditing {
                SelectionCircle(isSelected: isSelected)
                    .padding(10)
            }
        }
        .contextMenu {
            if !isEditing {
                Button(role: .destructive) {
                    store.deletePlan(plan)
                } label: {
                    Label("Delete Plan", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Other Plan Row

struct OtherPlanRow: View {
    let plan       : SavedPlan
    let index      : Int
    let isLast     : Bool
    let isEditing  : Bool
    let isSelected : Bool
    @EnvironmentObject var store: PlanStore

    private var daysUntilRace: Int {
        max(0, Calendar.current.dateComponents(
            [.day], from: Date(), to: plan.raceDate).day ?? 0)
    }

    private var raceMonthYear: String {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f.string(from: plan.raceDate)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {

                // Left: selection circle or index number
                if isEditing {
                    SelectionCircle(isSelected: isSelected)
                        .frame(width: 36, height: 36)
                } else {
                    ZStack {
                        Circle()
                            .fill(Color(.tertiarySystemGroupedBackground))
                            .frame(width: 36, height: 36)
                        Text("\(index + 1)")
                            .font(.metricCaption(13))
                            .foregroundColor(.secondary)
                    }
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

                // Days + chevron (hidden while editing)
                if !isEditing {
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
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.08)
                    : Color(.secondarySystemGroupedBackground)
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isSelected)

            if !isLast {
                Divider().padding(.leading, 64)
            }
        }
        .contextMenu {
            if !isEditing {
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
}
