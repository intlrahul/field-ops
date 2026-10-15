import { inspectionStore } from './inspections/store.js';
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
    const store = inspectionStore(db);
    const actor = { id: '',role: 'supervisor' as const };
    const existingAsset = db.prepare("SELECT id FROM assets WHERE asset_tag = 'DEMO-PUMP-001'").get() as { id: string } | undefined;
    const timestamp = new Date().toISOString();
    const asset = existingAsset ? store.getAsset(existingAsset.id,actor)!
      : store.createAsset({ assetTag: 'DEMO-PUMP-001',name: 'Demo cooling pump',location: 'Plant A' },timestamp);
    const assigned = db.prepare("SELECT id FROM users WHERE email = 'technician@fieldops.test' AND role = 'technician' AND active = 1")
      .get() as { id: string } | undefined;
    const existingInspection = db.prepare('SELECT id FROM inspections WHERE asset_id = ? LIMIT 1').get(asset.id);
    if (assigned && !existingInspection) {
      store.createInspection({ assetId: asset.id,assigneeId: assigned.id,title: 'Demo pump safety inspection',
        checklistItems: [{ label: 'Inspect housing for cracks',required: true }],
        readingDefinitions: [{ label: 'Temperature',unit: '°C',required: true,minValue: 0,maxValue: 80 }],
      },timestamp);
    }
  }).immediate();
  console.log('Development accounts ready: supervisor@fieldops.test, technician@fieldops.test. Existing accounts unchanged. Demo asset and assigned inspection seeded when absent.');
} finally { db.close(); }
