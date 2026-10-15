# Persistent project context

Updated: 2026-10-15

## Confirmed requirements

FieldOps is a portfolio-quality inspection product and a vehicle for deep learning. The user is an experienced mobile engineer learning SwiftUI, native persistence, concurrency, and synchronization. They write iOS; the assistant designs and implements the backend incrementally.

One organization initially. Supervisors manage assets, assignments, and progress. Technicians access assigned inspections, record checklist results/readings/notes, and complete inspections when requirements are met. Authentication must be real: established password hashing, short-lived access tokens, securely stored rotating refresh tokens, revocation/logout, rate limiting, safe errors, and role/resource authorization. No public self-assignment of supervisor privileges.

SQLite replaces the original PostgreSQL requirement. No Docker dependency. Integration tests use isolated temporary SQLite databases. Database access has clear boundaries without portability frameworks.

Online workflow comes first. Later synchronization must address operation IDs, durable pending operations, idempotency, versions, cursors, tombstones, conflicts, lost responses, retries, out-of-order responses, restarts, concurrent edits, and access revoked while offline. No full sync engine initially. Maps, push notifications, attachments, and complex organization management are deferred.

## Foundation decisions

Node.js 24 LTS, strict TypeScript, Fastify, better-sqlite3 with explicit SQL migrations, Vitest, ESLint. Initial server deployment assumption: one instance and persistent local disk. See decisions/0001-backend-foundation.md.

## Proposed product defaults — confirm before domain implementation

- Seeded accounts only initially; supervisor APIs plus seeds support the technician-first UI.
- One assignee; reassignment only before work starts.
- Inspection owns a snapshot of checklist/reading definitions; reusable templates later.
- Checklist results: unanswered/pass/fail; mandatory means answered. A failure may still allow completion.
- Numeric readings with fixed units; invalid data differs from valid measurements outside operating range.
- Explicit assigned → in_progress → completed transitions; completed records read-only.
- Notes append-only with author and server time.

Open: must failed checks require notes or block completion? Are templates required immediately? Can completed inspections reopen? Confirm these before their endpoints or database schema are implemented.

## Resume here

Authentication slice now implements login, refresh, logout and /me, plus development seeds. See AUTHENTICATION.md and openapi.yaml. Access lasts 15 minutes; sessions last 30 days without sliding expiry. Strict consumed-refresh-token reuse revokes the device session; a lost refresh response can require login. The user authorized implementation using these proposed defaults. Docker and HTTPS setup are deferred. Offline local access beyond session expiry remains undecided. Next: confirm inspection domain defaults before assets/assigned-inspection contracts.

## iOS learning constraints

SwiftUI with modern Observation; feature-first MVVM and Clean Architecture; explicit constructor injection and feature factories. Domain value types, API DTOs, and persistence models remain separate. Swift Testing for unit/integration tests and XCTest for UI tests. Start without iOS persistence, then create separate Core Data and SwiftData branches from the same baseline. Explain Keychain/token-storage expectations without generating iOS code. Occasionally ask the user to explain a key concept and directly correct misunderstandings.

## Foundation verification

npm run check passed: strict type checking, ESLint, four API/database integration tests, and production build. Tests cover healthy/unavailable persistence, persistence after reconnect, isolation, foreign keys, and transaction rollback. A real-port smoke test was blocked by the execution sandbox (listen EPERM); HTTP behavior was verified with Fastify injection. CI is configured but has not run remotely. The nested ios/.git directory was subsequently removed at the user’s explicit request, deleting its local Git history and settings while preserving source files. The full workspace is now initialized on main with origin git@github.com:intlrahul/field-ops.git. The initial foundation commit includes the existing iOS project, backend, documentation, and CI workflow. Publishing to the remote is a separate step.

## Authentication verification

npm run check passes with 15 tests covering API/database behavior, refresh replay and concurrent use, session isolation, access/session expiry, logout, account deactivation/current role, validation/rate limiting, seed persistence and rerun safety, and OpenAPI validation. No iOS files changed. Local credentials belong in ignored backend/.env; backend/.env.example documents required values. The runtime now requires AUTH_SECRET; see AUTHENTICATION.md before starting. The user manually tested the authentication flow and authorized committing this slice. Publishing to the remote remains a separate step.
