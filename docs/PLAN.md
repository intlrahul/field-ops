# Incremental delivery plan

1. Foundation (implemented): persistent context, runnable server, SQLite migrations, health contract, isolated integration tests, type checking, linting, build, CI.
2. Authentication contract and implementation (implemented; see AUTHENTICATION.md): seeded accounts, password hashing, login, rotating/revocable sessions, logout, rate limiting, authorization tests. Agree contract before coding.
3. Assets and assigned inspections (implemented; ASSETS_INSPECTIONS.md): asset and inspection creation/list/details, scoped authorization, frozen definitions and asset snapshots, cursor pagination, demo seed, and migration from existing auth databases.
4. Inspection work (implemented; INSPECTION_WORKFLOW.md): assigned-technician start, checklist results, readings with internal history, append-only notes, atomic completion, state/permission/rule tests.
5. Synchronization (TODO — deferred at user request; see SYNC_TODO.md): operation IDs, retry safety, concurrency versions, incremental cursor, tombstones and explicit conflict resolution.
6. Reliability and portfolio polish: extend CI, operational documentation, honest limitations, review examples.

For each slice: explain scope, agree unresolved product choices, update OpenAPI/examples, implement only that slice, verify meaningful behavior, update context.

Foundation acceptance: npm ci then npm run check succeeds without Docker; health checks a migrated SQLite database; persistence survives reconnect; tests prove separate databases and foreign-key enforcement; startup/shutdown cleanly release resources. No domain schema until its rules are agreed.

Authentication acceptance verified: 15 tests pass across foundation, authentication, seed CLI, and OpenAPI validation. Strict type checking, linting, and production build pass. API tests run through Fastify injection with real isolated SQLite files; no Docker is required. Role/resource restrictions for asset and assigned-inspection reads/creation are now implemented; workflow mutation permissions are now enforced for assigned technicians.

Assets/inspections acceptance verified: npm run check passes with 27 tests, including access boundaries, atomic nested creation/rollback, immutable snapshots, stable pagination, cursor scope/forgery checks, strict validation, migration preservation, and repeatable demo seeding.

Workflow acceptance verified: npm run check passes with 56 tests, strict type checking, linting, and production build. See INSPECTION_WORKFLOW.md for API behavior, manual testing, and concurrency/retry limits. The online workflow is complete for the agreed initial scope. Synchronization contract design is deferred at the user’s request; resume only when requested.
