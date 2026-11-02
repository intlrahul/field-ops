protocol GetInspectionStatisticsUseCase: Sendable {
    func execute() async throws -> InspectionStatistics
}

struct DefaultGetInspectionStatisticsUseCase: GetInspectionStatisticsUseCase {
    private let repository: any InspectionRepository

    init(repository: any InspectionRepository) { self.repository = repository }

    func execute() async throws -> InspectionStatistics {
        try await repository.statistics()
    }
}
