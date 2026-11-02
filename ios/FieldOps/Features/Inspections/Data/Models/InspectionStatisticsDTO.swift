import Foundation

nonisolated struct InspectionStatisticsDTO: Decodable, Sendable {
    let total: Int
    let assigned: Int
    let inProgress: Int
    let completed: Int
    func toDomain() -> InspectionStatistics {
        InspectionStatistics(total: total, assigned: assigned, inProgress: inProgress, completed: completed)
    }
}
