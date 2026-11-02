protocol GetInspectionsUseCase: Sendable {
    func execute(cursor: String?, status: InspectionStatus?) async throws
        -> InspectionPage
}

struct DefaultGetInspectionsUseCase: GetInspectionsUseCase {
    private let repository: any InspectionRepository

    init(repository: any InspectionRepository) { self.repository = repository }

    func execute(cursor: String?, status: InspectionStatus?) async throws
        -> InspectionPage
    {
        try await repository.list(cursor: cursor, status: status)
    }
}
