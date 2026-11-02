import Foundation

nonisolated struct CheckDTO: Decodable, Sendable {
    let id: String
    let position: Int
    let label: String
    let required: Bool
    let result: String?
    let failureNote: String?
}
