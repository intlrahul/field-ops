//
//  AuthFactory.swift
//  FieldOps
//
//  Created by Rahul Singh on 17/10/26.
//

@MainActor
struct AuthFactory {
    private let sessionProvider: any SessionProvider
    private let sessionWriter: any SessionWriter

    let authRepository: any AuthRepository
    let restoreSessionUseCase: any RestoreSessionUseCase
    let refreshSessionUseCase: any RefreshSessionUseCase

    init(
        apiClient: any APIClient,
        sessionProvider: any SessionProvider,
        sessionWriter: any SessionWriter,
    ) {
        self.sessionWriter = sessionWriter
        self.sessionProvider = sessionProvider
        
        self.authRepository = RemoteAuthRepository(apiClient: apiClient)

        refreshSessionUseCase = DefaultRefreshSessionUseCase(
            authRepository: authRepository,
            sessionProvider: sessionProvider,
            sessionWriter: sessionWriter,
        )

        restoreSessionUseCase = DefaultRestoreSessionUseCase(
            sessionProvider: sessionProvider,
            sessionWriter: sessionWriter,
            refreshSessionUseCase: refreshSessionUseCase,
        )
    }

    func signoutUseCase() -> any SignoutUseCase {
        DefaultSignoutUseCase(
            authRepository: authRepository,
            sessionWriter: sessionWriter,
            sessionProvider: sessionProvider
        )
    }

    func loginViewModel() -> LoginViewModel {
        let useCase = DefaultSignInUseCase(
            authRepository: authRepository,
            sessionWriter: sessionWriter
        )

        return LoginViewModel(signInUseCase: useCase)
    }
}
