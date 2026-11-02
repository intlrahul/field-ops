# iOS navigation with PathRouter

The user explicitly authorized this iOS integration. The local package is under ios/local_dependencies/PathRouter. Both PathRouter and PathRouterUI are linked to the app target.

Feature-owned registration lives in Features/Account/Navigation/AccountRoutes.swift and Features/Dashboard/Navigation/DashboardRoutes.swift. Each feature owns its path constants and a single list of FeatureRoute registrations containing both metadata and deferred screen builders. AccountRoutes constructs AccountScreen and AccountViewModel directly in its deferred route builder using injected SessionProvider, SignoutUseCase, and onSignedOut. It depends on neither AppCoordinator nor AppContainer. AccountScreen retains its view model in State; the AccountDestination wrapper has been removed. AccountFactory and its AppContainer extension have been removed. AuthFactory retains its useful repository/use-case composition role.

FieldOpsApp only creates/retains AppComposition and displays its root. App/Dependencies/AppComposition.swift owns dependency and lifecycle wiring. App/Navigation/AppRoutes.swift owns the combined feature-registration list, exposed through registrations(container:). It derives metadata from those registrations → creates Router → creates AppCoordinator → materializes screen builders with injected NavigationActions → creates AppNavigation. Account's sign-out action captures the coordinator weakly.

Core/Navigation/FeatureRoute.swift contains the shared registration value and NavigationActions callback context. Each registration declares its RouteDefinition and destination once. Screen construction is deferred until callbacks are available, avoiding circular initialization or mutable callback holders. The local PathRouter ScreenRoute(definition:destination:) initializer reuses the same metadata. Features depend on the callback contract, not AppCoordinator.

AppNavigation is generic: it receives a router and registered screens, validates the screen registry, and constructs RouterStack. It contains no screen-specific destination or adapter. Adding another screen to an existing feature changes that feature's registration only. Adding a feature adds one registration entry to AppRoutes' combined list. Neither FieldOpsApp nor AppNavigation needs screen/feature-specific edits. The router and screen registry are constructed from the same feature-owned definitions. Dashboard is /; Account is /account with / as its parent.

AppCoordinator owns session/root-flow transitions, not a separate navigation path. It updates router authentication on restoration/login and calls resetForSignOut on logout. Restoring without a session preserves a pending link. Successful restoration or login resumes it. Logout discards navigation and pending links. A restoration revision guard prevents an older asynchronous result from replacing a later login/logout UI transition; it does not redesign cancellation or persistence inside session use cases.

AppRootView displays loading, login, or the retained RouterStack. Its outer onOpenURL forwards links even while login or loading is visible. Configuration/Info.plist registers the fieldops scheme; public HTTPS universal links are not configured.

Dashboard uses Router from the environment and AccountRoutes.path with push mode. PathRouter's deep-link handling uses canonical parent chains. Unknown/malformed links preserve the existing stack; lastError is available on Router. Navigation errors from the Account button show an alert. The old SignedRoute, destination switch, signedInPath/pendingRoute, and DeepLinkParser have been removed.

PathRouter deliberately rejects trailing slashes and query/fragment payloads, so use fieldops://account (not fieldops://account/). The former parser accepted a trailing slash; this integration adopts the package's stricter behavior.

## Required procedure for new routes

This is the official project convention, recorded in decisions/0005-feature-owned-navigation.md and AGENTS.md.

1. Open Features/<Feature>/Navigation/<Feature>Routes.swift (create it for a new feature).
2. Add a named path and one FeatureRoute entry containing the explicit parent, any parameter validation, and the screen builder. Keep route patterns in this feature file; encode dynamic values with RoutePath.encodeSegment at call sites.
3. Build the screen/view model inside the deferred builder using injected dependencies. Let the screen retain its view model. Use NavigationActions for app callbacks; do not reach into AppContainer or AppCoordinator.
4. For a new feature only, add its registrations once to App/Navigation/AppRoutes.swift and supply dependencies there. An existing feature's new screens do not change the app-level list.
5. Leave FieldOpsApp, AppComposition, and AppNavigation unchanged for routine screen additions. Shared infrastructure dependencies or new app actions may legitimately require composition changes.
6. Verify internal navigation and deep links resolve to the same destination, explicit parent/back behavior is correct, invalid parameters/unknown links preserve the stack, and protected links resume after restoration/login but do not survive logout. Keep backend resource authorization checks independent of navigation.

Do not introduce destination wrappers or factory types solely to forward screen constructors. AuthFactory remains at Features/Auth/AuthFactory.swift because it assembles a meaningful authentication dependency graph.

## Verification

Run package tests:

```sh
swift test --package-path ios/local_dependencies/PathRouter
```

AppNavigationTests covers pending links through authenticated restoration/login, logout clearing, unknown-link preservation, system path truncation, and late restoration after logout. Run FieldOpsTests in Xcode against an installed simulator.

Interactive checks still required:

1. Login, open Account, then use Back and swipe-back to return to Dashboard.
2. While signed out, open fieldops://account, login, and verify Account appears above Dashboard.
3. Launch with a valid saved session and a pending account link; verify restoration opens Account.
4. Logout from Account, then login again; old protected navigation should not return.
5. Unknown links must leave the current screen unchanged.

On a booted simulator:

```sh
xcrun simctl openurl booted 'fieldops://account'
```

Backend behavior and the deferred offline-sync milestone are unchanged.

Verified on 2026-11-02: simulator app build succeeded; 8 package tests and 4 navigation integration tests passed on iPhone 17 / iOS 26.5. The built Info.plist contains the fieldops URL scheme. Tests use stub restoration and do not prove real-screen gestures or backend login, which remain the manual checks above.
