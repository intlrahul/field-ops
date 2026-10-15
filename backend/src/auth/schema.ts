export const authSchema = `
CREATE TABLE users (
 id TEXT PRIMARY KEY, email TEXT NOT NULL UNIQUE,
 password_hash TEXT NOT NULL, role TEXT NOT NULL CHECK(role IN ('supervisor','technician')),
 active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0,1))
) STRICT;
CREATE TABLE sessions (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id),
 expires_at INTEGER NOT NULL, revoked_at INTEGER
) STRICT;
CREATE INDEX sessions_user ON sessions(user_id);
CREATE TABLE refresh_tokens (
 hash TEXT PRIMARY KEY, session_id TEXT NOT NULL REFERENCES sessions(id),
 consumed_at INTEGER
) STRICT;
CREATE INDEX refresh_session ON refresh_tokens(session_id);
`;
