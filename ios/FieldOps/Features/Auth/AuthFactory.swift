//
//  AuthFactory.swift
//  FieldOps
//
//  Created by Rahul Singh on 17/10/26.
//

@MainActor
struct AuthFactory {
    let authRepository: any AuthRepository
    let restoreSessionUseCase: any RestoreSessionUseCase
    let refreshSessionUseCase: any RefreshSessionUseCase
    private let sessionProvider: any SessionProvider
    private let sessionWriter: any SessionWriter

    init(
        apiClient: any APIClient,
        sessionProvider: any SessionProvider,
        sessionWriter: any SessionWriter,
    ) {
        self.authRepository = RemoteAuthRepository(
            apiClient: apiClient
        )
        self.sessionWriter = sessionWriter
        self.sessionProvider = sessionProvider
        
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
