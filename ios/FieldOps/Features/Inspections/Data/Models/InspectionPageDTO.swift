import Foundation

nonisolated struct InspectionPageDTO: Decodable, Sendable {
    let items: [InspectionSummaryDTO]
    let nextCursor: String?
    func toDomain() throws -> InspectionPage {
        try InspectionPage(items: items.map { try $0.toDomain() }, nextCursor: nextCursor)
    }
}
