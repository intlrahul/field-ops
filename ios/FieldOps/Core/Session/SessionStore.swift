//
//  SessionStore.swift
//  FieldOps
//
//  Created by Rahul Singh on 15/10/26.
//

actor SessionStore: SessionProvider, SessionWriter {
    private var session: Session?
    
    init(session: Session? = nil) {
        self.session = session
    }
    
    func saveSession(_ session: Session) async {
        self.session = session
    }

    func refreshToken() async -> String? {
        session?.credentials.refreshToken
    }

    func currentUser() async -> User? {
        session?.user
    }

    func accessToken() async -> String? {
        session?.credentials.accessToken
    }
    
    func clearSession() async {
        session = nil
    }

}
