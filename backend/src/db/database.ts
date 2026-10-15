import Database from 'better-sqlite3';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

export type SqliteDatabase = Database.Database;

export function openDatabase(path: string): SqliteDatabase {
  mkdirSync(dirname(path), { recursive: true });
  const db = new Database(path);
  try {
    db.pragma('foreign_keys = ON');
    db.pragma('journal_mode = WAL');
    db.pragma('busy_timeout = 5000');
    return db;
  } catch (error) {
    db.close();
    throw error;
  }
}

// Add domain migrations only after their business rules and contracts are agreed.
const migrations: readonly { version: number; sql: string }[] = [];

export function migrate(db: SqliteDatabase): void {
  db.transaction(() => {
    db.exec(`CREATE TABLE IF NOT EXISTS schema_migrations (
      version INTEGER PRIMARY KEY,
      applied_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
    ) STRICT`);
    const current = db.prepare('SELECT MAX(version) AS version FROM schema_migrations')
      .get() as { version: number | null };
    const latest = migrations.at(-1)?.version ?? 0;
    if ((current.version ?? 0) > latest) {
      throw new Error('Database schema is newer than this application');
    }
    for (const migration of migrations) {
      if (migration.version > (current.version ?? 0)) {
        db.exec(migration.sql);
        db.prepare('INSERT INTO schema_migrations (version) VALUES (?)').run(migration.version);
      }
    }
  }).immediate();
}
