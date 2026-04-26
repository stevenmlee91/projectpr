import Foundation
import Combine

final class WeekDetailViewModel: ObservableObject {
    let planID : UUID
    let weekID : UUID

    @Published var week: SavedWeek?

    private var cancellables = Set<AnyCancellable>()

    // Init without store — store is connected later via connect(to:)
    // This is required because @EnvironmentObject is unavailable in init
    init(planID: UUID, weekID: UUID) {
        self.planID = planID
        self.weekID = weekID
    }

    // Called from .onAppear once @EnvironmentObject is available
    func connect(to store: PlanStore) {
        // Seed immediately with current data
        week = fetchWeek(from: store.plans)

        // Subscribe to future store changes.
        // Updates self.week (@Published on @StateObject) which
        // re-renders the detail view body in place.
        // This never touches NavigationStack.
        store.$plans
            .receive(on: DispatchQueue.main)
            .map { [weak self] plans -> SavedWeek? in
                guard let self else { return nil }
                return self.fetchWeek(from: plans)
            }
            .assign(to: \.week, on: self)
            .store(in: &cancellables)
    }

    private func fetchWeek(from plans: [SavedPlan]) -> SavedWeek? {
        plans
            .first(where: { $0.id == planID })?
            .weeks.first(where: { $0.id == weekID })
    }
}
