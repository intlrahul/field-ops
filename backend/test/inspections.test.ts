import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { randomUUID } from 'node:crypto';
import { afterEach, beforeAll, expect, test } from 'vitest';
import { buildApp } from '../src/app.js';
import { openDatabase, migrate } from '../src/db/database.js';
import { authSchema } from '../src/auth/schema.js';
import { hashPassword } from '../src/auth/password.js';
import type { Asset, InspectionDetail } from '../src/inspections/types.js';

let hash: string;
beforeAll(async () => { hash = await hashPassword('integration-test-password'); });
const cleanup: (() => void | Promise<void>)[] = [];
afterEach(async () => { for (const close of cleanup.splice(0).reverse()) await close(); });
async function fixture() {
  const directory = mkdtempSync(join(tmpdir(),'fieldops-inspections-'));
  cleanup.push(() => rmSync(directory,{ recursive: true,force: true }));
  const db = openDatabase(join(directory,'test.sqlite'));
  cleanup.push(() => { db.close(); });
  migrate(db);
  const users = [
    { id: randomUUID(),role: 'supervisor' },
    { id: randomUUID(),role: 'technician' },
    { id: randomUUID(),role: 'technician' },
  ];
  for (const [index,user] of users.entries()) {
    db.prepare('INSERT INTO users (id,email,password_hash,role) VALUES (?,?,?,?)')
      .run(user.id,`user${index}@fieldops.test`,hash,user.role);
  }
  const app = buildApp(db,false,{ secret: 'integration-test-secret-32-bytes-minimum',now: () => Date.UTC(2026,9,15) });
  cleanup.push(() => app.close());
  const headers = [];
  for (let index = 0; index < users.length; index++) {
    const response = await app.inject({ method: 'POST',url: '/auth/login',payload: { email: `user${index}@fieldops.test`,password: 'integration-test-password' } });
    expect(response.statusCode).toBe(200);
    headers.push({ authorization: `Bearer ${response.json().accessToken}` });
  }
  const admin = headers[0]!; const tech = headers[1]!; const other = headers[2]!;
  const createAsset = (tag = 'PUMP-001') => app.inject({ method: 'POST',url: '/assets',headers: admin,payload: { assetTag: tag,name: 'Cooling pump',location: 'Plant A' } });
  const body = (assetId: string,assigneeId = users[1]!.id) => ({
    assetId,assigneeId,title: 'Safety inspection',dueAt: '2026-10-20T14:30:00+05:30',
    checklistItems: [{ label: 'Check housing',required: true },{ label: 'Check paint',required: false }],
    readingDefinitions: [{ label: 'Temperature',unit: '°C',required: true,minValue: 0,maxValue: 80 }],
  });
  const createInspection = (payload: unknown) => app.inject({ method: 'POST',url: '/inspections',headers: admin,payload: payload as object });
  return { db,app,users,admin,tech,other,createAsset,body,createInspection };
}

test('creates assets and ordered inspection details with fixed initial state and normalized dates', async () => {
  const f = await fixture();
  const assetResponse = await f.createAsset();
  expect(assetResponse.statusCode).toBe(201);
  const asset = assetResponse.json<Asset>();
  expect(assetResponse.headers.location).toBe(`/assets/${asset.id}`);
  const response = await f.createInspection(f.body(asset.id));
  expect(response.statusCode).toBe(201);
  const inspection = response.json<InspectionDetail>();
  expect(response.headers.location).toBe(`/inspections/${inspection.id}`);
  expect(inspection).toMatchObject({ status: 'assigned',version: 1,dueAt: '2026-10-20T09:00:00.000Z',notes: [],startedAt: null,completedAt: null,
    asset: { id: asset.id,assetTag: 'PUMP-001',name: 'Cooling pump',location: 'Plant A' } });
  expect(inspection.checklistItems.map(i => [i.label,i.position,i.required,i.result,i.failureNote]))
    .toEqual([['Check housing',0,true,null,null],['Check paint',1,false,null,null]]);
  expect(inspection.readings[0]).toMatchObject({ position: 0,minValue: 0,maxValue: 80,value: null,rangeStatus: 'unrecorded',required: true });
  expect((await f.app.inject({ url: `/inspections/${inspection.id}`,headers: f.tech })).json()).toEqual(inspection);
});

test('requires authentication and enforces supervisor-only actions before body validation', async () => {
  const f = await fixture();
  for (const url of ['/assets','/inspections','/assets/'+randomUUID(),'/inspections/'+randomUUID()]) {
    expect((await f.app.inject({ url })).statusCode).toBe(401);
  }
  for (const url of ['/assets','/inspections']) {
    expect((await f.app.inject({ method: 'POST',url,headers: f.tech,payload: {} })).statusCode).toBe(403);
  }
  expect((await f.app.inject({ url: '/assets',headers: f.tech })).statusCode).toBe(403);
});

test('technicians cannot discover other assignments or their assets', async () => {
  const f = await fixture();
  const asset = (await f.createAsset()).json<Asset>();
  const inspection = (await f.createInspection(f.body(asset.id))).json<InspectionDetail>();
  for (const url of [`/assets/${asset.id}`,`/inspections/${inspection.id}`]) {
    expect((await f.app.inject({ url,headers: f.tech })).statusCode).toBe(200);
    const denied = await f.app.inject({ url,headers: f.other });
    expect(denied.statusCode).toBe(404);
    expect(denied.json()).toEqual({ error: { code: 'NOT_FOUND',message: 'Resource not found' } });
  }
  expect((await f.app.inject({ url: '/inspections',headers: f.other })).json()).toEqual({ items: [],nextCursor: null });
  expect((await f.app.inject({ url: `/inspections?assigneeId=${f.users[1]!.id}`,headers: f.tech })).statusCode).toBe(403);
  expect((await f.app.inject({ url: '/inspections',headers: f.admin })).json().items).toHaveLength(1);
});

test('snapshots remain fixed when the live asset changes', async () => {
  const f = await fixture();
  const asset = (await f.createAsset()).json<Asset>();
  const inspection = (await f.createInspection(f.body(asset.id))).json<InspectionDetail>();
  f.db.prepare("UPDATE assets SET name = 'New name', location = 'Plant B',asset_tag = 'NEW-TAG' WHERE id = ?").run(asset.id);
  const current = (await f.app.inject({ url: `/assets/${asset.id}`,headers: f.tech })).json();
  expect(current.name).toBe('New name');
  const saved = (await f.app.inject({ url: `/inspections/${inspection.id}`,headers: f.tech })).json();
  expect(saved.asset).toEqual(inspection.asset);
  expect(saved.checklistItems).toEqual(inspection.checklistItems);
  expect((await f.app.inject({ method: 'PATCH',url: `/inspections/${inspection.id}`,headers: f.admin,payload: { checklistItems: [] } })).statusCode).toBe(404);
});

test('duplicate tags, invalid references, and inactive assignees have safe errors without partial data', async () => {
  const f = await fixture();
  const asset = (await f.createAsset()).json<Asset>();
  expect((await f.createAsset()).statusCode).toBe(409);
  for (const payload of [f.body(randomUUID()),f.body(asset.id,randomUUID()),f.body(asset.id,f.users[0]!.id)]) {
    const response = await f.createInspection(payload);
    expect(response.statusCode).toBe(422);
    expect(response.json().error.code).toBe('INVALID_ASSIGNMENT');
  }
  f.db.prepare('UPDATE users SET active = 0 WHERE id = ?').run(f.users[1]!.id);
  expect((await f.createInspection(f.body(asset.id))).statusCode).toBe(422);
  expect(f.db.prepare('SELECT COUNT(*) AS count FROM inspections').get()).toEqual({ count: 0 });
  expect(f.db.prepare('SELECT COUNT(*) AS count FROM checklist_items').get()).toEqual({ count: 0 });
});

test('a failed nested write rolls back the inspection and all earlier children', async () => {
  const f = await fixture();
  const asset = (await f.createAsset()).json<Asset>();
  f.db.exec(`CREATE TRIGGER fail_reading BEFORE INSERT ON reading_definitions BEGIN SELECT RAISE(ABORT,'test failure'); END;`);
  const response = await f.createInspection(f.body(asset.id));
  expect(response.statusCode).toBe(500);
  expect(response.json()).toEqual({ error: { code: 'INTERNAL_ERROR',message: 'Internal server error' } });
  for (const table of ['inspections','checklist_items','reading_definitions']) {
    expect(f.db.prepare(`SELECT COUNT(*) AS count FROM ${table}`).get()).toEqual({ count: 0 });
  }
});

test('rejects bad definitions, blank text, extra fields, numeric strings and invalid dates', async () => {
  const f = await fixture();
  const asset = (await f.createAsset()).json<Asset>();
  const valid = f.body(asset.id);
  for (const payload of [
    { ...valid,title: '   ' },{ ...valid,status: 'completed' },{ ...valid,checklistItems: [] },
    { ...valid,dueAt: '2026-10-15T12:00:00' },{ ...valid,dueAt: 'not-a-date' },{ ...valid,dueAt: '2026-02-30T12:00:00Z' },
    { ...valid,readingDefinitions: [{ ...valid.readingDefinitions[0],minValue: '0' }] },
    { ...valid,checklistItems: [{ label: 'Test',required: 'true' }] },
  ]) expect((await f.createInspection(payload)).statusCode).toBe(400);
  const range = await f.createInspection({ ...valid,readingDefinitions: [{ ...valid.readingDefinitions[0],minValue: 100 }] });
  expect(range.statusCode).toBe(422);
  expect(range.json().error.code).toBe('INVALID_DEFINITION');
  expect(f.db.prepare('SELECT COUNT(*) AS count FROM inspections').get()).toEqual({ count: 0 });
});

test('trims human text and permits nullable bounds, due dates and locations', async () => {
  const f = await fixture();
  const response = await f.app.inject({ method: 'POST',url: '/assets',headers: f.admin,payload: { assetTag: 'TRIM',name: '  Pump  ' } });
  expect(response.statusCode).toBe(201);
  const asset = response.json<Asset>();
  expect(asset.name).toBe('Pump'); expect(asset.location).toBeNull();
  const payload = { ...f.body(asset.id),title: '  Inspection  ',dueAt: null,
    readingDefinitions: [{ label: '  Speed  ',unit: ' rpm ',required: false,minValue: null,maxValue: null }] };
  const inspection = await f.createInspection(payload);
  expect(inspection.statusCode).toBe(201);
  expect(inspection.json()).toMatchObject({ title: 'Inspection',dueAt: null,readings: [{ label: 'Speed',unit: 'rpm',minValue: null,maxValue: null }] });
});

test('keyset pagination is deterministic with equal timestamps and scopes cursors to actor and filters', async () => {
  const f = await fixture();
  const ids = [];
  for (const tag of ['A','B','C']) ids.push((await f.createAsset(tag)).json<Asset>().id);
  const first = (await f.app.inject({ url: '/assets?limit=2',headers: f.admin })).json();
  const second = (await f.app.inject({ url: `/assets?limit=2&cursor=${first.nextCursor}`,headers: f.admin })).json();
  expect([...first.items,...second.items].map((a: Asset) => a.id)).toEqual(ids.sort().reverse());
  expect(second.nextCursor).toBeNull();
  for (const id of ids) expect((await f.createInspection(f.body(id))).statusCode).toBe(201);
  const page = (await f.app.inject({ url: '/inspections?status=assigned&limit=1',headers: f.tech })).json();
  const cursor = page.nextCursor;
  expect(cursor).toBeTypeOf('string');
  expect((await f.app.inject({ url: `/inspections?status=assigned&limit=1&cursor=${cursor}`,headers: f.tech })).statusCode).toBe(200);
  for (const [url,headers] of [
    [`/inspections?status=completed&cursor=${cursor}`,f.tech],
    [`/inspections?status=assigned&cursor=${cursor}`,f.other],
    ['/inspections?cursor=not-valid',f.tech],
  ] as const) {
    const response = await f.app.inject({ url,headers });
    expect(response.statusCode).toBe(400);
    expect(response.json().error.code).toBe('INVALID_CURSOR');
  }
});

test('supervisor filters work and invalid list parameters are rejected', async () => {
  const f = await fixture();
  const a = (await f.createAsset('A')).json<Asset>(); const b = (await f.createAsset('B')).json<Asset>();
  await f.createInspection(f.body(a.id)); await f.createInspection(f.body(b.id,f.users[2]!.id));
  expect((await f.app.inject({ url: `/inspections?assigneeId=${f.users[1]!.id}&assetId=${a.id}&status=assigned`,headers: f.admin })).json().items).toHaveLength(1);
  expect((await f.app.inject({ url: `/inspections?assetId=${b.id}`,headers: f.tech })).json().items).toHaveLength(0);
  for (const suffix of ['limit=0','limit=101','limit=2.5','limit=-1','status=invalid','unknown=value']) {
    expect((await f.app.inject({ url: `/inspections?${suffix}`,headers: f.admin })).statusCode).toBe(400);
  }
});

test('forging a cursor scope cannot bypass the SQL authorization predicate', async () => {
  const f = await fixture();
  const asset = (await f.createAsset()).json<Asset>();
  await f.createInspection(f.body(asset.id)); await f.createInspection(f.body(asset.id));
  const first = (await f.app.inject({ url: '/inspections?limit=1',headers: f.tech })).json();
  const decoded = JSON.parse(Buffer.from(first.nextCursor,'base64url').toString('utf8'));
  decoded.scope = JSON.stringify(['inspections',f.users[2]!.id,'technician',null,null,null]);
  const forged = Buffer.from(JSON.stringify(decoded)).toString('base64url');
  const response = await f.app.inject({ url: `/inspections?cursor=${forged}`,headers: f.other });
  expect(response.statusCode).toBe(200);
  expect(response.json()).toEqual({ items: [],nextCursor: null });
});


test('upgrading an authentication-only database preserves existing accounts', () => {
  const directory = mkdtempSync(join(tmpdir(),'fieldops-upgrade-'));
  cleanup.push(() => rmSync(directory,{ recursive: true,force: true }));
  const db = openDatabase(join(directory,'old.sqlite'));
  cleanup.push(() => { db.close(); });
  db.exec(`CREATE TABLE schema_migrations (version INTEGER PRIMARY KEY,
    applied_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))) STRICT;
    ${authSchema}
    INSERT INTO schema_migrations (version) VALUES (1);`);
  const id = randomUUID();
  db.prepare('INSERT INTO users (id,email,password_hash,role) VALUES (?,?,?,?)')
    .run(id,'existing@fieldops.test',hash,'technician');
  migrate(db);
  migrate(db);
  expect(db.prepare('SELECT id FROM users').get()).toEqual({ id });
  expect(db.prepare('SELECT version FROM schema_migrations ORDER BY version').all())
    .toEqual([{ version: 1 },{ version: 2 },{ version: 3 }]);
  expect(db.prepare('SELECT COUNT(*) AS count FROM assets').get()).toEqual({ count: 0 });
});
