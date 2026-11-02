//
//  User.swift
//  FieldOps
//
//  Created by Rahul Singh on 15/10/26.
//

nonisolated struct User: Identifiable, Sendable, Codable {
    let id: String
    let name: String
    let email: String
}
