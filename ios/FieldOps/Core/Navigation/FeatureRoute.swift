import SwiftUI
import PathRouter
import PathRouterUI

/// App actions exposed to feature assembly without exposing the coordinator.
@MainActor
struct NavigationActions {
    let onSignedOut: () -> Void
}

/// Registers metadata and a deferred destination together, once per screen.
@MainActor
struct FeatureRoute {
    let definition: RouteDefinition
    private let build: (NavigationActions) -> ScreenRoute

    init<Destination: View>(
        _ path: String,
        parent: String? = nil,
        requiresAuthentication: Bool = true,
        validate: @escaping @Sendable ([String: String]) throws -> Void = { _ in },
        @ViewBuilder destination: @escaping (RouteEntry, NavigationActions) -> Destination
    ) {
        let definition = RouteDefinition(path, parent: parent,
                                         requiresAuthentication: requiresAuthentication, validate: validate)
        self.definition = definition
        self.build = { actions in
            ScreenRoute(definition: definition) { entry in destination(entry, actions) }
        }
    }

    func screen(actions: NavigationActions) -> ScreenRoute { build(actions) }
}
