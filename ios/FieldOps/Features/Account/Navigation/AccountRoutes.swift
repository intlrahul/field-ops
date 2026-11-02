import SwiftUI

@MainActor
enum AccountRoutes {
    static let path = "/account"

    static func registrations(
        sessionProvider: any SessionProvider,
        signoutUseCase: any SignoutUseCase
    ) -> [FeatureRoute] {
        [
            FeatureRoute(path, parent: "/") { _, actions in
                AccountScreen(
                    viewModel: AccountViewModel(
                        sessionProvider: sessionProvider,
                        signoutUseCase: signoutUseCase
                    ),
                    onSignedOut: actions.onSignedOut
                )
            }
        ]
    }
}
