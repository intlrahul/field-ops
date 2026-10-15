import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { expect, test } from 'vitest';
import { openDatabase } from '../src/db/database.js';
import { verifyPassword } from '../src/auth/password.js';

test('development seed persists hashed accounts and reruns without resetting them', async () => {
  const dir = mkdtempSync(join(tmpdir(),'fieldops-seed-'));
  const path = join(dir,'seed.sqlite');
  const seed = (password: string) => execFileSync(process.execPath,['--import','tsx','src/seed.ts'],{
    cwd: new URL('..',import.meta.url),
    env: { ...process.env, NODE_ENV: 'test', DATABASE_PATH: path,
      SEED_SUPERVISOR_PASSWORD: password, SEED_TECHNICIAN_PASSWORD: password },
    stdio: 'pipe',
  });
  try {
    seed('original-test-password');
    seed('replacement-test-password');
    const db = openDatabase(path);
    try {
      const users = db.prepare('SELECT email,role,password_hash FROM users ORDER BY role').all() as {
        email: string; role: string; password_hash: string;
      }[];
      expect(users.map(u => u.role)).toEqual(['supervisor','technician']);
      for (const user of users) {
        expect(user.email).toBe(`${user.role}@fieldops.test`);
        expect(user.password_hash).toMatch(/^\$argon2id\$/);
        expect(await verifyPassword(user.password_hash,'original-test-password')).toBe(true);
        expect(await verifyPassword(user.password_hash,'replacement-test-password')).toBe(false);
      }
    } finally { db.close(); }
    expect(() => seed('short')).toThrow();
  } finally { rmSync(dir,{ recursive: true, force: true }); }
});
