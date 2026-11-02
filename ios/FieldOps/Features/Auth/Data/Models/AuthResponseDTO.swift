//
//  AuthResponseDTO.swift
//  FieldOps
//
//  Created by Rahul Singh on 15/10/26.
//

import Foundation

enum AuthMappingError: Error {
    case invalidTimestamp(String)
}

nonisolated struct AuthResponseDTO: Decodable, Sendable {
    let tokenType: String
    let accessToken: String
    let refreshToken: String
    let accessTokenExpiresAt: String
    let sessionExpiresAt: String
    let user: UserDTO
}

extension AuthResponseDTO {
    func toDomain() throws -> Session {
        Session(
            user: user.toDomain(),
            credentials: try toCredentials()
        )
    }

    func toCredentials() throws -> Credentials {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds,
        ]

        func parseDate(_ value: String) throws -> Date {
            if let date = formatter.date(from: value) {
                return date
            }

            formatter.formatOptions = [.withInternetDateTime]
            let date = formatter.date(from: value)
            formatter.formatOptions = [
                .withInternetDateTime,
                .withFractionalSeconds,
            ]

            guard let date else {
                throw AuthMappingError.invalidTimestamp(value)
            }

            return date
        }

        return Credentials(
            tokenType: tokenType,
            accessToken: accessToken,
            refreshToken: refreshToken,
            accessTokenExpiresAt: try parseDate(accessTokenExpiresAt),
            sessionExpiresAt: try parseDate(sessionExpiresAt)
        )
    }
}
