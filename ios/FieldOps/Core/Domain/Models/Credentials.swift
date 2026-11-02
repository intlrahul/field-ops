//
//  Credentials.swift
//  FieldOps
//
//  Created by Rahul Singh on 15/10/26.
//

import Foundation

nonisolated struct Credentials: Sendable, Codable {
    let tokenType: String
    let accessToken: String
    let refreshToken: String
    let accessTokenExpiresAt: Date
    let sessionExpiresAt: Date
}
