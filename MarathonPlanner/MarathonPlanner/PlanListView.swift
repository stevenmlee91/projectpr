import SwiftUI

struct PlanNavID: Hashable { let id: UUID }
struct WeekNavID: Hashable { let id: UUID }

struct PlanListView: View {
    @EnvironmentObject var store: PlanStore
    @State private var showingCreate = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
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
                    }
                }
            }
            .sheet(isPresented: $showingCreate) {
                CreatePlanView().environmentObject(store)
            }
            .navigationDestination(for: PlanNavID.self) { nav in
                if let plan = store.plans.first(where: { $0.id == nav.id }) {
                    SavedPlanView(plan: plan)
                        .environmentObject(store)
                }
            }
            .navigationDestination(for: WeekNavID.self) { nav in
                let matchingPlan = store.plans.first { p in
                    p.weeks.contains { $0.id == nav.id }
                }
                let matchingWeek = matchingPlan?.weeks.first { $0.id == nav.id }
                if let p = matchingPlan, let w = matchingWeek {
                    SPVWeekDetailView(planID: p.id, week: w)
                        .environmentObject(store)
                }
            }
        }
    }

    // MARK: - Empty State

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run")
                .font(.system(size: 52, weight: .ultraLight))
                .foregroundColor(Color(.tertiaryLabel))
            Text("No plans yet")
                .font(.system(size: 18, weight: .light))
                .foregroundColor(.secondary)
            Button(action: { showingCreate = true }) {
                Text("CREATE YOUR FIRST PLAN")
                    .font(.system(size: 12, weight: .semibold,
                                  design: .monospaced))
                    .kerning(2)
                    .foregroundColor(Color(.systemBackground))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color(.label))
                    .cornerRadius(10)
            }
        }
    }

    // MARK: - Plan List

    var planList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: Primary Plan Section
                if let primary = store.primaryPlan {
                    sectionHeader("ACTIVE PLAN")

                    NavigationLink(value: PlanNavID(id: primary.id)) {
                        PlanRowView(plan: primary, isPrimary: true)
                            .environmentObject(store)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }

                // MARK: Other Plans Section
                if !store.otherPlans.isEmpty {
                    sectionHeader("OTHER PLANS")

                    VStack(spacing: 10) {
                        ForEach(store.otherPlans) { plan in
                            NavigationLink(value: PlanNavID(id: plan.id)) {
                                PlanRowView(plan: plan, isPrimary: false)
                                    .environmentObject(store)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Spacer().frame(height: 32)
            }
            .padding(.top, 8)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(.secondary)
            .kerning(3)
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
    }
}

// MARK: - Plan Row

struct PlanRowView: View {
    let plan      : SavedPlan
    let isPrimary : Bool
    @EnvironmentObject var store: PlanStore

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; return f
    }()

    var daysUntilRace: Int {
        let comps = Calendar.current.dateComponents(
            [.day], from: Date(), to: plan.raceDate)
        return max(0, comps.day ?? 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Active plan banner
            if isPrimary {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("ACTIVE PLAN")
                        .font(.system(size: 10, weight: .semibold,
                                      design: .monospaced))
                        .kerning(2)
                    Spacer()
                    Text("Training now")
                        .font(.system(size: 10, design: .monospaced))
                        .opacity(0.7)
                }
                .foregroundColor(Color(.systemBackground))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(.label))
            }

            // Main row content
            HStack(spacing: 16) {
                // Accent bar — thicker for primary
                RoundedRectangle(cornerRadius: 2)
                    .fill(isPrimary ? Color(.label) : Color(.tertiaryLabel))
                    .frame(width: isPrimary ? 4 : 3, height: 50)

                VStack(alignment: .leading, spacing: 6) {
                    Text(plan.name)
                        .font(.system(size: 16,
                                      weight: isPrimary ? .semibold : .medium))
                        .foregroundColor(.primary)

                    HStack(spacing: 12) {
                        Label(plan.planType, systemImage: "doc.text")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                        Label(dateFormatter.string(from: plan.raceDate),
                              systemImage: "flag.checkered")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(daysUntilRace)")
                        .font(.system(size: 22, weight: .thin,
                                      design: .monospaced))
                        .foregroundColor(.primary)
                    Text("days")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isPrimary
                        ? Color(.label).opacity(0.2)
                        : Color.clear,
                        lineWidth: 1)
        )
        // Context menu — set primary, edit, delete
        .contextMenu {
            if !isPrimary {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.setPrimary(plan)
                    }
                } label: {
                    Label("Set as Active Plan", systemImage: "bolt.fill")
                }
            }

            Button(role: .destructive) {
                store.deletePlan(plan)
            } label: {
                Label("Delete Plan", systemImage: "trash")
            }
        }
    }
}
