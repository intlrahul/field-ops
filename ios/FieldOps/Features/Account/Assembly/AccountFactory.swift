//
//  AccountFactory.swift
//  FieldOps
//
//  Created by Rahul Singh on 19/10/26.
//

extension AppContainer {
    var accountFactory: AccountFactory {
        AccountFactory(
            sessionProvider: sessionStore,
            signoutUseCase: authFactory.signoutUseCase(),
        )
    }
}

@MainActor
struct AccountFactory {
    private let sessionProvider: any SessionProvider
    private let signoutUseCase: any SignoutUseCase

    init(
        sessionProvider: any SessionProvider,
        signoutUseCase: any SignoutUseCase
    ) {
        self.sessionProvider = sessionProvider
        self.signoutUseCase = signoutUseCase
    }

    func accountViewModel() -> AccountViewModel {
        AccountViewModel(
            sessionProvider: sessionProvider,
            signoutUseCase: signoutUseCase
        )
    }
}
