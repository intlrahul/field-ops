//
//  SessionStore.swift
//  FieldOps
//
//  Created by Rahul Singh on 15/10/26.
//

actor SessionStore: SessionProvider, SessionWriter {
    private var session: Session?
    private var persistence: SessionPersistence

    init(session: Session? = nil, persistence: SessionPersistence) {
        self.session = session
        self.persistence = persistence
    }
    
    func credentials() async -> Credentials? {
        session?.credentials
    }
    
    func currentUser() async -> User? {
        session?.user
    }
    
    func accessToken() async -> String? {
        session?.credentials.accessToken
    }
    
    func restoreSession() async throws {
        self.session = try await persistence.getSession()
    }

    func saveSession(_ session: Session) async throws {
        self.session = session
        try await persistence.save(session: session)
    }

    func clearSession() async throws {
        session = nil
        try await persistence.clearSession()
    }

}
