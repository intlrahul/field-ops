import Foundation

nonisolated struct AssetSnapshotDTO: Decodable, Sendable {
    let assetTag: String
    let name: String
    let location: String?
}
