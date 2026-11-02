import Foundation
import PathRouter
import PathRouterUI

@MainActor
final class AppComposition {
    let container: AppContainer
    let coordinator: AppCoordinator
    let navigation: AppNavigation

    init(baseURL: URL) throws {
        let container = AppContainer(baseURL: baseURL)
        let registrations = AppRoutes.registrations(container: container)
        let registry = try RouteRegistry(
            routes: registrations.map(\.definition)
        )
        let router = Router(registry: registry)
        let coordinator = AppCoordinator(
            restoreSessionUseCase: container.authFactory.restoreSessionUseCase,
            router: router
        )
        let actions = NavigationActions(
            onSignedOut: { [weak coordinator] in
                coordinator?.didSignOut()
            }
        )
        self.container = container
        self.coordinator = coordinator
        self.navigation = try AppNavigation(
            router: router,
            routes: registrations.map { $0.screen(actions: actions) }
        )
    }
}
