import Foundation

nonisolated struct ReadingDTO: Decodable, Sendable {
    let id: String
    let position: Int
    let label: String
    let unit: String
    let required: Bool
    let minValue: Double?
    let maxValue: Double?
    let value: Double?
    let rangeStatus: String
}
