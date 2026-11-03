protocol GetCurrentUserUseCase: Sendable {
    func execute() async throws -> User
}

struct DefaultGetCurrentUserUseCase: GetCurrentUserUseCase {
    private let repository: any AuthRepository
    init(repository: any AuthRepository) { self.repository = repository }
    func execute() async throws -> User { try await repository.currentUser() }
}

/// Explicit preview dependency. Production always fetches /me before exposing inspection features.
struct PreviewCurrentUserUseCase: GetCurrentUserUseCase {
    func execute() async throws -> User {
        User(id: "preview", name: "Technician", email: "preview@fieldops.test", roles: ["technician"],
             capabilities: ["assets.read", "inspections.read", "inspections.perform"])
    }
}
