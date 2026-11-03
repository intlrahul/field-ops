# Backend architecture

HTTP handlers validate transport data and map responses. Application operations will own authorization, state transitions, and transaction boundaries. Focused persistence modules own SQL; pure domain rules remain independently testable. Create each layer when the feature needs it, without empty framework scaffolding.

The app factory receives its database connection and does not listen on a port. The executable owns connection creation, migrations, listening, and shutdown. This allows HTTP integration tests to exercise real handlers and SQLite through Fastify injection without binding a port.

SQLite uses foreign keys, WAL, and a bounded busy timeout. Keep write transactions short and synchronous; do not perform network requests in transactions. WAL permits concurrent readers but still only one writer. Migrations are ordered, append-only SQL changes recorded transactionally in schema_migrations. Never edit an applied migration; add a new one.

Development uses a durable local file. Tests create private temporary directories, apply the same migrations, and close connections before deleting database files and sidecars. No mocked persistence for integration tests. Later concurrency tests will use independent connections to the same temporary file.

Implemented domain conventions: UUID IDs, UTC RFC 3339 timestamps, integer server-owned versions, consistent error envelopes, and bounded cursor pagination. Their contracts are defined in openapi.yaml and its domain module. Version fields initialize to 1 and increment with workflow changes; optimistic concurrency for mutations is still deferred. SQLite is backend persistence only; iOS persistence remains the user's separate Core Data/SwiftData learning work.

Authentication uses Argon2id password hashes, jose-signed access tokens, and hashed rotating refresh tokens. HTTP routes call an authentication service, which uses a focused SQL store. Every protected request checks the current database session and user; refresh rotation and replay revocation use immediate transactions. See AUTHENTICATION.md for lifetimes, client expectations, rate limits, and limitations. Asset/inspection routes use a separate service and SQL store. Inspection creation validates an active same-organization eligible performer and snapshots the asset plus ordered definitions in one immediate transaction. List queries apply authorization before keyset pagination; detail reads use a consistent transaction. Cursor scope is checked but is not trusted for authorization. Definition updates have no API or store operation. Workflow services wrap authorization, state checks, pure completion rules, writes, and parent version/timestamp changes in immediate transactions. Reading replacements append internal measurements; detail reads select the latest. Notes append with authenticated author/server time. See INSPECTION_WORKFLOW.md. Offline synchronization, password reset, and email verification remain deferred.


## iOS navigation convention

The official route-registration procedure is docs/IOS_NAVIGATION.md (relative to the project root), with ADR 0005. Features/<Feature>/Navigation owns single FeatureRoute entries pairing metadata and deferred screen construction. App/Navigation/AppRoutes is the sole combined feature list. App/Dependencies/AppComposition owns generic dependency/lifecycle composition; FieldOpsApp and AppNavigation contain no feature-specific registration logic. Features use explicit dependencies and NavigationActions rather than AppContainer/AppCoordinator. User, Session, and Credentials are owned by Features/Auth/Domain/Entities and intentionally consumed by Account and shared session infrastructure. AuthFactory remains; Account's forwarding factory/destination wrapper were removed.

## iOS design system

ios/local_dependencies/Prism/Sources/Prism owns semantic assets/tokens, Dynamic Type typography, theme environment, reusable components, and a preview catalog. Current app screens consume it; feature/domain/navigation responsibilities stay outside it. FieldOpsApp applies the system-following default theme once. Native navigation/dialog surfaces retain platform behavior. See DESIGN_SYSTEM.md and ADR 0006 for required authoring conventions and verification limits. The user handles simulator/visual testing.

## iOS inspection reads

Inspections owns summary/detail domain types and an InspectionRepository boundary shared with Dashboard. RemoteInspectionRepository maps transport DTOs through the authenticated APIClient. AppContainer supplies one repository; feature routes construct State-owned view models with explicit injection. Sample repositories are preview/test-only. The dashboard uses cursor pagination and labels counts as loaded-only; details fetch independently by backend ID. See IOS_INSPECTIONS.md for behavior, test compilation, and manual checks. Workflow writes and offline persistence remain separate work.

Inspection statistics use one scoped aggregate query in inspectionStore, exposed through service and authenticated GET /inspections/statistics. Scope reuses the list/detail authorization predicate; totals do not depend on pagination. Empty results return four integer zeroes. No filters or cached counters are added. Separate list/statistics requests are individually consistent, not a shared snapshot.

Inspection presentation now depends on explicit Domain/UseCases protocols (list, details, statistics), not directly on InspectionRepository. Default use cases delegate domain reads to the repository. AppRoutes composes them and passes them to feature route builders. Loading/filter/pagination presentation state remains in view models.


## Backend authorization policy

src/authorization/policy.ts centrally owns role-to-capability mappings, separate organization/assigned read scope, performer checks, and inspection action policy. Roles group static capabilities; templates.manage is reserved. Supervisors can perform their assignments, not arbitrary organization work. HTTP authenticates current database user/session; immediate mutation transactions re-read both. SQL queries bind organization and scope before pagination/aggregation. Details are presented with actor-specific allowedActions and completionBlockers from the same policy/rules used to authorize writes. Migration 4 backfills existing records into the default organization and adds reference/ownership triggers; prior migrations remain untouched. Asset tags retain their historical global uniqueness. See AUTHORIZATION.md and ADR 0007 for errors, contracts, migration limits and tests.

Frontend authorization uses raw-string permissions in Auth's domain User with known Capability constants for UI checks. GetCurrentUserUseCase reads /me; Dashboard/list require inspections.read independently of role and invalidate cached presentation on scope changes. Inspection details own raw resource action metadata with known InspectionAction constants; action availability comes from the server. No authorization rules are copied from backend role policies into Swift. Legacy sessions decode without grants; no permission-management UI or feature-flag coupling is added.
