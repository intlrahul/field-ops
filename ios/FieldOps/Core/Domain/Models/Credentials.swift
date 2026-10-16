//
//  Credentials.swift
//  FieldOps
//
//  Created by Rahul Singh on 15/10/26.
//

import Foundation

struct Credentials: Sendable {
    let accessToken: String
    let refreshToken: String
    let accessTokenExpiresAt: Date
    let sessionExpiresAt: Date
}
