nonisolated struct User: Identifiable, Sendable, Codable {
    let id: String
    let name: String
    let email: String
    let roles: [String]
    let organizationId: String?
    let capabilities: Set<String>

    init(id: String, name: String, email: String, roles: [String] = [],
         organizationId: String? = nil, capabilities: Set<String> = []) {
        self.id = id
        self.name = name
        self.email = email
        self.roles = roles
        self.organizationId = organizationId
        self.capabilities = capabilities
    }

    func can(_ capability: Capability) -> Bool { capabilities.contains(capability.rawValue) }

    private enum CodingKeys: String, CodingKey { case id, name, email, roles, organizationId, capabilities }

    // Sessions written before capability support remain readable, with no inferred grants.
    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        email = try values.decode(String.self, forKey: .email)
        roles = try values.decodeIfPresent([String].self, forKey: .roles) ?? []
        organizationId = try values.decodeIfPresent(String.self, forKey: .organizationId)
        capabilities = try values.decodeIfPresent(Set<String>.self, forKey: .capabilities) ?? []
    }
}
