//
//  RefreshTokenRequestDTO.swift
//  FieldOps
//
//  Created by Rahul Singh on 19/10/26.
//

nonisolated struct RefreshTokenRequestDTO: Encodable, Sendable {
    let refreshToken: String
}
