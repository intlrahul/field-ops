# Incremental delivery plan

1. Foundation (implemented): persistent context, runnable server, SQLite migrations, health contract, isolated integration tests, type checking, linting, build, CI.
2. Authentication contract and implementation (implemented; see AUTHENTICATION.md): seeded accounts, password hashing, login, rotating/revocable sessions, logout, rate limiting, authorization tests. Agree contract before coding.
3. Assets and assigned inspections: agree domain defaults, list/details contract, role and resource access, pagination.
4. Inspection work: start, checklist, readings, notes, atomic completion, rule tests. Agree edits and completion rules first.
5. Synchronization: operation IDs, retry safety, concurrency versions, incremental cursor, tombstones and explicit conflict resolution.
6. Reliability and portfolio polish: extend CI, operational documentation, honest limitations, review examples.

For each slice: explain scope, agree unresolved product choices, update OpenAPI/examples, implement only that slice, verify meaningful behavior, update context.

Foundation acceptance: npm ci then npm run check succeeds without Docker; health checks a migrated SQLite database; persistence survives reconnect; tests prove separate databases and foreign-key enforcement; startup/shutdown cleanly release resources. No domain schema until its rules are agreed.

Authentication acceptance verified: 15 tests pass across foundation, authentication, seed CLI, and OpenAPI validation. Strict type checking, linting, and production build pass. API tests run through Fastify injection with real isolated SQLite files; no Docker is required. Role/resource restrictions for domain operations remain in their future slices.
