//
//  DefaultRestoreSessionUseCase.swift
//  FieldOps
//
//  Created by Rahul Singh on 19/10/26.
//

import Foundation

nonisolated struct DefaultRestoreSessionUseCase: RestoreSessionUseCase {
    private let sessionProvider: any SessionProvider
    private let sessionWriter: any SessionWriter
    private let refreshSessionUseCase: any RefreshSessionUseCase
    private let now: @Sendable () -> Date

    init(
        sessionProvider: any SessionProvider,
        sessionWriter: any SessionWriter,
        refreshSessionUseCase: any RefreshSessionUseCase,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.sessionProvider = sessionProvider
        self.sessionWriter = sessionWriter
        self.refreshSessionUseCase = refreshSessionUseCase
        self.now = now
    }

    func execute() async throws -> SessionRestorationResult {
        try await sessionProvider.restoreSession()
        try Task.checkCancellation()

        guard let credentials = await sessionProvider.credentials() else {
            return .signedOut
        }

        let currentDate = now()

        guard credentials.sessionExpiresAt > currentDate else {
            try await sessionWriter.clearSession()
            return .signedOut
        }

        // Refresh slightly early rather than using a nearly expired token.
        if credentials.accessTokenExpiresAt >
            currentDate.addingTimeInterval(30) {
            return .authenticated
        }

        do {
            try await refreshSessionUseCase.execute()
        } catch RefreshSessionError.rejected {
            try await sessionWriter.clearSession()
            return .signedOut
        }

        try Task.checkCancellation()
        return .authenticated
    }
}
