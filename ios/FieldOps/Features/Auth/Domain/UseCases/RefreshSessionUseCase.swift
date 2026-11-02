//
//  RestoreSessionUseCase.swift
//  FieldOps
//
//  Created by Rahul Singh on 19/10/26.
//

protocol RefreshSessionUseCase: Sendable {
    func execute() async throws
}

nonisolated enum RefreshSessionError: Error, Sendable {
    case rejected
}

nonisolated struct DefaultRefreshSessionUseCase: RefreshSessionUseCase {
    private let authRepository: any AuthRepository
    private let sessionProvider: any SessionProvider
    private let sessionWriter: any SessionWriter

    init(
        authRepository: any AuthRepository,
        sessionProvider: any SessionProvider,
        sessionWriter: any SessionWriter
    ) {
        self.authRepository = authRepository
        self.sessionProvider = sessionProvider
        self.sessionWriter = sessionWriter
    }

    func execute() async throws {
        guard let credentials = await sessionProvider.credentials() else {
            throw SessionError.noSession
        }

        let session = try await authRepository.refreshSession(
            refreshToken: credentials.refreshToken
        )

        try Task.checkCancellation()
        try await sessionWriter.saveSession(session)
    }
}
