//
//  AuthRepository.swift
//  FieldOps
//
//  Created by Rahul Singh on 15/10/26.
//

protocol AuthRepository: Sendable {
    func signIn(email: String, password: String) async throws -> Session
}
