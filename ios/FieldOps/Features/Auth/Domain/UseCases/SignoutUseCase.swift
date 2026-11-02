//
//  SignoutUseCase.swift
//  FieldOps
//
//  Created by Rahul Singh on 19/10/26.
//

protocol SignoutUseCase {
    func execute() async throws
}

struct DefaultSignoutUseCase: SignoutUseCase {
    private let authRepository: any AuthRepository
    private let sessionProvider: any SessionProvider
    private let sessionWriter: any SessionWriter

    init(
        authRepository: any AuthRepository,
        sessionWriter: any SessionWriter,
        sessionProvider: any SessionProvider
    ) {
        self.authRepository = authRepository
        self.sessionWriter = sessionWriter
        self.sessionProvider = sessionProvider
    }

    func execute() async throws {
        guard await sessionProvider.credentials() != nil else {
            throw SessionError.noSession
        }
        try await authRepository.signOut()
        try await sessionWriter.clearSession()
    }
}
