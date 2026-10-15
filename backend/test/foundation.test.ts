import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, expect, test } from 'vitest';
import { buildApp } from '../src/app.js';
import { migrate, openDatabase } from '../src/db/database.js';

const cleanup: (() => void | Promise<void>)[] = [];
afterEach(async () => {
  for (const dispose of cleanup.splice(0).reverse()) await dispose();
});

function database() {
  const directory = mkdtempSync(join(tmpdir(), 'fieldops-test-'));
  cleanup.push(() => rmSync(directory, { recursive: true, force: true }));
  const path = join(directory, 'test.sqlite');
  const db = openDatabase(path);
  cleanup.push(() => { if (db.open) db.close(); });
  migrate(db);
  return { db, path };
}

test('health exercises a migrated database through HTTP', async () => {
  const { db } = database();
  const app = buildApp(db);
  cleanup.push(() => app.close());
  const response = await app.inject({ method: 'GET', url: '/health' });
  expect(response.statusCode).toBe(200);
  expect(response.json()).toEqual({ status: 'ok' });
});

test('health returns a safe unavailable response when persistence fails', async () => {
  const { db } = database();
  const app = buildApp(db);
  cleanup.push(() => app.close());
  db.close();
  const response = await app.inject({ method: 'GET', url: '/health' });
  expect(response.statusCode).toBe(503);
  expect(response.json()).toEqual({
    error: { code: 'SERVICE_UNAVAILABLE', message: 'Service temporarily unavailable' },
  });
});

test('data survives reconnect, migration reruns, and databases remain isolated', () => {
  const first = database();
  const second = database();
  first.db.exec('CREATE TABLE probe (value TEXT NOT NULL) STRICT');
  first.db.prepare('INSERT INTO probe VALUES (?)').run('persisted');
  first.db.close();
  const reopened = openDatabase(first.path);
  cleanup.push(() => { reopened.close(); });
  migrate(reopened);
  expect(reopened.prepare('SELECT value FROM probe').get()).toEqual({ value: 'persisted' });
  expect(second.db.prepare("SELECT name FROM sqlite_master WHERE name = 'probe'").get())
    .toBeUndefined();
});

test('connections enforce foreign keys and roll back failed transactions', () => {
  const { db } = database();
  db.exec(`CREATE TABLE parent (id INTEGER PRIMARY KEY) STRICT;
    CREATE TABLE child (parent_id INTEGER REFERENCES parent(id)) STRICT;`);
  expect(() => db.prepare('INSERT INTO child VALUES (42)').run()).toThrow();
  expect(() => db.transaction(() => {
    db.prepare('INSERT INTO parent VALUES (1)').run();
    db.prepare('INSERT INTO child VALUES (42)').run();
  })()).toThrow();
  expect(db.prepare('SELECT * FROM parent').all()).toEqual([]);
});
