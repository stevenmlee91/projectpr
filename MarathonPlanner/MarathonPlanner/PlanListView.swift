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
                            .foregroundColor(.primary)
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

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run")
                .font(.system(size: 52, weight: .ultraLight))
                .foregroundColor(Color(hex: "3A3A3A"))
            Text("No plans yet")
                .font(.system(size: 18, weight: .light))
                .foregroundColor(.secondary)
            Button(action: { showingCreate = true }) {
                Text("CREATE YOUR FIRST PLAN")
                    .font(.system(size: 12, weight: .semibold,
                                  design: .monospaced))
                    .kerning(2)
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .cornerRadius(10)
            }
        }
    }

    var planList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(store.plans) { plan in
                    NavigationLink(value: PlanNavID(id: plan.id)) {
                        PlanRowView(plan: plan)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            store.deletePlan(plan)
                        } label: {
                            Label("Delete Plan", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
}

// MARK: - Plan Row

struct PlanRowView: View {
    let plan: SavedPlan

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; return f
    }()

    var daysUntilRace: Int {
        let comps = Calendar.current.dateComponents(
            [.day], from: Date(), to: plan.raceDate)
        return max(0, comps.day ?? 0)
    }

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white)
                .frame(width: 3, height: 50)

            VStack(alignment: .leading, spacing: 6) {
                Text(plan.name)
                    .font(.system(size: 16, weight: .medium))
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
                    .foregroundColor(Color(hex: "3E3E3E"))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
