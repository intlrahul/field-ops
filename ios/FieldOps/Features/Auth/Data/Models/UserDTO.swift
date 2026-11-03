nonisolated struct UserDTO: Decodable, Sendable {
    let id: String
    let email: String
    let role: String?
    let roles: [String]?
    let organizationId: String?
    let capabilities: [String]?

    func toDomain() -> User {
        User(id: id, name: email, email: email,
             roles: roles ?? role.map { [$0] } ?? [],
             organizationId: organizationId, capabilities: Set(capabilities ?? []))
    }
}
