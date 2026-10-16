//
//  SignInUseCase.swift
//  FieldOps
//
//  Created by Rahul Singh on 16/10/26.
//

protocol SignInUseCase {
    func execute(email: String, password: String) async throws
}

struct DefaultSignInUseCase: SignInUseCase {
    private let authRepository: any AuthRepository
    private let sessionWriter: any SessionWriter

    init(
        authRepository: any AuthRepository,
        sessionWriter: any SessionWriter
    ) {
        self.authRepository = authRepository
        self.sessionWriter = sessionWriter
    }

    func execute(email: String, password: String) async throws {
        let session = try await authRepository.signIn(
            email: email,
            password: password
        )

        await sessionWriter.saveSession(session)
    }
}
