# ADR 0005: Feature-owned PathRouter registrations

Status: accepted project convention, 2026-11-02. Supersedes the intermediate coordinator-path, destination-wrapper, and parallel registration-list designs discussed during integration.

## Decision

Use the local PathRouter package for signed-in navigation and deep-link resolution. Each feature owns Features/<Feature>/Navigation/<Feature>Routes.swift, returning FeatureRoute registrations. Each registration pairs metadata (path, parent, authentication requirement, parameter validation) with deferred destination construction exactly once.

App/Navigation/AppRoutes.swift is the sole app-level list of features. Existing-feature screens are added only in their feature registration. A new feature adds one registration entry in AppRoutes. Do not modify FieldOpsApp, AppComposition, or generic AppNavigation for routine screen additions.

App/Dependencies/AppComposition.swift constructs shared dependencies, obtains registrations through AppRoutes, creates the router and coordinator, injects NavigationActions, and materializes screens. This order supports coordinator callbacks without mutable callback holders or circular construction. It may change when a genuine shared dependency or app-level action changes.

Features receive explicit dependencies; they do not access AppContainer or AppCoordinator. AppRoutes is an app composition boundary and may access AppContainer. View models are constructed by deferred route builders and retained by screens in State. AccountRoutes constructs AccountScreen directly; AccountFactory and AccountDestination are unnecessary forwarding layers. AuthFactory remains useful for its repository/refresh/restoration dependency graph; it currently resides at Features/Auth/AuthFactory.swift.

The coordinator owns session/root-flow transitions; PathRouter owns navigation history and pending protected destinations. Root-level URL delivery remains active during restoration/login. Startup without a session preserves pending navigation; successful restoration/login resumes it; actual logout clears it. Backend authorization remains authoritative.

## Consequences

Screen additions stay local to feature navigation files. Explicit feature registration remains visible in one app file. There is no automatic discovery or service locator. Parameterized paths use RoutePath.encodeSegment and registration validation; URL segments do not imply screens unless an explicit parent registration declares them.

PathRouter v1 supports one push stack. Sheets, tabs, universal-link hosting configuration, and inspection-detail screens require separately scoped work. Session persistence races are not solved by routing; the coordinator revision guard only prevents stale UI flow transitions.

See ../IOS_NAVIGATION.md for the required authoring procedure, ownership map, and verification checklist. The user continues to own iOS implementation unless explicitly delegating a change.
