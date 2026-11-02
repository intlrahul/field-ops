import PathRouter
import PathRouterUI

/// Generic assembly of the feature-provided destinations and existing router.
@MainActor
struct AppNavigation {
    let screens: ScreenRegistry
    let router: Router
    let stack: RouterStack

    init(router: Router, routes: [ScreenRoute]) throws {
        let screens = try ScreenRegistry(root: router.registry.rootPattern, screens: routes)
        self.screens = screens
        self.router = router
        self.stack = try RouterStack(router: router, screens: screens)
    }
}
