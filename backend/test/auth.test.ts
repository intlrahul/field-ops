import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { randomUUID } from 'node:crypto';
import { afterEach, beforeAll, expect, test } from 'vitest';
import { buildApp } from '../src/app.js';
import { migrate, openDatabase } from '../src/db/database.js';
import { hashPassword } from '../src/auth/password.js';

const password = 'test-password-123';
let passwordHash: string;
beforeAll(async () => { passwordHash = await hashPassword(password); });
const cleanup: (() => void | Promise<void>)[] = [];
afterEach(async () => { for (const fn of cleanup.splice(0).reverse()) await fn(); });
function fixture() {
  const dir = mkdtempSync(join(tmpdir(),'fieldops-auth-'));
  cleanup.push(() => rmSync(dir,{ recursive: true, force: true }));
  const db = openDatabase(join(dir,'test.sqlite'));
  cleanup.push(() => { db.close(); });
  migrate(db);
  for (const role of ['technician','supervisor']) {
    db.prepare('INSERT INTO users (id,email,password_hash,role) VALUES (?,?,?,?)')
      .run(randomUUID(),`${role}@fieldops.test`,passwordHash,role);
  }
  let time = Date.UTC(2026,9,15);
  const app = buildApp(db,false,{ secret: 'test-only-secret-with-at-least-32-bytes', now: () => time });
  cleanup.push(() => app.close());
  const login = (email = 'technician@fieldops.test', pass = password) => app.inject({
    method: 'POST', url: '/auth/login', payload: { email, password: pass },
  });
  const refresh = (token: string) => app.inject({ method: 'POST', url: '/auth/refresh', payload: { refreshToken: token } });
  const me = (token: string) => app.inject({ method: 'GET', url: '/me', headers: { authorization: `Bearer ${token}` } });
  return { db, app, login, refresh, me, advance: (seconds: number) => { time += seconds*1000; } };
}

test('both seeded roles can log in; /me exposes no password hash and tokens are stored hashed', async () => {
  const f = fixture();
  for (const role of ['technician','supervisor']) {
    const response = await f.login(`  ${role.toUpperCase()}@fieldops.test  `);
    // Whitespace is normalized by the service, but transport requires a valid email.
    expect(response.statusCode).toBe(400);
    const valid = await f.login(`${role.toUpperCase()}@fieldops.test`);
    expect(valid.statusCode).toBe(200);
    const pair = valid.json();
    const profile = await f.me(pair.accessToken);
    expect(profile.statusCode).toBe(200);
    expect(profile.json()).toEqual(pair.user);
    expect(profile.json()).not.toHaveProperty('password_hash');
    expect(valid.headers['cache-control']).toBe('no-store');
    const rows = f.db.prepare('SELECT hash FROM refresh_tokens').all();
    expect(JSON.stringify(rows)).not.toContain(pair.refreshToken);
  }
});

test('unknown user, wrong password, and disabled user get the same response', async () => {
  const f = fixture();
  const wrong = await f.login(undefined,'wrong');
  const unknown = await f.login('unknown@fieldops.test');
  f.db.prepare('UPDATE users SET active = 0').run();
  const disabled = await f.login();
  for (const response of [wrong,unknown,disabled]) {
    expect(response.statusCode).toBe(401);
    expect(response.json()).toEqual({ error: { code: 'INVALID_CREDENTIALS', message: 'Invalid email or password' } });
  }
});

test('rotation, replay revocation, and independent device sessions', async () => {
  const f = fixture();
  const first = (await f.login()).json();
  const other = (await f.login()).json();
  const rotated = await f.refresh(first.refreshToken);
  expect(rotated.statusCode).toBe(200);
  expect(rotated.json().refreshToken).not.toBe(first.refreshToken);
  expect((await f.refresh(first.refreshToken)).statusCode).toBe(401);
  expect((await f.refresh(rotated.json().refreshToken)).statusCode).toBe(401);
  expect((await f.me(first.accessToken)).statusCode).toBe(401);
  expect((await f.me(other.accessToken)).statusCode).toBe(200);
});

test('concurrent refresh use yields one success and revokes that session', async () => {
  const f = fixture();
  const pair = (await f.login()).json();
  const results = await Promise.all([f.refresh(pair.refreshToken),f.refresh(pair.refreshToken)]);
  expect(results.map(r => r.statusCode).sort()).toEqual([200,401]);
  expect((await f.me(pair.accessToken)).statusCode).toBe(401);
});

test('logout revokes access and refresh; anonymous and tampered tokens are rejected', async () => {
  const f = fixture();
  const pair = (await f.login()).json();
  expect((await f.app.inject({ method: 'GET',url: '/me' })).statusCode).toBe(401);
  expect((await f.me(`x${pair.accessToken}`)).statusCode).toBe(401);
  expect((await f.app.inject({ method: 'POST', url: '/auth/logout', headers: { authorization: `Bearer ${pair.accessToken}` } })).statusCode).toBe(204);
  expect((await f.me(pair.accessToken)).statusCode).toBe(401);
  expect((await f.refresh(pair.refreshToken)).statusCode).toBe(401);
});

test('access expiry, fixed session deadline, and deactivation are enforced', async () => {
  const f = fixture();
  const pair = (await f.login()).json();
  f.advance(900);
  expect((await f.me(pair.accessToken)).statusCode).toBe(401);
  const renewed = (await f.refresh(pair.refreshToken)).json();
  expect(renewed.sessionExpiresAt).toBe(pair.sessionExpiresAt);
  expect((await f.me(renewed.accessToken)).statusCode).toBe(200);
  f.advance(30*24*3600);
  expect((await f.refresh(renewed.refreshToken)).statusCode).toBe(401);
  const current = (await f.login()).json();
  f.db.prepare('UPDATE users SET active = 0').run();
  expect((await f.me(current.accessToken)).statusCode).toBe(401);
  expect((await f.refresh(current.refreshToken)).statusCode).toBe(401);
});

test('role injection and malformed bodies fail; login attempts are rate limited', async () => {
  const f = fixture();
  expect((await f.app.inject({ method: 'POST',url: '/auth/login',payload: {
    email: 'technician@fieldops.test',password,role: 'supervisor',
  } })).statusCode).toBe(400);
  expect((await f.refresh('bad')).statusCode).toBe(400);
  for (let i = 0; i < 5; i++) await f.login(undefined,'wrong');
  const response = await f.login();
  expect(response.statusCode).toBe(429);
  expect(response.json().error.code).toBe('RATE_LIMITED');
  expect(response.headers['retry-after']).toBeDefined();
});

test('current database role is returned instead of a stale role claim', async () => {
  const f = fixture();
  const pair = (await f.login()).json();
  f.db.prepare("UPDATE users SET role = 'supervisor' WHERE email = 'technician@fieldops.test'").run();
  expect((await f.me(pair.accessToken)).json().role).toBe('supervisor');
});

test('unknown refresh tokens and missing logout credentials are rejected', async () => {
  const f = fixture();
  expect((await f.refresh('a'.repeat(43))).statusCode).toBe(401);
  expect((await f.app.inject({ method: 'POST', url: '/auth/logout' })).statusCode).toBe(401);
});
