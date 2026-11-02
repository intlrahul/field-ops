//
//  DefaultSessionPersistence.swift
//  FieldOps
//
//  Created by Rahul Singh on 19/10/26.
//
import Foundation

private let sessionKey = "session"

actor DefaultSessionPersistence: SessionPersistence {
    private let storage: KeyValueStorage

    init(storage: KeyValueStorage) {
        self.storage = storage
    }

    func save(session: Session) async throws {
        let data = try JSONEncoder().encode(session)
        try await storage.save(key: sessionKey, value: data)
    }

    func getSession() async throws -> Session? {
        let data = try await storage.get(key: sessionKey)

        guard let data = data, !data.isEmpty else {
            throw SessionError.noSession
        }
        do {
            return try JSONDecoder().decode(
                Session.self,
                from: data,
            )
        } catch is DecodingError {
            throw SessionError.corruptedStoredSession
        }
    }

    func clearSession() async throws {
        try await storage.clear(key: sessionKey)
    }

}
