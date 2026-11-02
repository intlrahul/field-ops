import Foundation

struct RemoteInspectionRepository: InspectionRepository {
    let apiClient: any APIClient

    func statistics() async throws -> InspectionStatistics {
        let response: InspectionStatisticsDTO = try await apiClient.get(
            path: "inspections/statistics",
            requiresAuthentication: true
        )
        return response.toDomain()
    }

    func list(cursor: String?, status: InspectionStatus?) async throws
        -> InspectionPage
    {
        var components = URLComponents()
        components.path = "inspections"
        components.queryItems = [URLQueryItem(name: "limit", value: "20")]
        if let status {
            components.queryItems?.append(
                URLQueryItem(name: "status", value: status.rawValue)
            )
        }
        if let cursor {
            components.queryItems?.append(
                URLQueryItem(name: "cursor", value: cursor)
            )
        }
        let response: InspectionPageDTO = try await apiClient.get(
            path: components.string!,
            requiresAuthentication: true
        )
        return try response.toDomain()
    }

    func detail(id: String) async throws -> InspectionDetail {
        guard UUID(uuidString: id) != nil else {
            throw BackendError(
                code: "NOT_FOUND",
                message: "Inspection not found."
            )
        }
        let response: InspectionDetailDTO = try await apiClient.get(
            path: "inspections/\(id)",
            requiresAuthentication: true
        )
        return try response.toDomain()
    }
}
