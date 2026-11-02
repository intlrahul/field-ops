# PathRouter — initial Swift package

A small path-based router for SwiftUI. Register a path, its explicit parent, access requirement, optional parameter validation, and screen builder once. Internal navigation and deep links use the same registry. No third-party dependencies.

## Requirements and verification

Swift 6.0+, iOS 17+, macOS 14+. Package uses explicit MainActor only for UI/router types; the routing core is Sendable and UI-independent. It does not enable default MainActor isolation.

**Status: initial implementation integrated into FieldOps.** On 2026-11-02, all 8 core package tests passed and the FieldOps simulator app built with both products linked. App navigation integration tests also passed. Interactive back/swipe and authentication/deep-link checks remain in the validation checklist. This is not a production-vetted release.

## Add to Xcode

Unzip, then File → Add Package Dependencies → Add Local, select PathRouter, and add the PathRouterUI product to FieldOps. Import PathRouter for registration metadata and PathRouterUI for screens/router. No app or existing iOS source has been modified.

## Single registration

```swift
let screens = try ScreenRegistry(screens: [
    ScreenRoute("/") { _ in DashboardScreen() },
    ScreenRoute("/account", parent: "/") { _ in
        AccountScreen(/* inject your factory-built model and callbacks */)
    },
    ScreenRoute("/inspections", parent: "/") { _ in InspectionListScreen() },
    ScreenRoute("/inspections/:id", parent: "/inspections") { entry in
        InspectionDetailsScreen(id: entry.parameters["id"]!)
    }
])
let router = screens.makeRouter()
let stack = try RouterStack(router: router, screens: screens)
```

The parameter is guaranteed present by matching; optional semantic validation can reject malformed IDs before navigation. Above app screen names/initializers are illustrative. Builders are synchronous: construct view models with factories and load data asynchronously in those models/screens. Keep construction free of side effects.

Retain the registry and router at app scope. RouterStack is paired with that registry; don't pass a router from a different registry. It constructs the root automatically and injects Router through SwiftUI environment.

```swift
@Environment(Router.self) private var router
// In a button action:
try router.navigate(to: "/inspections/123")
```

The default canonical mode sets Dashboard → Inspections → Details. Explicit `mode: .push` appends only the matched destination, preserving current history. Back/swipe-back truncates the bound path. `router.back()` and `popToRoot()` support programmatic back navigation.

Root is not included in `router.path`. Every non-root registration must reach the root through explicit parent links. A URL segment is not automatically treated as a screen. Parent parameters must also exist in the leaf route.

## Deep links

```swift
let links = DeepLinkConfiguration(
    customScheme: "fieldops",
    universalLinkHosts: ["your-real-domain.example"]
)
// Attach outside the authenticated branch so cold/signed-out links are received:
.onOpenURL { url in
    router.open(url, configuration: links)
}
```

Both `fieldops://inspections/123` and `fieldops:///inspections/123` resolve to `/inspections/123`. HTTPS requires an allowed host. Register your scheme in target Info → URL Types. Universal Links additionally require Associated Domains and a valid server AASA file; the package cannot configure those for you.

No per-screen deep-link parser is required: the registration is the mapping. Paths are case-sensitive. Queries/fragments, repeated slashes, trailing slashes, dot segments, encoded slashes, credentials, ports, and control characters are rejected. Percent decoding happens once. Use `RoutePath.encodeSegment(id)` when building dynamic path strings. Do not concatenate unescaped IDs.

Unknown links return false without changing stack; `lastError` provides diagnostic context. Throwing `navigate` lets callers choose app-specific error UI.

## Authentication

Router defaults to `.restoring`. It does not own credentials, networking, or session restoration. All routes default to protected. A protected request while restoring/signed out is retained (latest wins).

- Restoration finds a valid session: `setAuthentication(.signedIn)`.
- Restoration needs login: `setAuthentication(.signedOut)` preserves the pending link.
- Login succeeds and saves session: `setAuthentication(.signedIn)` resumes that link.
- Actual logout: `resetForSignOut()` discards history and pending links.

Your existing AppCoordinator still switches loading/login/dashboard. Make router authentication updates in the same coordinator transition methods. `needsSignIn` can signal a login requirement; the host decides how to show login. Do not mount a protected root while signed out. Server authorization must validate every protected operation regardless of route metadata.

Keep restoration task lifetime app-owned and prevent stale restoration/login/refresh results overriding later logout. The router's synchronous state transitions do not solve async auth races for the host.

## Validation and scope

Registration rejects duplicates/equivalent patterns, missing parents, parent cycles, and unbound parent parameters. Literal segments take precedence by number of literal matches; equally specific overlapping matches throw ambiguity. Parameter validation failure does not fall through to a different route.

V1 is a single push stack, not sheets, tabs, persisted navigation, wildcard paths, query-parameter routes, async data guards, or automatic profile/data fetching. AnyView is used only at the heterogeneous screen registry boundary.

Core tests cover canonical hierarchy, static precedence, invalid input/parameters, registration errors, ambiguous routes, and trusted deep links. UI/state tests and interactive back/auth handoff should be run on Apple tooling; see VALIDATION.md.

## Existing FieldOps migration

1. Add local package and retain one ScreenRegistry/Router in composition.
2. Register Dashboard, Account and available inspection screens with existing factories.
3. Replace the signed-in NavigationStack/destination switch with RouterStack.
4. Replace SignedRoute parsing and coordinator path updates with router.navigate/open.
5. Keep AppCoordinator root-flow/session logic; synchronize router auth on each transition.
6. Remove old SignedRoute/parser only after testing both entry points.

See Examples/FieldOpsIntegration.swift for dependency and callback placement.

## Feature-owned registration

ScreenRoute(definition:destination:) accepts an existing RouteDefinition. A host may create its Router from feature-owned metadata first, create the session coordinator using that router, then assemble screen builders with injected coordinator callbacks. Build the router and screen registry from the same feature definitions. This supports callback injection without mutable callback holders or feature dependencies on an app coordinator.
