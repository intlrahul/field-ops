import { workflowService } from './inspections/workflow-service.js';
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
    const workflow = workflowService(db);
    const actor = { id: '',role: 'supervisor' as const };
    const timestamp = new Date().toISOString();
    const assigned = db.prepare("SELECT id FROM users WHERE email = 'technician@fieldops.test' AND role = 'technician' AND active = 1")
      .get() as { id: string } | undefined;
    const examples = [
      { tag: 'DEMO-PUMP-001',name: 'Demo cooling pump',location: 'Plant A',title: 'Demo pump safety inspection',
        days: null,checks: ['Inspect housing for cracks','Check pipe connections'],reading: 'Temperature',unit: '°C',min: 0,max: 80 },
      { tag: 'DEMO-GEN-001',name: 'Standby generator',location: 'Utility building',title: 'Weekly generator readiness check',
        days: 1,checks: ['Inspect fuel lines for leaks','Verify emergency stop operation'],reading: 'Battery voltage',unit: 'V',min: 12,max: 14.8 },
      { tag: 'DEMO-HVAC-001',name: 'Rooftop air handler',location: 'Building B roof',title: 'Air handler performance inspection',
        days: 3,checks: ['Inspect air filters','Check fan belt condition'],reading: 'Supply temperature',unit: '°C',min: 10,max: 22 },
      { tag: 'DEMO-FIRE-001',name: 'Fire extinguisher station',location: 'Warehouse entrance',title: 'Fire safety equipment inspection',
        days: -2,checks: ['Verify safety pin and seal','Check service label is current'],reading: null,unit: '',min: 0,max: 0 },
      { tag: 'DEMO-COMP-001',name: 'Workshop air compressor',location: 'Maintenance workshop',title: 'Compressor pressure and safety check',
        days: 7,checks: ['Inspect hoses and fittings','Check pressure relief valve'],reading: 'Operating pressure',unit: 'bar',min: 6,max: 8 },
    ];
    const demoInspections = Array.from({ length: 10 },(_,index) => examples.map(example => {
      if (index === 0) return example;
      const number = String(index + 1).padStart(3,'0');
      return { ...example,tag: example.tag.replace(/001$/,number),
        name: `${example.name} ${number}`,title: `${example.title} · Unit ${number}`,
        location: `${example.location} · Zone ${index + 1}` };
    })).flat();
    for (const example of demoInspections) {
      const existingAsset = db.prepare('SELECT id FROM assets WHERE asset_tag = ?').get(example.tag) as { id: string } | undefined;
      const asset = existingAsset ? store.getAsset(existingAsset.id,actor)!
        : store.createAsset({ assetTag: example.tag,name: example.name,location: example.location },timestamp);
      const existingInspection = db.prepare('SELECT id FROM inspections WHERE asset_id = ? LIMIT 1').get(asset.id) as { id: string } | undefined;
      if (assigned && !existingInspection) {
        store.createInspection({ assetId: asset.id,assigneeId: assigned.id,title: example.title,
          dueAt: example.days === null ? null : new Date(Date.now() + example.days * 86_400_000).toISOString(),
          checklistItems: example.checks.map(label => ({ label,required: true })),
          readingDefinitions: example.reading === null ? [] : [{ label: example.reading,unit: example.unit,
            required: true,minValue: example.min,maxValue: example.max }],
        },timestamp);
      }
      const unit = Number(example.tag.slice(-3));
      if (assigned && unit >= 5) {
        const inspectionId = existingInspection?.id ?? (db.prepare('SELECT id FROM inspections WHERE asset_id = ?').get(asset.id) as { id: string }).id;
        const technicianActor = { id: assigned.id,role: 'technician' as const };
        const inspection = store.getInspection(inspectionId,technicianActor);
        // Only advance untouched seed examples, never existing user work or completed inspections.
        if (inspection?.status === 'assigned' && inspection.version === 1 && inspection.title === example.title
          && inspection.notes.length === 0 && inspection.checklistItems.every(item => item.result === null)
          && inspection.readings.every(item => item.value === null)) {
          workflow.start(technicianActor,inspection.id);
          const checks = unit >= 8 ? inspection.checklistItems : inspection.checklistItems.slice(0,1);
          for (const item of checks) workflow.result(technicianActor,inspection.id,item.id,{ result: 'pass' });
          if (unit >= 8) {
            for (const reading of inspection.readings) {
              const value = reading.minValue !== null && reading.maxValue !== null
                ? (reading.minValue + reading.maxValue) / 2 : (reading.minValue ?? reading.maxValue ?? 0);
              workflow.reading(technicianActor,inspection.id,reading.id,value);
            }
            workflow.note(technicianActor,inspection.id,'Demo inspection: all required checks passed and readings are within range.');
            workflow.complete(technicianActor,inspection.id);
          } else {
            workflow.note(technicianActor,inspection.id,'Demo inspection started; remaining checks are pending.');
          }
        }
      }
    }
  }).immediate();
  console.log('Development accounts ready: supervisor@fieldops.test, technician@fieldops.test. Existing accounts unchanged. 50 demo inspections ready with assigned, in-progress, and completed examples; existing work preserved.');
} finally { db.close(); }
