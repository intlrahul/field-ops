//
//  UserDTO.swift
//  FieldOps
//
//  Created by Rahul Singh on 16/10/26.
//

nonisolated enum UserRole: String, Decodable, Sendable {
    case supervisor
    case technician
}

nonisolated struct UserDTO: Decodable, Sendable {
    let id: String
    let email: String
    let role: UserRole
}

extension UserDTO {
    func toDomain() -> User {
        User(
            id: id,
            name: email,
            email: email
        )
    }
}
