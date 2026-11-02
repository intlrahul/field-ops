import Foundation

nonisolated func inspectionDate(_ value: String) throws -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    guard let date = formatter.date(from: value) else {
        throw BackendError(
            code: "INVALID_RESPONSE",
            message: "The server returned an invalid inspection date."
        )
    }
    return date
}
