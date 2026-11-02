import Foundation
import Observation
import SwiftUI
import PathRouter

public enum AuthenticationState: Sendable { case restoring, signedOut, signedIn }
public enum NavigationMode: Sendable { case canonical, push }

@MainActor
@Observable
public final class Router {
    public private(set) var path: [RouteEntry] = []
    public private(set) var authentication: AuthenticationState
    public private(set) var needsSignIn = false
    public private(set) var lastError: String?
    public let registry: RouteRegistry
    @ObservationIgnored private var pending: ResolvedRoute?

    public init(registry: RouteRegistry, authentication: AuthenticationState = .restoring) {
        self.registry = registry
        self.authentication = authentication
    }

    /// Canonical navigation constructs the registered parent chain. Push preserves history.
    public func navigate(to path: String, mode: NavigationMode = .canonical) throws {
        let resolved = try registry.resolve(path)
        if resolved.requiresAuthentication && authentication != .signedIn {
            pending = resolved
            needsSignIn = authentication == .signedOut
            return
        }
        apply(resolved, mode: mode)
    }

    /// Returns false for unsupported/malformed links, leaving the stack unchanged.
    @discardableResult
    public func open(_ url: URL, configuration: DeepLinkConfiguration) -> Bool {
        do {
            try navigate(to: configuration.path(from: url))
            lastError = nil
            return true
        } catch {
            lastError = String(describing: error)
            return false
        }
    }

    /// Call after startup restoration or successful login. Latest pending link wins.
    public func setAuthentication(_ state: AuthenticationState) {
        authentication = state
        switch state {
        case .restoring: needsSignIn = false
        case .signedOut:
            path = []
            needsSignIn = pending != nil
        case .signedIn:
            needsSignIn = false
            if let destination = pending {
                pending = nil
                apply(destination, mode: .canonical)
            }
        }
    }

    /// Actual logout clears pending external navigation as well as protected history.
    public func resetForSignOut() {
        pending = nil
        path = []
        authentication = .signedOut
        needsSignIn = false
    }

    public func back() { if !path.isEmpty { path.removeLast() } }
    public func popToRoot() { path = [] }

    /// Binding setter for system Back/swipe-back. Only accepts a prefix of the current stack.
    public func acceptSystemPath(_ newPath: [RouteEntry]) {
        guard newPath.count <= path.count,
              Array(path.prefix(newPath.count)) == newPath else { return }
        path = newPath
    }

    private func apply(_ resolved: ResolvedRoute, mode: NavigationMode) {
        switch mode {
        case .canonical: path = Array(resolved.entries.dropFirst())
        case .push:
            guard let target = resolved.entries.last,
                  target.pattern != registry.rootPattern,
                  path.last != target else { return }
            path.append(target)
        }
    }
}

/// A single registration contains matching metadata and screen construction.
@MainActor
public struct ScreenRoute {
    public let definition: RouteDefinition
    let build: (RouteEntry) -> AnyView

    public init<Content: View>(
        _ pattern: String,
        parent: String? = nil,
        requiresAuthentication: Bool = true,
        validate: @escaping @Sendable ([String: String]) throws -> Void = { _ in },
        @ViewBuilder destination: @escaping (RouteEntry) -> Content
    ) {
        self.init(
            definition: RouteDefinition(pattern, parent: parent,
                                        requiresAuthentication: requiresAuthentication, validate: validate),
            destination: destination
        )
    }

    /// Reuse feature-owned metadata when composing the router before its screens.
    public init<Content: View>(
        definition: RouteDefinition,
        @ViewBuilder destination: @escaping (RouteEntry) -> Content
    ) {
        self.definition = definition
        build = { AnyView(destination($0)) }
    }
}

@MainActor
public struct ScreenRegistry {
    public let routes: RouteRegistry
    private let screens: [String: ScreenRoute]

    public init(root: String = "/", screens: [ScreenRoute]) throws {
        routes = try RouteRegistry(root: root, routes: screens.map(\.definition))
        self.screens = Dictionary(uniqueKeysWithValues: screens.map { ($0.definition.pattern, $0) })
    }

    public func makeRouter(authentication: AuthenticationState = .restoring) -> Router {
        Router(registry: routes, authentication: authentication)
    }

    func screen(for entry: RouteEntry) -> AnyView {
        guard let screen = screens[entry.pattern] else {
            return AnyView(Text("Destination unavailable"))
        }
        return screen.build(entry)
    }
}

/// Root + destination mapping + router environment. Keep registry/router paired and app-owned.
@MainActor
public struct RouterStack: View {
    private let router: Router
    private let screens: ScreenRegistry
    private let root: RouteEntry

    public init(router: Router, screens: ScreenRegistry) throws {
        self.router = router
        self.screens = screens
        guard let root = try screens.routes.resolve(screens.routes.rootPattern).entries.first else {
            throw RoutingError.invalidRegistration(screens.routes.rootPattern)
        }
        self.root = root
    }

    public var body: some View {
        NavigationStack(path: Binding(
            get: { router.path },
            set: { router.acceptSystemPath($0) }
        )) {
            screens.screen(for: root)
                .navigationDestination(for: RouteEntry.self) { entry in
                    screens.screen(for: entry)
                }
        }
        .environment(router)
    }
}
