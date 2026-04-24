import SwiftUI

// MARK: - Plan List (root screen showing all saved plans)

struct PlanListView: View {
    @EnvironmentObject var store: PlanStore
    @State private var showingCreate = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0F0F0F").ignoresSafeArea()

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
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingCreate) {
                CreatePlanView()
                    .environmentObject(store)
            }
        }
        .colorScheme(.dark)
    }

    // MARK: Empty State

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run")
                .font(.system(size: 52, weight: .ultraLight))
                .foregroundColor(Color(hex: "3A3A3A"))
            Text("No plans yet")
                .font(.system(size: 18, weight: .light))
                .foregroundColor(Color(hex: "5E5E5E"))
            Button(action: { showingCreate = true }) {
                Text("CREATE YOUR FIRST PLAN")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .kerning(2)
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .cornerRadius(10)
            }
        }
    }

    // MARK: Plan List

    var planList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(store.plans) { plan in
                    NavigationLink(destination: SavedPlanView(plan: plan)) {
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
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var daysUntilRace: Int {
        let comps = Calendar.current.dateComponents([.day], from: Date(), to: plan.raceDate)
        return max(0, comps.day ?? 0)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Color accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white)
                .frame(width: 3, height: 50)

            VStack(alignment: .leading, spacing: 6) {
                Text(plan.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)

                HStack(spacing: 12) {
                    Label(plan.planType, systemImage: "doc.text")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(hex: "5E5E5E"))

                    Label(dateFormatter.string(from: plan.raceDate), systemImage: "flag.checkered")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(hex: "5E5E5E"))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(daysUntilRace)")
                    .font(.system(size: 22, weight: .thin, design: .monospaced))
                    .foregroundColor(.white)
                Text("days")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(hex: "3E3E3E"))
            }
        }
        .padding(16)
        .background(Color(hex: "1A1A1A"))
        .cornerRadius(12)
    }
}
