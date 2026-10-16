//
//  LoginRequestDTO.swift
//  FieldOps
//
//  Created by Rahul Singh on 15/10/26.
//

nonisolated struct LoginRequestDTO: Encodable, Sendable {
    let email: String
    let password: String
}
