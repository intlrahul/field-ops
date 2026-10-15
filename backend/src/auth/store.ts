import type { SqliteDatabase } from '../db/database.js';
export type User = { id: string; email: string; password_hash: string; role: 'supervisor' | 'technician'; active: number };
export type SessionUser = User & { session_id: string; expires_at: number; revoked_at: number | null; consumed_at?: number | null };

export function authStore(db: SqliteDatabase) {
  const sessionQuery = `SELECT users.*, sessions.id AS session_id, sessions.expires_at, sessions.revoked_at
    FROM sessions JOIN users ON users.id = sessions.user_id`;
  return {
    userByEmail(email: string) {
      return db.prepare('SELECT * FROM users WHERE email = ?').get(email) as User | undefined;
    },
    createSession(id: string, userId: string, expires: number, hash: string) {
      db.transaction(() => {
        db.prepare('INSERT INTO sessions (id,user_id,expires_at) VALUES (?,?,?)').run(id,userId,expires);
        db.prepare('INSERT INTO refresh_tokens (hash,session_id) VALUES (?,?)').run(hash,id);
      }).immediate();
    },
    session(id: string) {
      return db.prepare(`${sessionQuery} WHERE sessions.id = ?`).get(id) as SessionUser | undefined;
    },
    rotate(oldHash: string, newHash: string, now: number): SessionUser | undefined {
      return db.transaction(() => {
        const row = db.prepare(`${sessionQuery} JOIN refresh_tokens ON refresh_tokens.session_id = sessions.id
          WHERE refresh_tokens.hash = ?`).get(oldHash) as SessionUser | undefined;
        if (!row) return undefined;
        const token = db.prepare('SELECT consumed_at FROM refresh_tokens WHERE hash = ?')
          .get(oldHash) as { consumed_at: number | null };
        if (token.consumed_at !== null) {
          db.prepare('UPDATE sessions SET revoked_at = COALESCE(revoked_at, ?) WHERE id = ?').run(now,row.session_id);
          return undefined;
        }
        if (!row.active || row.revoked_at !== null || row.expires_at <= now) return undefined;
        db.prepare('UPDATE refresh_tokens SET consumed_at = ? WHERE hash = ?').run(now,oldHash);
        db.prepare('INSERT INTO refresh_tokens (hash,session_id) VALUES (?,?)').run(newHash,row.session_id);
        return row;
      }).immediate();
    },
    revoke(id: string, now: number) {
      db.prepare('UPDATE sessions SET revoked_at = COALESCE(revoked_at, ?) WHERE id = ?').run(now,id);
    },
  };
}
