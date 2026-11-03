# Persistent project context

Updated: 2026-11-02

## Current backend authorization — authoritative

Capability authorization is implemented with the agreed defaults: two static role groups, one organization per user, both roles granted inspections.perform for their own assignments only, and templates.manage reserved/not advertised while template APIs remain deferred. See AUTHORIZATION.md and ADR 0007. Migration 4 preserves existing data in the default FieldOps organization; no local database was migrated during implementation/testing. Login/refresh/me retain role and add roles, organizationId, capabilities. Full inspection responses add allowedActions and completionBlockers, generated through the same policies and completion rules that enforce writes. All read/list/statistics scope is organization-bound; technicians see own assignments and linked assets, supervisors their organization. Mutations re-read permissions and session state inside transactions. Supervisor assignees are now eligible; completed work remains read-only. Existing asset tags remain globally unique. No iOS files changed by this task; the existing local login prefill remains untouched. Templates, permission-management UI, multi-membership, and offline sync are deferred.

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

Sign-out request correction: debugging a reported sign-out error found that RemoteAuthRepository sent an access token in a refreshToken JSON body with requiresAuthentication=false, while APIClient ignored authentication flags. The backend requires a bodyless POST /auth/logout with Authorization: Bearer accessToken. AuthRepository.signOut now takes no token argument; the API client adds bearer headers for authenticated GET/POST calls and supports bodyless empty-response POSTs. Sign-out clears local state only after server success; callbacks/navigation are unchanged. An injectable Alamofire session supports URLProtocol transport tests without real credentials/network calls. Automatic access-token refresh is not added by this fix; expired/revoked credentials remain server rejections under the existing contract.

Sign-out verification: simulator build and all 11 FieldOps unit/integration tests passed (6 navigation, 4 logout/transport, 1 existing placeholder). Transport tests verify bearer/no-body logout, empty 204 success, unauthorized rejection preserving local credentials, public-request header omission, and missing-token rejection. The live backend was not called. Changes remain uncommitted.

Verification preference: the user will run the simulator and simulator tests. Do not launch or execute them unless the user explicitly changes this instruction. Earlier sign-out test results predate this preference; no simulator checks were rerun for this commit. The user requested committing the sign-out request correction, transport tests, and documentation; no push is included.

## Design system — 2026-11-02

User explicitly requested shared components, typography, theme, color scheme, and foundations. Core/DesignSystem now contains semantic typography/layout/motion tokens, DSTheme/DSColors, shared content/control/layout/state components, and DesignSystemCatalog previews. Eighteen color assets have light/dark/increased-contrast variants. FieldOpsApp applies the default teal/system-following theme once. Login, Account, Dashboard/summary/rows, inspection details, and loading were migrated without changing auth/navigation/business logic. Dashboard summary now derives counts from the actual local samples. No API calls were added. docs/DESIGN_SYSTEM.md, ADR 0006, and AGENTS.md establish the styling convention. A non-simulator script checks 60 contrast pairs and asset variants. Generic iOS device build passed; no simulator, simulator tests, previews, or visual QA were run. User must review Dynamic Type, appearance, VoiceOver, and real interaction using the catalog/manual checklist. Changes are uncommitted.


Prism extraction: the user requested a local Swift package named Prism. The shared design-system source and assets now live in ios/local_dependencies/Prism/Sources/Prism, with an iOS 17+ Swift-tools-6.0 manifest, public component initializers, and no FieldOps/third-party dependencies. The app links the Prism product and imports it at UI call sites. Colors resolve via Bundle.module from processed package resources; native app AccentColor remains app-owned. DS-prefixed component names are retained; the default preset is now DSTheme.prism and the gallery is PrismCatalog. The contrast-check script follows the package asset path. This supersedes the former app-local Core/DesignSystem arrangement.

Prism verification: final generic iOS device build succeeded with the app consuming Prism as a separate module. Prism_Prism.bundle is present in the built app, all 18 color assets/four variants and 60 contrast pairs pass the non-simulator script, and no duplicate app-local design-system folder remains. No simulator, simulator tests, or preview rendering was run. Changes are uncommitted.

Loading visual preference: restored the original checklist/scanning-line illustration inside Prism as public DSLoadingIndicator, consumed by DSLoadingState/AppLoadingScreen and the catalog. It uses semantic theme colors; Reduce Motion removes the moving scan, and the timeline pauses while inactive. Button loading remains native. This supersedes the earlier removal of the scan illustration.

Loading backdrop: Prism's DSLoadingBackground now gives DSLoadingState/AppLoadingScreen static teal/blue corner glows and a faint dot grid, fading out behind the central content. Increase Contrast and Reduce Transparency use a plain canvas. The checklist scan remains unchanged. Generic-device compilation verifies integration; visual verification remains with the user, without simulator execution.

Branding: added Prism DSWordmark with a custom vector F/check monogram and rounded heavy Field/Ops lettering using semantic text/accent colors. App Core/Branding/FieldOpsLogo centralizes the name and compact configuration. App loading, login, and dashboard navigation share it. DSLoadingState accepts a custom heading without removing its title-string initializer. No simulator execution; user owns visual review.

Loading backdrop refinement: user reported the original glows looked unchanged. Increased their visibility and added a full semantic surface gradient plus corner contour rings. The center stays quiet; Increase Contrast/Reduce Transparency still use plain canvas. This changes the SwiftUI restoration screen, not the system launch screen.

Login artwork: added Prism DSWelcomeIllustration, a scalable vector checklist/compass composition, above login. Artwork expands to readable width on iPad while form controls remain bounded to formWidth. Interpreted “all screens” as all screen sizes, not every feature page. User owns visual device verification.

Button sizing correction: DSActionStyle now applies content padding before its 52-point minimum-height frame. Previously the padding was outside that frame, producing a minimum 68-point button. All button variants now share the intended 52-point minimum while allowing wrapped/Dynamic Type content to expand.

## iOS inspection reads — current

User authorized inspection API integration. Dashboard and details now use authenticated remote reads with explicit repository injection through AppContainer/AppRoutes/feature registrations. Inspections owns the shared domain model; sample data is restricted to explicitly injected preview/test dependencies. List supports cursor pagination, loaded-only summary counts, refresh, loading/empty/retry/error states; details independently fetch UUIDs and display checklist/results, readings/bounds, and notes read-only. APIClient GET now preserves query encoding and backend error messages. No workflow mutations, auto-refresh-on-401, persistence, or sync added. See IOS_INSPECTIONS.md. App and test targets compile for generic iOS; tests were not executed and simulator was not launched. User separately authorized adding/compiling focused tests after automatic review initially required explicit test permission. Existing local password prefill remains untouched/uncommitted.

Development seed expanded from one pump inspection to five asset/inspection examples for the seeded technician. Added generator, HVAC, fire safety, and compressor assignments with checklists/readings and varied due dates. Reruns skip demo assets that already have inspections and preserve all existing work/accounts. Integration tests still use temporary SQLite databases; local seeding is an explicit user-requested data operation.

## Authorized dashboard statistics

Implemented authenticated GET /inspections/statistics returning total, assigned, inProgress, completed. One aggregate SQL statement uses the same actor scope as list/detail: technician assignments only, supervisor all. No filters/query parameters, no pagination, zero-filled empty results, Cache-Control no-store. Separate list/statistics requests are not a shared snapshot. OpenAPI and API guide updated; isolated SQLite/API tests prove pagination independence (>20 records), role isolation, empty/auth cases, invalid query rejection, and updates through real start/complete endpoints. npm run check passes with 59 tests, lint, typecheck, build. Backend-only slice: iOS consumption remains pending and currently counts loaded rows. No migration or local development database change needed.

Development data expanded to 50 demo inspections: ten units each of pump, generator, HVAC, fire safety, and compressor. Stable DEMO equipment tags (001–010) make reruns skip existing work; all newly created inspections are assigned to the seeded technician. Fresh data spans three 20-item pages. Seed integration test verifies 50 records remain after rerun.

Mixed demo statuses: user requested in-progress and completed examples. Seed now advances only untouched matching demo inspections (assigned, version 1, no saved work) through workflowService. Fresh distribution: 20 assigned, 15 in_progress with partial checks, 15 completed with all passing checks/in-range readings and synthetic notes. Existing work and completed inspections remain unchanged; rerun tests verify versions/history do not duplicate. This supersedes the prior all-assigned seed description.

Swift statistics integration: DashboardSummaryView now renders server total/assigned/inProgress/completed via InspectionRepository.statistics and separate DTO/domain types. InspectionListViewModel refreshes list and totals concurrently; statistics have separate loading/error/retry state and no list-count fallback. Pagination does not change totals. This supersedes earlier loaded-only count descriptions. Focused statistics tests added under the existing authorization to add/compile inspection tests only; no simulator or test execution.

Progressive loading: Prism DSSkeleton supplies card/statistics shimmer placeholders used by dashboard sections and inspection details. Initial placeholders appear before task scheduling and disappear per-region as content/errors arrive; list and totals already load concurrently and publish independently. Existing content stays visible during refresh. Details remain one response, so all detail content appears together. Reduce Motion/Reduce Transparency use static placeholders and inactive scenes pause animation. Session restoration remains separate because access must resolve before protected screens render. No simulator execution.

Statistics cards now filter the dashboard inspection list in place. Repository list accepts optional InspectionStatus and encodes status.rawValue in the query. Total clears filtering; status changes reset rows/cursor and show skeletons, with a revision guard against stale responses. Refresh/retry/pagination preserve status; statistics stay overall. Prism DSStatGrid supports optional selection/actions with a visible outline and accessibility trait. No route changes. Generic-device app/test compilation only; no simulator or test execution.

Checklist loading reused across app: Prism DSLoadingIndicator has launch144/refresh48/compact28 sizes, with simplified compact artwork. DSButton replaces its native spinner; DSLoadingRow supplies labelled inline feedback. DSScreen accepts optional onRefresh and renders the scanner during pull/refresh with a view-owned async task and accessibility Refresh action; Dashboard and detail replace .refreshable with it. Initial skeleton loading and progressive content remain. Generic-device build only; gesture/accessibility checks remain user-owned.

Inspection data organization: DTOs and their toDomain mappings now live in Features/Inspections/Data/Models (including shared inspection date parsing). RemoteInspectionRepository lives in Data/Repositories and only coordinates requests, ID validation, and mapping calls. Page/statistics mapping moved beside their DTOs. API and domain behavior are unchanged; matches the Auth feature's organization.

Inspection use-case layer added at user request: GetInspectionsUseCase, GetInspectionDetailsUseCase, GetInspectionStatisticsUseCase protocols and Default implementations live in Domain/UseCases. AppRoutes supplies use cases to feature registrations; view models no longer reference InspectionRepository. Repository ownership in AppContainer remains unchanged. Preview/test constructors updated; behavior remains unchanged. Generic-device app/test build succeeded, without test execution or simulator launch.

Refresh regression fix: user reported dashboard pull-to-refresh missing. Removed custom offset preference/drag threshold from DSScreen and restored native .refreshable internally. Kept onRefresh API, in-content checklist animation, short-content bounce, concurrent-refresh guard, and named accessibility action. System pull indicator remains native for reliable gesture behavior. Supersedes prior custom gesture documentation. Generic-device compile only; physical gesture verification remains user-owned.

Statistics-card navigation corrected to user intent: cards now push a separate InspectionListScreen instead of filtering Dashboard. Feature route /inspection-lists/:status accepts all/assigned/in_progress/completed with Dashboard parent; list starts with its own immutable initial status and fetches pages only, retaining status on refresh/retry/pagination. Details push above the list; Dashboard state stays unfiltered. Existing detail deep links unchanged. This supersedes in-place filter behavior. App/test compilation succeeded; no simulator or test execution.

Authorization verification: npm run check passes with 70 tests using isolated temporary SQLite databases, plus strict type checking, lint, production build, and OpenAPI reference validation. Tests include migration history/session preservation, action/enforcement agreement for both roles, organization isolation, scoped statistics/assets/cursors, escalation input rejection, current-token role changes, deactivation/revocation and stale-service-actor checks. No commit or push performed.

Frontend capability support follows backend commit 8e6580d. UserDTO/User preserve raw roles, organizationId and capabilities with backward-compatible cached-user decoding (missing permissions deny; roles do not infer grants). AuthRepository and GetCurrentUserUseCase fetch /me for dashboard/list visibility on reads and refresh; explicit route injection is retained. Missing/revoked permissions hide and clear inspection content; scope/identity changes invalidate pagination and totals, and old request responses are discarded. Inspection details retain raw allowedActions/completionBlockers and expose safe known-action checks with read-only messaging; forms remain pending. /me is not persisted over session credentials; login/refresh update cached metadata naturally. Frontend app/test compilation succeeds only (no tests/simulator execution). Existing local password prefill untouched. Frontend changes remain uncommitted.
