import Foundation

nonisolated struct InspectionPage: Sendable {
    let items: [Inspection]
    let nextCursor: String?
}

nonisolated struct InspectionDetail: Sendable {
    let summary: Inspection
    let assetTag: String
    let location: String?
    let checklist: [InspectionCheck]
    let readings: [InspectionReading]
    let notes: [InspectionNote]
    var organizationId: String? = nil
    var allowedActions: Set<String> = []
    var completionBlockers: [InspectionCompletionBlocker] = []

    func allows(_ action: InspectionAction) -> Bool { allowedActions.contains(action.rawValue) }
}

nonisolated struct InspectionCheck: Identifiable, Sendable {
    let id: String
    let label: String
    let required: Bool
    let result: String?
    let failureNote: String?
}

nonisolated struct InspectionReading: Identifiable, Sendable {
    let id: String
    let label: String
    let unit: String
    let required: Bool
    let minValue: Double?
    let maxValue: Double?
    let value: Double?
    let rangeStatus: String
}

nonisolated struct InspectionNote: Identifiable, Sendable {
    let id: String
    let authorId: String
    let text: String
    let createdAt: Date
}
