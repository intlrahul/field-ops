# Backend architecture

HTTP handlers validate transport data and map responses. Application operations will own authorization, state transitions, and transaction boundaries. Focused persistence modules own SQL; pure domain rules remain independently testable. Create each layer when the feature needs it, without empty framework scaffolding.

The app factory receives its database connection and does not listen on a port. The executable owns connection creation, migrations, listening, and shutdown. This allows HTTP integration tests to exercise real handlers and SQLite through Fastify injection without binding a port.

SQLite uses foreign keys, WAL, and a bounded busy timeout. Keep write transactions short and synchronous; do not perform network requests in transactions. WAL permits concurrent readers but still only one writer. Migrations are ordered, append-only SQL changes recorded transactionally in schema_migrations. Never edit an applied migration; add a new one.

Development uses a durable local file. Tests create private temporary directories, apply the same migrations, and close connections before deleting database files and sidecars. No mocked persistence for integration tests. Later concurrency tests will use independent connections to the same temporary file.

Future domain conventions proposed: UUID IDs, UTC RFC 3339 timestamps, integer server-owned versions, consistent error envelopes, and bounded cursor pagination. These need explicit API definitions before domain implementation. SQLite is backend persistence only; iOS persistence remains the user's separate Core Data/SwiftData learning work.

Authentication and business endpoints are not implemented. Password hashing/token libraries, expiry periods, refresh replay policy, offline access revocation, and iOS Keychain storage expectations will be documented in the authentication slice. Password reset/email verification remain deferred until explicitly scoped.
