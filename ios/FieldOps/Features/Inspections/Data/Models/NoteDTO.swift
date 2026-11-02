import Foundation

nonisolated struct NoteDTO: Decodable, Sendable {
    let id: String
    let authorId: String
    let text: String
    let createdAt: String
}
