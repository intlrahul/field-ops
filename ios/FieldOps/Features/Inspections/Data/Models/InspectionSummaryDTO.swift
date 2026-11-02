import Foundation

nonisolated struct InspectionSummaryDTO: Decodable, Sendable {
    let id: String
    let title: String
    let status: InspectionStatus
    let asset: AssetSnapshotDTO
    let dueAt: String?

    func toDomain() throws -> Inspection {
        try Inspection(
            id: id,
            title: title,
            assetName: asset.name,
            status: status,
            dueDate: dueAt.map(inspectionDate)
        )
    }
}
