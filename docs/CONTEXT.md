# Persistent project context

Updated: 2026-10-15

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
