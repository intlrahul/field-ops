import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { randomUUID } from 'node:crypto';
import { afterEach, beforeAll, expect, test } from 'vitest';
import { buildApp } from '../src/app.js';
import { openDatabase, migrate } from '../src/db/database.js';
import { inspectionSchema } from '../src/inspections/schema.js';
import { authSchema } from '../src/auth/schema.js';
import { inspectionStore } from '../src/inspections/store.js';
import { hashPassword } from '../src/auth/password.js';
import type { InspectionDetail } from '../src/inspections/types.js';

const secret = 'workflow-test-signing-secret-at-least-32-bytes';
const instant = Date.UTC(2026,9,15);
let hash: string;
beforeAll(async () => { hash = await hashPassword('workflow-test-password'); });
const cleanup: (() => void | Promise<void>)[] = [];
afterEach(async () => { for (const close of cleanup.splice(0).reverse()) await close(); });
async function fixture() {
  const directory = mkdtempSync(join(tmpdir(),'fieldops-workflow-'));
  cleanup.push(() => rmSync(directory,{ recursive: true,force: true }));
  const path = join(directory,'test.sqlite');
  const db = openDatabase(path);
  cleanup.push(() => { db.close(); });
  migrate(db);
  const users = ['supervisor','technician','technician'].map(role => ({ id: randomUUID(),role }));
  for (const [index,user] of users.entries()) db.prepare('INSERT INTO users (id,email,password_hash,role) VALUES (?,?,?,?)')
    .run(user.id,`workflow${index}@fieldops.test`,hash,user.role);
  const app = buildApp(db,false,{ secret,now: () => instant });
  cleanup.push(() => app.close());
  const headers = [];
  for (let index = 0; index < users.length; index++) {
    const response = await app.inject({ method: 'POST',url: '/auth/login',payload: { email: `workflow${index}@fieldops.test`,password: 'workflow-test-password' } });
    expect(response.statusCode).toBe(200);
    headers.push({ authorization: `Bearer ${response.json().accessToken}` });
  }
  const admin = headers[0]!; const tech = headers[1]!; const other = headers[2]!;
  const asset = (await app.inject({ method: 'POST',url: '/assets',headers: admin,payload: { assetTag: 'TEST',name: 'Test pump' } })).json();
  const create = async () => {
    const response = await app.inject({ method: 'POST',url: '/inspections',headers: admin,payload: {
      assetId: asset.id,assigneeId: users[1]!.id,title: 'Test inspection',
      checklistItems: [{ label: 'Mandatory',required: true },{ label: 'Optional',required: false }],
      readingDefinitions: [
        { label: 'Temperature',unit: '°C',required: true,minValue: 0,maxValue: 80 },
        { label: 'Optional',unit: 'bar',required: false,minValue: 1,maxValue: 10 },
      ],
    } });
    expect(response.statusCode).toBe(201); return response.json<InspectionDetail>();
  };
  const inspection = await create(); const base = `/inspections/${inspection.id}`;
  const start = () => app.inject({ method: 'POST',url: `${base}/start`,headers: tech });
  const result = (result: 'pass' | 'fail' | null, failureNote?: string | null, itemId = inspection.checklistItems[0]!.id) =>
    app.inject({ method: 'PUT',url: `${base}/checklist-items/${itemId}/result`,headers: tech,payload: { result,...(failureNote !== undefined ? { failureNote } : {}) } });
  const reading = (value: number, readingId = inspection.readings[0]!.id) =>
    app.inject({ method: 'PUT',url: `${base}/readings/${readingId}`,headers: tech,payload: { value } });
  const note = (text = 'A general note') => app.inject({ method: 'POST',url: `${base}/notes`,headers: tech,payload: { text } });
  const complete = () => app.inject({ method: 'POST',url: `${base}/complete`,headers: tech });
  const detail = () => app.inject({ url: base,headers: tech });
  const ready = async () => { await start(); await result('pass'); await reading(40); };
  return { db,path,app,users,admin,tech,other,inspection,base,create,start,result,reading,note,complete,detail,ready };
}

test('start sets lifecycle metadata once, and the full workflow persists completion', async () => {
  const f = await fixture();
  const started = await f.start();
  expect(started.statusCode).toBe(200);
  expect(started.json()).toMatchObject({ status: 'in_progress',version: 2,startedAt: new Date(instant).toISOString() });
  expect((await f.start()).json()).toEqual(started.json());
  expect((await f.result('pass')).statusCode).toBe(200);
  expect((await f.reading(80)).statusCode).toBe(200);
  const note = await f.note('  Checked by technician  ');
  expect(note.statusCode).toBe(201);
  expect(note.json()).toMatchObject({ text: 'Checked by technician',authorId: f.users[1]!.id });
  const response = await f.complete();
  expect(response.statusCode).toBe(200);
  expect(response.json()).toMatchObject({ status: 'completed',version: 6,completedAt: new Date(instant).toISOString(),notes: [note.json()] });
  expect((await f.detail()).json()).toEqual(response.json());
  expect((await f.app.inject({ url: '/inspections?status=completed',headers: f.tech })).json().items).toHaveLength(1);
});

test('work and completion require an explicitly started inspection', async () => {
  const f = await fixture();
  for (const response of [await f.result('pass'),await f.reading(40),await f.note(),await f.complete()]) {
    expect(response.statusCode).toBe(409);
    expect(response.json().error.code).toBe('INVALID_STATE');
  }
  expect((await f.detail()).json()).toEqual(f.inspection);
});

test('completion reports every blocker and changes no version or lifecycle fields', async () => {
  const f = await fixture();
  await f.start();
  const before = (await f.detail()).json();
  const response = await f.complete();
  expect(response.statusCode).toBe(422);
  expect(response.json().error).toEqual({ code: 'COMPLETION_BLOCKED',message: 'Inspection requirements are not satisfied',details: { blockers: [
    { code: 'CHECKLIST_UNANSWERED',itemId: f.inspection.checklistItems[0]!.id },
    { code: 'READING_REQUIRED',itemId: f.inspection.readings[0]!.id },
  ] } });
  expect((await f.detail()).json()).toEqual(before);
});

test('failed checks can be drafted; only item-specific explanation satisfies completion', async () => {
  const f = await fixture(); await f.ready();
  expect((await f.result('fail')).statusCode).toBe(200);
  await f.note('General note does not explain a specific failure');
  expect((await f.complete()).json().error.details.blockers).toEqual([
    { code: 'FAILURE_NOTE_REQUIRED',itemId: f.inspection.checklistItems[0]!.id },
  ]);
  const updated = await f.result('fail','  Cracked housing reported  ');
  expect(updated.json().checklistItems[0].failureNote).toBe('Cracked housing reported');
  expect((await f.complete()).statusCode).toBe(200);
});

test('out-of-range measurements are retained, flagged, and cannot be waived by a note', async () => {
  const f = await fixture(); await f.ready();
  const response = await f.reading(90);
  expect(response.statusCode).toBe(200);
  expect(response.json().readings[0]).toMatchObject({ value: 90,rangeStatus: 'out_of_range' });
  await f.note('Supervisor informed');
  expect((await f.complete()).json().error.details.blockers).toEqual([
    { code: 'READING_OUT_OF_RANGE',itemId: f.inspection.readings[0]!.id },
  ]);
  await f.reading(80);
  expect(f.db.prepare('SELECT value FROM reading_measurements WHERE definition_id = ? ORDER BY sequence').all(f.inspection.readings[0]!.id))
    .toEqual([{ value: 40 },{ value: 90 },{ value: 80 }]);
  expect((await f.complete()).statusCode).toBe(200);
});

test('identical PUTs are no-ops; clearing a result restores its completion blocker', async () => {
  const f = await fixture(); await f.ready();
  const before = (await f.detail()).json();
  expect((await f.result('pass')).json()).toEqual(before);
  expect((await f.reading(40)).json()).toEqual(before);
  expect(f.db.prepare('SELECT COUNT(*) AS count FROM reading_measurements').get()).toEqual({ count: 1 });
  await f.result(null);
  expect((await f.complete()).json().error.details.blockers[0].code).toBe('CHECKLIST_UNANSWERED');
  await f.result('fail','Explanation');
  expect((await f.result('pass','A stale explanation')).statusCode).toBe(400);
  const passed = await f.result('pass');
  expect(passed.json().checklistItems[0].failureNote).toBeNull();
});

test('optional failed checks and provided optional out-of-range readings block completion', async () => {
  const f = await fixture(); await f.ready();
  await f.result('fail',undefined,f.inspection.checklistItems[1]!.id);
  await f.reading(11,f.inspection.readings[1]!.id);
  expect((await f.complete()).json().error.details.blockers).toEqual([
    { code: 'FAILURE_NOTE_REQUIRED',itemId: f.inspection.checklistItems[1]!.id },
    { code: 'READING_OUT_OF_RANGE',itemId: f.inspection.readings[1]!.id },
  ]);
});

test('completed inspections reject every work mutation and remain readable by supervisor', async () => {
  const f = await fixture(); await f.ready();
  const completed = (await f.complete()).json();
  for (const response of [await f.start(),await f.result('fail','Late'),await f.reading(100),await f.note(),await f.complete()]) {
    expect(response.statusCode).toBe(409);
    expect(response.json().error.code).toBe('INSPECTION_READ_ONLY');
  }
  expect((await f.detail()).json()).toEqual(completed);
  expect((await f.app.inject({ url: f.base,headers: f.admin })).json()).toEqual(completed);
});

test('all work endpoints reject anonymous, supervisor, and nonassigned callers', async () => {
  const f = await fixture(); await f.start();
  const requests = [
    { method: 'POST' as const,url: `${f.base}/start` },{ method: 'POST' as const,url: `${f.base}/complete` },
    { method: 'POST' as const,url: `${f.base}/notes`,payload: { text: 'note' } },
    { method: 'PUT' as const,url: `${f.base}/readings/${f.inspection.readings[0]!.id}`,payload: { value: 40 } },
    { method: 'PUT' as const,url: `${f.base}/checklist-items/${f.inspection.checklistItems[0]!.id}/result`,payload: { result: 'pass' } },
  ];
  for (const request of requests) {
    expect((await f.app.inject(request)).statusCode).toBe(401);
    expect((await f.app.inject({ ...request,headers: f.admin })).statusCode).toBe(403);
    expect((await f.app.inject({ ...request,headers: f.other })).statusCode).toBe(404);
  }
});

test('child IDs are scoped to their parent inspection and invalid input never mutates data', async () => {
  const f = await fixture(); await f.start(); const second = await f.create();
  const before = (await f.detail()).json();
  expect((await f.result('pass',undefined,second.checklistItems[0]!.id)).statusCode).toBe(404);
  expect((await f.reading(50,second.readings[0]!.id)).statusCode).toBe(404);
  for (const payload of [{ value: '40' },{ value: null },{ value: 50,unit: 'F' }]) {
    expect((await f.app.inject({ method: 'PUT',url: `${f.base}/readings/${f.inspection.readings[0]!.id}`,headers: f.tech,payload })).statusCode).toBe(400);
  }
  expect((await f.note('   ')).statusCode).toBe(400);
  expect((await f.app.inject({ method: 'POST',url: `${f.base}/complete`,headers: f.tech,payload: { override: true } })).statusCode).toBe(400);
  expect((await f.detail()).json()).toEqual(before);
});

test('notes are append-only and cannot impersonate another author', async () => {
  const f = await fixture(); await f.start();
  const first = (await f.note('First')).json(); const second = (await f.note('Second')).json();
  expect(first.id).not.toBe(second.id);
  expect((await f.detail()).json().notes).toEqual([first,second]);
  expect((await f.app.inject({ method: 'POST',url: `${f.base}/notes`,headers: f.tech,payload: { text: 'Forged',authorId: f.users[0]!.id } })).statusCode).toBe(400);
  expect((await f.app.inject({ method: 'DELETE',url: `${f.base}/notes/${first.id}`,headers: f.tech })).statusCode).toBe(404);
});

test('failure after a lifecycle update rolls back status, timestamp, and version together', async () => {
  const f = await fixture(); await f.ready(); const before = (await f.detail()).json();
  f.db.exec(`CREATE TRIGGER reject_complete_touch BEFORE UPDATE OF version ON inspections
    WHEN NEW.status = 'completed' BEGIN SELECT RAISE(ABORT,'test rollback'); END;`);
  expect((await f.complete()).statusCode).toBe(500);
  expect((await f.detail()).json()).toEqual(before);
});

test('completion and reading writes on separate connections cannot leave completed out-of-range work', async () => {
  const f = await fixture(); await f.ready();
  const db = openDatabase(f.path); cleanup.push(() => { db.close(); });
  const app = buildApp(db,false,{ secret,now: () => instant }); cleanup.push(() => app.close());
  const [complete,reading] = await Promise.all([
    f.complete(),app.inject({ method: 'PUT',url: `${f.base}/readings/${f.inspection.readings[0]!.id}`,headers: f.tech,payload: { value: 90 } }),
  ]);
  const final = (await f.detail()).json();
  if (complete.statusCode === 200) {
    expect(reading.statusCode).toBe(409); expect(final.status).toBe('completed'); expect(final.readings[0].value).toBe(40);
  } else {
    expect(complete.statusCode).toBe(422); expect(reading.statusCode).toBe(200); expect(final.status).toBe('in_progress'); expect(final.readings[0].value).toBe(90);
  }
});


test('migration from existing inspection data preserves definitions and initializes unanswered work', () => {
  const directory = mkdtempSync(join(tmpdir(),'fieldops-workflow-upgrade-'));
  cleanup.push(() => rmSync(directory,{ recursive: true,force: true }));
  const db = openDatabase(join(directory,'previous.sqlite')); cleanup.push(() => { db.close(); });
  db.exec(`CREATE TABLE schema_migrations (version INTEGER PRIMARY KEY,
    applied_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))) STRICT;
    ${authSchema}
    ${inspectionSchema}
    INSERT INTO schema_migrations (version) VALUES (1),(2);`);
  const technician = randomUUID(); const asset = randomUUID(); const inspection = randomUUID();
  const check = randomUUID(); const reading = randomUUID(); const timestamp = new Date(instant).toISOString();
  db.prepare('INSERT INTO users (id,email,password_hash,role) VALUES (?,?,?,?)').run(technician,'old@fieldops.test',hash,'technician');
  db.prepare('INSERT INTO assets (id,asset_tag,name,created_at,updated_at) VALUES (?,?,?,?,?)').run(asset,'OLD','Historical pump',timestamp,timestamp);
  db.prepare(`INSERT INTO inspections (id,asset_id,assignee_id,title,asset_tag,asset_name,created_at,updated_at)
    VALUES (?,?,?,?,?,?,?,?)`).run(inspection,asset,technician,'Historical inspection','OLD','Historical pump',timestamp,timestamp);
  db.prepare('INSERT INTO checklist_items (id,inspection_id,position,label,required) VALUES (?,?,?,?,?)').run(check,inspection,0,'Old check',1);
  db.prepare('INSERT INTO reading_definitions (id,inspection_id,position,label,unit,required,min_value,max_value) VALUES (?,?,?,?,?,?,?,?)')
    .run(reading,inspection,0,'Old reading','°C',1,0,80);
  migrate(db); migrate(db);
  const detail = inspectionStore(db).getInspection(inspection,{ id: technician,role: 'technician' });
  expect(detail).toMatchObject({ status: 'assigned',version: 1,asset: { name: 'Historical pump' },
    checklistItems: [{ id: check,label: 'Old check',result: null,failureNote: null }],
    readings: [{ id: reading,minValue: 0,maxValue: 80,value: null,rangeStatus: 'unrecorded' }],notes: [] });
});

test('nonfinite JSON numeric input is rejected without losing an existing reading', async () => {
  const f = await fixture(); await f.ready(); const before = (await f.detail()).json();
  const response = await f.app.inject({ method: 'PUT',url: `${f.base}/readings/${f.inspection.readings[0]!.id}`,
    headers: { ...f.tech,'content-type': 'application/json' },payload: '{"value":1e400}' });
  expect(response.statusCode).toBe(400);
  expect((await f.detail()).json()).toEqual(before);
});
