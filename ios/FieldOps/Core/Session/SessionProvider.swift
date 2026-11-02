//
//  SessionProvider.swift
//  FieldOps
//
//  Created by Rahul Singh on 15/10/26.
//

protocol SessionProvider: AccessTokenProvider {
    func restoreSession() async throws
    func credentials() async -> Credentials?
    func currentUser() async -> User?
}
