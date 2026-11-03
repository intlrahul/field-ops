import Foundation

nonisolated struct InspectionDetailDTO: Decodable, Sendable {
    let id: String
    let title: String
    let status: InspectionStatus
    let asset: AssetSnapshotDTO
    let dueAt: String?
    let checklistItems: [CheckDTO]
    let readings: [ReadingDTO]
    let notes: [NoteDTO]
    let organizationId: String?
    let allowedActions: [String]?
    let completionBlockers: [InspectionCompletionBlockerDTO]?

    func toDomain() throws -> InspectionDetail {
        try InspectionDetail(
            summary: Inspection(
                id: id,
                title: title,
                assetName: asset.name,
                status: status,
                dueDate: dueAt.map(inspectionDate)
            ),
            assetTag: asset.assetTag,
            location: asset.location,
            checklist: checklistItems.sorted { $0.position < $1.position }.map {
                InspectionCheck(
                    id: $0.id,
                    label: $0.label,
                    required: $0.required,
                    result: $0.result,
                    failureNote: $0.failureNote
                )
            },
            readings: readings.sorted { $0.position < $1.position }.map {
                InspectionReading(
                    id: $0.id,
                    label: $0.label,
                    unit: $0.unit,
                    required: $0.required,
                    minValue: $0.minValue,
                    maxValue: $0.maxValue,
                    value: $0.value,
                    rangeStatus: $0.rangeStatus
                )
            },
            notes: notes.map {
                try InspectionNote(
                    id: $0.id,
                    authorId: $0.authorId,
                    text: $0.text,
                    createdAt: inspectionDate($0.createdAt)
                )
            },
            organizationId: organizationId,
            allowedActions: Set(allowedActions ?? []),
            completionBlockers: (completionBlockers ?? []).map {
                InspectionCompletionBlocker(code: $0.code, itemId: $0.itemId)
            }
        )
    }
}

nonisolated struct InspectionCompletionBlockerDTO: Decodable, Sendable {
    let code: String
    let itemId: String
}
