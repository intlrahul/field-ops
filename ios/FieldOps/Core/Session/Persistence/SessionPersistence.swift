//
//  SessionPersistence.swift
//  FieldOps
//
//  Created by Rahul Singh on 19/10/26.
//

protocol SessionPersistence: Sendable {
    func save(session: Session) async throws
    func getSession() async throws -> Session?
    func clearSession() async throws
}

nonisolated enum SessionError: Error, Sendable {
    case noSession
    case corruptedStoredSession
}
