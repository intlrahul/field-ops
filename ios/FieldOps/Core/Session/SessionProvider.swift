//
//  SessionProvider.swift
//  FieldOps
//
//  Created by Rahul Singh on 15/10/26.
//

protocol SessionProvider: AccessTokenProvider {
    func refreshToken() async -> String?
    func currentUser() async -> User?
}
