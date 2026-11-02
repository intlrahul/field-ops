# Persistent project context

Updated: 2026-11-02

## Current iOS structure — authoritative

Route additions must follow IOS_NAVIGATION.md and decisions/0005-feature-owned-navigation.md (also enforced by AGENTS.md). FeatureRoute entries live in Features/<Feature>/Navigation; the sole combined feature list is App/Navigation/AppRoutes.swift. AppComposition lives in App/Dependencies. FieldOpsApp and generic AppNavigation do not change for routine route additions. Account constructs its screen/view model directly with explicit dependencies and NavigationActions; AccountFactory/AccountDestination are removed. AuthFactory remains at Features/Auth/AuthFactory.swift. Auth owns User/Session/Credentials under Domain/Entities. This summary supersedes earlier intermediate arrangements recorded below. The user authorized committing the navigation refactor and this convention; publishing is separate.

## Confirmed requirements

FieldOps is a portfolio-quality inspection product and a vehicle for deep learning. The user is an experienced mobile engineer learning SwiftUI, native persistence, concurrency, and synchronization. They write iOS; the assistant designs and implements the backend incrementally.

One organization initially. Supervisors manage assets, assignments, and progress. Technicians access assigned inspections, record checklist results/readings/notes, and complete inspections when requirements are met. Authentication must be real: established password hashing, short-lived access tokens, securely stored rotating refresh tokens, revocation/logout, rate limiting, safe errors, and role/resource authorization. No public self-assignment of supervisor privileges.

SQLite replaces the original PostgreSQL requirement. No Docker dependency. Integration tests use isolated temporary SQLite databases. Database access has clear boundaries without portability frameworks.

Online workflow comes first. Later synchronization must address operation IDs, durable pending operations, idempotency, versions, cursors, tombstones, conflicts, lost responses, retries, out-of-order responses, restarts, concurrent edits, and access revoked while offline. No full sync engine initially. Maps, push notifications, attachments, and complex organization management are deferred.

## Foundation decisions

Node.js 24 LTS, strict TypeScript, Fastify, better-sqlite3 with explicit SQL migrations, Vitest, ESLint. Initial server deployment assumption: one instance and persistent local disk. See decisions/0001-backend-foundation.md.

## Confirmed inspection rules

- A failed checklist result allows completion only with a nonblank explanatory note for that failed item. Keep this explanation attached to the result, distinct from general inspection notes.
- Out-of-range numeric readings are saved and flagged, but block completion. A note cannot override this block. Missing or invalid required readings also block completion.
- Supervisors define checklist items directly per inspection; reusable templates are deferred.
- Completed inspections are read-only for technicians and supervisors. No reopening initially.
- Checklist and reading definitions freeze at inspection creation for all roles.
- Each inspection snapshots assetTag, name, and location at creation; later asset edits do not change these historical details.

See DOMAIN_RULES.md for examples and outstanding design choices. Definition freezing, asset snapshots, and all online workflow mutations/completion rules are implemented. See INSPECTION_WORKFLOW.md.

## Workflow defaults implemented

- One assignee; reassignment endpoints remain deferred.
- Checklist results: unanswered/pass/fail; mandatory means answered.
- Numeric readings have fixed units.
- Explicit assigned → in_progress → completed transitions.
- General inspection notes are append-only with author and server time.
- Only the assigned technician submits work; explicit start required.
- Distinct reading replacements retain internal history, while details expose latest value.
- Version increments and completion validation/state changes are atomic; stale-write rejection is deferred.

## Resume here

Authentication slice now implements login, refresh, logout and /me, plus development seeds. See AUTHENTICATION.md and openapi.yaml. Access lasts 15 minutes; sessions last 30 days without sliding expiry. Strict consumed-refresh-token reuse revokes the device session; a lost refresh response can require login. The user authorized implementation using these proposed defaults. Docker and HTTPS setup are deferred. Offline local access beyond session expiry remains undecided. Assets and assigned-inspection create/list/detail endpoints are implemented. See ASSETS_INSPECTIONS.md and the main openapi.yaml (which includes assets-inspections.openapi.json). Snapshot/definition immutability and field/pagination defaults are implemented. Online workflow APIs are implemented (INSPECTION_WORKFLOW.md and inspection-workflow.openapi.json). Synchronization is TODO and explicitly deferred at the user’s request. Discussion notes and open decisions are in SYNC_TODO.md. Resume its contract design only when requested; do not assume the current endpoints are safe for an offline mutation queue. Confirmed completion rules remain in DOMAIN_RULES.md.

## iOS learning constraints

SwiftUI with modern Observation; feature-first MVVM and Clean Architecture; explicit constructor injection and feature factories. Domain value types, API DTOs, and persistence models remain separate. Swift Testing for unit/integration tests and XCTest for UI tests. Start without iOS persistence, then create separate Core Data and SwiftData branches from the same baseline. Explain Keychain/token-storage expectations without generating iOS code. Occasionally ask the user to explain a key concept and directly correct misunderstandings.

## Foundation verification

npm run check passed: strict type checking, ESLint, four API/database integration tests, and production build. Tests cover healthy/unavailable persistence, persistence after reconnect, isolation, foreign keys, and transaction rollback. A real-port smoke test was blocked by the execution sandbox (listen EPERM); HTTP behavior was verified with Fastify injection. CI is configured but has not run remotely. The nested ios/.git directory was subsequently removed at the user’s explicit request, deleting its local Git history and settings while preserving source files. The full workspace is now initialized on main with origin git@github.com:intlrahul/field-ops.git. The initial foundation commit includes the existing iOS project, backend, documentation, and CI workflow. Publishing to the remote is a separate step.

## Authentication verification

npm run check passes with 15 tests covering API/database behavior, refresh replay and concurrent use, session isolation, access/session expiry, logout, account deactivation/current role, validation/rate limiting, seed persistence and rerun safety, and OpenAPI validation. No iOS files changed. Local credentials belong in ignored backend/.env; backend/.env.example documents required values. The runtime now requires AUTH_SECRET; see AUTHENTICATION.md before starting. The user manually tested the authentication flow and authorized committing this slice. Publishing to the remote remains a separate step.

## Assets and assigned-inspections verification

Implemented six endpoints: POST/GET /assets, GET /assets/{id}, POST/GET /inspections, GET /inspections/{id}. Migration 2 preserves authentication data. Inspection definitions and asset snapshots are fixed at creation; workflow results and completion rules were subsequently implemented in the workflow slice below. Lists enforce resource authorization in SQL before pagination. Seed adds a demo asset/assigned inspection without duplicating data on reruns. Main OpenAPI includes the domain contract module. npm run check passes: 27 tests plus type checking, linting, and production build. Existing local data and .env were not read or changed during implementation/testing; all tests use temporary databases. No iOS changes, commit, or push in this slice.

## Online workflow verification

Implemented POST start/complete, PUT checklist-item result, PUT reading value, and POST notes. Only assigned technicians may mutate in-progress work. Completion validates persisted mandatory answers, explanations for every failed check, and valid/in-range readings in the same transaction as the terminal state/version update. Distinct reading replacements remain in internal history; notes are append-only. Completed inspections reject all workflow mutations. Migration 3 preserves existing accounts, inspection snapshots, and definitions. npm run check passes with 56 tests, including pure business rules, API authorization/state validation, rollback, migration preservation, retry behavior, invalid numeric input, and separate-connection completion/reading interaction. Main OpenAPI and manual walkthrough are updated. Current mutation versions are informational: stale-write rejection, idempotent POST operations, and offline sync remain deferred. iOS, local .env, and development data were untouched. The user authorized committing the assets and online workflow implementation, contracts, tests, and deferred synchronization TODO. Publishing remains a separate step.

## iOS login integration

The user implemented and manually verified login against the backend, then requested a commit. The iOS changes include login DTOs/repository/use case/presentation, session storage boundaries, app dependency injection/navigation, networking/error types, and Alamofire dependency configuration with Package.resolved. The assistant did not generate or modify Swift code for this commit. Verification is the user's successful login test; no iOS build or automated tests were run by the assistant. Local .env remains excluded. Offline synchronization remains explicitly deferred.

## iOS session and account integration — 2026-11-02

User requested committing session restoration/persistence with Keychain storage, refresh/signout use cases, account UI, app loading/navigation/factory changes, and dashboard presentation work. The prefilled login password was cleared before committing with the user’s go-ahead. No iOS build or automated tests were run for this commit; local .env is excluded. Offline synchronization remains deferred.


## PathRouter integration — 2026-11-02

The user explicitly authorized implementing the iOS navigation migration after adding/compiling the local package. AppNavigation retains a single registry/router/stack, with Dashboard at / and Account at /account. The coordinator retains session/root-flow control and updates router authentication on restoration/login/logout. The old SignedRoute, destination switch, path/pending state, and custom parser are removed. Protected links received during loading/login resume after authentication; actual logout clears them. A transition revision guard prevents late restoration results overriding a later UI login/logout transition. The package products are linked and Configuration/Info.plist registers the fieldops scheme. Universal links and inspection-detail routing remain outside this slice. See IOS_NAVIGATION.md for architecture and manual checks. Backend behavior and the sync deferral are unchanged. Changes are not committed.

PathRouter verification: simulator app build succeeded, all 8 package tests passed, and all 4 new AppNavigationTests passed on iPhone 17 (iOS 26.5), including a final run after correcting an explicit module import. The built app's Info.plist contains the fieldops scheme. Interactive gesture and real-screen login/deep-link checks remain manual; see IOS_NAVIGATION.md. No backend changes or tests were needed for this slice.

Account navigation assembly: AccountDestination now lives under Features/Account/Assembly/Navigation, taking AccountFactory and an onSignedOut closure. AppNavigation keeps a small AccountRouteBoundary that adapts the app coordinator to the callback, keeping the feature destination independent of AppCoordinator.


Feature-owned route registration refactor: AccountRoutes and DashboardRoutes own metadata and screen assembly. AccountDestination remains in the Account feature with an injected onSignedOut closure; AccountRouteBoundary has been removed. AppNavigation now only combines an existing router and screen registrations. FieldOpsApp creates route metadata/router, then coordinator, then screen builders with weak coordinator callbacks. PathRouter gained ScreenRoute(definition:destination:) for shared feature metadata. New screens in an existing feature do not require AppNavigation edits. This supersedes the earlier adapter-based arrangement.

Feature-registration verification: rebuilt the app and ran all 4 AppNavigationTests successfully on iPhone 17 / iOS 26.5; all 8 PathRouter package tests also passed. Changes remain uncommitted. Manual screen/gesture checks from IOS_NAVIGATION.md still apply.


App composition refinement: FieldOpsApp now only retains AppComposition and displays its root. App/Dependencies/AppComposition owns dependency construction and a single feature-registration list. Features return FeatureRoute values (Core/Navigation) that pair route definitions with deferred destination builders accepting NavigationActions. Metadata is derived from the same list used to materialize screens after router/coordinator construction. Account sign-out is a weak coordinator callback; features remain independent of AppCoordinator. A new screen changes its feature only; a new feature adds one entry in AppComposition. FieldOpsApp and generic AppNavigation remain unchanged. This supersedes the previous parallel metadata/screen lists in FieldOpsApp.

AppComposition verification: simulator build and all 4 AppNavigationTests passed after the single-registration refactor. No package source changes were needed in this final refinement; the previously verified shared-definition initializer is reused. Manual gesture/login checks remain documented. Changes are uncommitted.

Factory simplification: at the user's request, AccountFactory and its feature-side AppContainer extension were removed. AppComposition supplies SessionProvider and SignoutUseCase directly to AccountRoutes, which forwards them with onSignedOut to AccountDestination. The destination constructs AccountViewModel only as its screen is rendered; AccountScreen retains it in State. AuthFactory is retained because it assembles the repository and shared refresh/restoration use cases as well as login/sign-out dependencies. No blanket factory-per-feature requirement remains.

Factory simplification verification: simulator build and all 4 AppNavigationTests passed. No AccountFactory/accountFactory references remain in iOS source. Changes are uncommitted.

Feature navigation simplification: AccountDestination was removed. AccountRoutes now constructs AccountScreen and its AccountViewModel directly in the deferred route builder, preserving screen State ownership and injected sign-out callbacks. AccountRoutes and DashboardRoutes moved from Features/<Feature>/Assembly/Navigation to Features/<Feature>/Navigation. AuthFactory remains in Auth/Assembly. This supersedes prior AccountDestination/folder descriptions; no app composition changes are needed.

Folder preference: AppComposition.swift now lives beside AppContainer in App/Dependencies. AppNavigation remains in App/Navigation. This is a file move only; composition behavior is unchanged.

Registration-list extraction: App/Navigation/AppRoutes.swift now owns the combined feature registrations. AppComposition calls AppRoutes.registrations(container:) without naming features. New screens change feature routes; new feature registrations change AppRoutes. Shared dependency/lifecycle changes may still require AppComposition edits.

Auth entity ownership: at the user's request, User.swift, Session.swift, and Credentials.swift moved from Core/Domain/Models to Features/Auth/Domain/Entities. Auth owns these domain types; Account and shared session infrastructure intentionally consume them. The app remains a single Swift target, so no import/access-control changes were required. Session storage/persistence and networking remain in Core. File contents and runtime behavior are unchanged.

Navigation convention commit verification: final simulator build and all 4 AppNavigationTests passed after the final folder/entity moves. The 8 package tests passed during this integration. Local credentials/generated output are excluded; the URL-encoding alphabet in PathRouter was checked as a benign credential substring match. Official route authoring is recorded in AGENTS.md, IOS_NAVIGATION.md, ARCHITECTURE.md, and ADR 0005. The user authorized the commit; no push is included.


Sample inspection detail screen: the user requested a minimal demonstration of adding a screen, without APIs. Features/Inspections now contains a read-only InspectionDetailsScreen and InspectionRoutes (/inspections/:id, parent /), reusing existing Dashboard Inspection.samples. AppRoutes adds the feature once; Dashboard rows navigate by encoded ID. Unknown sample IDs show an unavailable state. FieldOpsApp, AppComposition, AppNavigation, and AppCoordinator are unchanged. No factory, destination wrapper, repository, or view model was added. See the worked example in IOS_NAVIGATION.md.

Sample detail verification: simulator build and all 6 AppNavigationTests passed, including the new inspection deep-link/authentication/back-stack and path-encoding/validation tests. Manual row tapping/visual verification remains available in the worked example. Changes are uncommitted; no backend or API changes were made.

Coordinator boundary confirmed: removed .environment(coordinator) from AppRootView. No feature consumes AppCoordinator from the environment. Feature app-flow transitions remain explicit callbacks; Router stays in the environment. Sign-out API/session work remains in AccountViewModel/use cases. This supersedes the earlier discussion about optionally retaining coordinator environment access.

The user authorized committing the sample inspection-detail screen and explicit coordinator boundary. Six navigation tests passed for the sample-screen integration; a subsequent simulator build passed after removing coordinator environment injection. Publishing remains separate.
