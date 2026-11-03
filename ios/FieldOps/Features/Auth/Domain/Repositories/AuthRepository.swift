//
//  AuthRepository.swift
//  FieldOps
//
//  Created by Rahul Singh on 15/10/26.
//

protocol AuthRepository: Sendable {
    func currentUser() async throws -> User

    func signIn(
        email: String,
        password: String
    ) async throws -> Session

    func refreshSession(
        refreshToken: String
    ) async throws -> Session

    func signOut() async throws
}
