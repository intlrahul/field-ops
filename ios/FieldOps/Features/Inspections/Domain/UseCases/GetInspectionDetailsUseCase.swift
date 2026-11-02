protocol GetInspectionDetailsUseCase: Sendable {
    func execute(id: String) async throws -> InspectionDetail
}

struct DefaultGetInspectionDetailsUseCase: GetInspectionDetailsUseCase {
    private let repository: any InspectionRepository

    init(repository: any InspectionRepository) { self.repository = repository }

    func execute(id: String) async throws -> InspectionDetail {
        try await repository.detail(id: id)
    }
}
