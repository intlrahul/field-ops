protocol InspectionRepository: Sendable {
    func statistics() async throws -> InspectionStatistics
    func list(cursor: String?, status: InspectionStatus?) async throws -> InspectionPage
    func detail(id: String) async throws -> InspectionDetail
}

/// Explicit preview/test dependency; production routes receive the remote repository.
struct PreviewInspectionRepository: InspectionRepository {
    func statistics() async throws -> InspectionStatistics {
        InspectionStatistics(total: 10, assigned: 4, inProgress: 3, completed: 3)
    }

    func list(cursor: String?, status: InspectionStatus?) async throws -> InspectionPage {
        InspectionPage(items: Inspection.samples.filter { status == nil || $0.status == status }, nextCursor: nil)
    }

    func detail(id: String) async throws -> InspectionDetail {
        guard let summary = Inspection.samples.first(where: { $0.id == id })
        else {
            throw BackendError(
                code: "NOT_FOUND",
                message: "Inspection not found."
            )
        }
        return InspectionDetail(
            summary: summary,
            assetTag: "PREVIEW",
            location: nil,
            checklist: [],
            readings: [],
            notes: []
        )
    }
}
