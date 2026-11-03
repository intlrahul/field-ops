import Foundation
import Testing
@testable import FieldOps

private actor MutableCurrentUser: GetCurrentUserUseCase {
    private var user: User
    init(capabilities: Set<String>) {
        user = User(id: "user", name: "User", email: "user@test.com", capabilities: capabilities)
    }
    func execute() async throws -> User { user }
    func revoke() { user = User(id: "user", name: "User", email: "user@test.com") }
}

private actor CapabilityInspectionRepository: InspectionRepository {
    private var reads = 0
    func list(cursor: String?, status: InspectionStatus?) async throws -> InspectionPage {
        reads += 1
        return InspectionPage(items: Inspection.samples, nextCursor: nil)
    }
    func statistics() async throws -> InspectionStatistics {
        reads += 1
        return InspectionStatistics(total: 10, assigned: 4, inProgress: 3, completed: 3)
    }
    func detail(id: String) async throws -> InspectionDetail {
        try await PreviewInspectionRepository().detail(id: id)
    }
    func readCount() -> Int { reads }
}

@MainActor
struct CapabilityTests {
    @Test func unknownRolesAndCapabilitiesArePreservedWithoutRoleBasedGrants() throws {
        let data = Data("""
        {"id":"user","email":"user@test.com","role":"future_role","roles":["future_role"],
         "organizationId":"org","capabilities":["inspections.read","future.capability"]}
        """.utf8)
        let user = try JSONDecoder().decode(UserDTO.self, from: data).toDomain()
        #expect(user.roles == ["future_role"])
        #expect(user.can(.inspectionsRead))
        #expect(user.capabilities.contains("future.capability"))
        #expect(!user.can(.inspectionsPerform))
        let missing = Data(#"{"id":"user","email":"user@test.com","role":"supervisor"}"#.utf8)
        let legacy = try JSONDecoder().decode(UserDTO.self, from: missing).toDomain()
        #expect(legacy.capabilities.isEmpty)
        #expect(!legacy.can(.inspectionsRead))
    }

    @Test func persistedLegacyUsersDecodeWithoutInventingPermissions() throws {
        let data = Data(#"{"id":"user","name":"User","email":"user@test.com"}"#.utf8)
        let user = try JSONDecoder().decode(User.self, from: data)
        #expect(user.capabilities.isEmpty)
        #expect(user.organizationId == nil)
        let updated = User(id: user.id, name: user.name, email: user.email,
                           roles: ["technician"], organizationId: "org", capabilities: ["inspections.read"])
        let restored = try JSONDecoder().decode(User.self, from: JSONEncoder().encode(updated))
        #expect(restored.can(.inspectionsRead))
        #expect(restored.organizationId == "org")
    }

    @Test func missingCapabilitiesPreventInspectionRequests() async {
        let repository = CapabilityInspectionRepository()
        let model = InspectionListViewModel(
            getInspections: DefaultGetInspectionsUseCase(repository: repository),
            getStatistics: DefaultGetInspectionStatisticsUseCase(repository: repository),
            getCurrentUser: MutableCurrentUser(capabilities: []))
        await model.refresh()
        #expect(!model.canReadInspections)
        #expect(model.accessError != nil)
        #expect(await repository.readCount() == 0)
    }

    @Test func refreshedPermissionsClearPreviouslyLoadedInspectionContent() async {
        let repository = CapabilityInspectionRepository()
        let profile = MutableCurrentUser(capabilities: ["inspections.read"])
        let model = InspectionListViewModel(
            getInspections: DefaultGetInspectionsUseCase(repository: repository),
            getStatistics: DefaultGetInspectionStatisticsUseCase(repository: repository),
            getCurrentUser: profile)
        await model.refresh()
        #expect(model.canReadInspections)
        #expect(model.statistics?.total == 10)
        await profile.revoke()
        await model.refresh()
        #expect(!model.canReadInspections)
        #expect(model.inspections.isEmpty)
        #expect(model.statistics == nil)
        #expect(model.nextCursor == nil)
    }

    @Test func actionMappingPreservesUnknownStringsAndDefaultsMissingActionsToUnavailable() throws {
        let base: [String: Any] = [
            "id": "inspection", "title": "Inspection", "status": "assigned",
            "asset": ["assetTag": "TEST", "name": "Pump"],
            "checklistItems": [], "readings": [], "notes": []
        ]
        let missing = try JSONDecoder().decode(InspectionDetailDTO.self, from: JSONSerialization.data(withJSONObject: base)).toDomain()
        #expect(!missing.allows(.start))
        var payload = base
        payload["allowedActions"] = ["start", "future_action"]
        payload["completionBlockers"] = [["code": "FUTURE_BLOCKER", "itemId": "item"]]
        let detail = try JSONDecoder().decode(InspectionDetailDTO.self, from: JSONSerialization.data(withJSONObject: payload)).toDomain()
        #expect(detail.allows(.start))
        #expect(!detail.allows(.complete))
        #expect(detail.allowedActions.contains("future_action"))
        #expect(detail.completionBlockers.first?.code == "FUTURE_BLOCKER")
    }
}

private actor MutableInspectionDetails: GetInspectionDetailsUseCase {
    private var revoked = false
    func execute(id: String) async throws -> InspectionDetail {
        if revoked { throw BackendError(code: "FORBIDDEN", message: "Access changed.") }
        var detail = try await PreviewInspectionRepository().detail(id: "inspection-001")
        detail.allowedActions = ["start"]
        return detail
    }
    func revoke() { revoked = true }
}

extension CapabilityTests {
    @Test func detailDenialRemovesPreviouslyAdvertisedActions() async {
        let source = MutableInspectionDetails()
        let model = InspectionDetailViewModel(id: "inspection-001", getDetails: source)
        await model.load()
        #expect(model.allows(.start))
        await source.revoke()
        await model.load()
        #expect(!model.allows(.start))
        #expect(model.detail == nil)
        #expect(model.errorMessage == "Access changed.")
    }
}
