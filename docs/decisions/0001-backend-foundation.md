# ADR 0001: Minimal SQLite backend foundation

Status: accepted for the foundation slice, 2026-10-15.

Use Node.js 24 LTS, TypeScript, Fastify, better-sqlite3, explicit SQL migrations, Vitest and ESLint. The user's SQLite/no-Docker update supersedes the original PostgreSQL/Compose brief.

Fastify supports schema-based HTTP contracts and injection tests. Explicit SQL makes relational constraints and transactions visible for learning. Focused modules isolate SQL without generic database adapters. Synchronous SQLite access simplifies short local transactions; long-running queries block the event loop, so keep workloads bounded and revisit based on evidence.

Use file-backed temporary databases for integration tests, matching development connection settings and migrations. WAL improves read/write overlap but does not permit multiple simultaneous writers. Initial hosting needs one server and persistent local storage; horizontal scaling and database migration are future decisions, not current abstractions.
