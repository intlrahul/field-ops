# ADR 0002: Device sessions with strict refresh rotation

Status: accepted for authentication slice, 2026-10-15.

Use Argon2id through node-argon2 for passwords, jose for HS256 access tokens (15 minutes), and 32-byte random refresh tokens stored only as SHA-256 hashes. A session has a fixed 30-day deadline. The signing secret is configured externally; startup rejects missing/short secrets.

Each login creates a session. Refresh consumes its token and inserts a replacement hash atomically. Retain consumed hashes: reuse revokes that device session without affecting others. This strict policy deliberately sacrifices retry convenience: a lost response or concurrent refresh can require signing in again. Client refresh requests must be serialized. Grace periods are not implemented.

Protected requests check current session state, account activity, and role in SQLite, making logout and deactivation immediate. JWT validation alone cannot provide immediate revocation. This adds a database lookup and makes authenticated requests dependent on database availability, an acceptable trade-off for the single-instance learning product.

No public signup. Seeded development credentials come from ignored environment configuration; repeated seeding preserves accounts. Local loopback HTTP remains for development, HTTPS and Docker are deferred. Offline access policy is independent and unresolved. See ../AUTHENTICATION.md for detailed behavior and deferred operations.
