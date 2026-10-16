//
//  AppContainer.swift
//  FieldOps
//
//  Created by Rahul Singh on 15/10/26.
//

import Foundation

@MainActor
final class AppContainer {
    let sessionStore: SessionStore
    let apiClient: AlamofireAPIClient
    let authRepository: RemoteAuthRepository

    init(baseURL: URL) {
        let sessionStore = SessionStore()

        let apiClient = AlamofireAPIClient(
            baseURL: baseURL,
            accessTokenProvider: sessionStore
        )

        let authRepository = RemoteAuthRepository(
            apiClient: apiClient
        )

        self.sessionStore = sessionStore
        self.apiClient = apiClient
        self.authRepository = authRepository
    }

    func loginViewModel() -> LoginViewModel {
        let repository = RemoteAuthRepository(apiClient: apiClient)

        let useCase = DefaultSignInUseCase(
            authRepository: repository,
            sessionWriter: sessionStore
        )

        return LoginViewModel(signInUseCase: useCase)
    }
}
