import { randomUUID } from 'node:crypto';
import { openDatabase, migrate } from './db/database.js';
import { hashPassword } from './auth/password.js';

if (process.env.NODE_ENV === 'production') throw new Error('Development seeding is disabled in production');
const supervisor = process.env.SEED_SUPERVISOR_PASSWORD;
const technician = process.env.SEED_TECHNICIAN_PASSWORD;
if (!supervisor || !technician || supervisor.length < 12 || technician.length < 12 || supervisor.length > 1024 || technician.length > 1024) {
  throw new Error('Set both SEED_SUPERVISOR_PASSWORD and SEED_TECHNICIAN_PASSWORD to 12–1024 character passwords');
}
const hashes = await Promise.all([hashPassword(supervisor),hashPassword(technician)]);
const db = openDatabase(process.env.DATABASE_PATH ?? 'data/fieldops.sqlite');
try {
  migrate(db);
  db.transaction(() => {
    for (const [index,role] of (['supervisor','technician'] as const).entries()) {
      db.prepare('INSERT INTO users (id,email,password_hash,role) VALUES (?,?,?,?) ON CONFLICT(email) DO NOTHING')
        .run(randomUUID(),`${role}@fieldops.test`,hashes[index]!,role);
    }
  }).immediate();
  console.log('Development accounts ready: supervisor@fieldops.test, technician@fieldops.test. Existing accounts unchanged.');
} finally { db.close(); }
