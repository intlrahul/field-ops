//
//  Session.swift
//  FieldOps
//
//  Created by Rahul Singh on 15/10/26.
//

nonisolated struct Session: Codable, Sendable {
    let user: User
    let credentials: Credentials
}
