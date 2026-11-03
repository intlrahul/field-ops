import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { randomUUID } from 'node:crypto';
import { afterEach, beforeAll, expect, test } from 'vitest';
import { buildApp } from '../src/app.js';
import { migrate, openDatabase } from '../src/db/database.js';
import { authSchema } from '../src/auth/schema.js';
import { inspectionSchema } from '../src/inspections/schema.js';
import { workflowSchema } from '../src/inspections/workflow-schema.js';
import { hashPassword } from '../src/auth/password.js';
import { defaultOrganizationId } from '../src/authorization/schema.js';
import { capabilities, type Actor } from '../src/authorization/policy.js';
import { inspectionService } from '../src/inspections/service.js';
import { workflowService } from '../src/inspections/workflow-service.js';
import type { InspectionDetail } from '../src/inspections/types.js';

const password = 'authorization-test-password';
const instant = Date.UTC(2026,10,3);
let hash: string;
beforeAll(async () => { hash = await hashPassword(password); });
const cleanup: (() => void | Promise<void>)[] = [];
afterEach(async () => { for (const dispose of cleanup.splice(0).reverse()) await dispose(); });
async function fixture() {
  const dir = mkdtempSync(join(tmpdir(),'fieldops-policy-'));
  cleanup.push(() => rmSync(dir,{ recursive: true,force: true }));
  const db = openDatabase(join(dir,'test.sqlite'));
  cleanup.push(() => { db.close(); });
  migrate(db);
  const otherOrganization = randomUUID();
  db.prepare('INSERT INTO organizations VALUES (?,?)').run(otherOrganization,'Other organization');
  const users: Actor[] = [
    { id: randomUUID(),role: 'supervisor',organizationId: defaultOrganizationId },
    { id: randomUUID(),role: 'technician',organizationId: defaultOrganizationId },
    { id: randomUUID(),role: 'technician',organizationId: defaultOrganizationId },
    { id: randomUUID(),role: 'supervisor',organizationId: otherOrganization },
    { id: randomUUID(),role: 'technician',organizationId: otherOrganization },
  ];
  for (const user of users) db.prepare('INSERT INTO users(id,email,password_hash,role,organization_id) VALUES (?,?,?,?,?)')
    .run(user.id,`${user.id}@fieldops.test`,hash,user.role,user.organizationId);
  const app = buildApp(db,false,{ secret: 'authorization-test-secret-at-least-32-bytes',now: () => instant });
  cleanup.push(() => app.close());
  const pairs = [];
  for (const user of users) {
    const response = await app.inject({ method: 'POST',url: '/auth/login',remoteAddress: user.id,payload: { email: `${user.id}@fieldops.test`,password } });
    expect(response.statusCode).toBe(200);
    pairs.push(response.json());
  }
  const headers = pairs.map(pair => ({ authorization: `Bearer ${pair.accessToken}` }));
  async function asset(index = 0) {
    const response = await app.inject({ method: 'POST',url: '/assets',headers: headers[index]!,payload: { assetTag: `ASSET-${randomUUID().replaceAll('-','').toUpperCase()}`,name: 'Pump' } });
    expect(response.statusCode).toBe(201);
    return response.json();
  }
  async function inspection(assignee = 1, admin = 0) {
    const equipment = await asset(admin);
    const response = await app.inject({ method: 'POST',url: '/inspections',headers: headers[admin]!,payload: {
      assetId: equipment.id,assigneeId: users[assignee]!.id,title: 'Policy test',
      checklistItems: [{ label: 'Safety check',required: true }],
      readingDefinitions: [{ label: 'Pressure',unit: 'bar',required: true,minValue: 1,maxValue: 5 }],
    } });
    expect(response.statusCode).toBe(201);
    return response.json<InspectionDetail>();
  }
  return { app,db,users,headers,pairs,asset,inspection };
}

test('login, me and refresh consistently expose current role groups and effective capabilities', async () => {
  const f = await fixture();
  for (let index = 0; index < f.users.length; index++) {
    const user = f.users[index]!;
    const profile = (await f.app.inject({ url: '/me',headers: f.headers[index]! })).json();
    expect(profile).toEqual(f.pairs[index].user);
    expect(profile).toMatchObject({ roles: [user.role],organizationId: user.organizationId,capabilities: capabilities(user.role) });
    expect(profile.capabilities).not.toContain('templates.manage');
    const refreshed = await f.app.inject({ method: 'POST',url: '/auth/refresh',payload: { refreshToken: f.pairs[index].refreshToken } });
    expect(refreshed.statusCode).toBe(200);
    expect(refreshed.json().user).toEqual(profile);
  }
});

test('organization scope protects lists, details, assets, statistics and every workflow mutation', async () => {
  const f = await fixture();
  const local = await f.inspection();
  const remote = await f.inspection(4,3);
  for (const index of [0,1]) {
    const headers = f.headers[index]!;
    const list = await f.app.inject({ url: '/inspections',headers });
    expect(list.json().items.map((item: InspectionDetail) => item.id)).toEqual([local.id]);
    expect((await f.app.inject({ url: '/inspections/statistics',headers })).json()).toEqual({ total: 1,assigned: 1,inProgress: 0,completed: 0 });
    expect((await f.app.inject({ url: '/assets',headers })).json().items.map((item: { id: string }) => item.id)).toEqual([local.asset.id]);
    for (const url of [`/inspections/${remote.id}`,`/assets/${remote.asset.id}`]) expect((await f.app.inject({ url,headers })).statusCode).toBe(404);
    for (const [method,path,payload] of [
      ['POST','start',undefined],['POST','complete',undefined],['POST','notes',{ text: 'Attempt' }],
      ['PUT',`checklist-items/${remote.checklistItems[0]!.id}/result`,{ result: 'pass' }],
      ['PUT',`readings/${remote.readings[0]!.id}`,{ value: 3 }],
    ] as const) {
      expect((await f.app.inject({ method,url: `/inspections/${remote.id}/${path}`,headers,...(payload ? { payload } : {}) })).statusCode).toBe(404);
    }
  }
  const cursor = (await f.app.inject({ url: '/inspections?limit=1',headers: f.headers[3]! })).json().nextCursor;
  expect(cursor).toBeNull();
  // A same-organization technician cannot see another assignment either.
  expect((await f.app.inject({ url: `/inspections/${local.id}`,headers: f.headers[2]! })).statusCode).toBe(404);
  expect((await f.app.inject({ url: '/assets',headers: f.headers[2]! })).json().items).toEqual([]);
});

test.each([0,1])('assigned role index %i advertises only actions its endpoints actually permit', async index => {
  const f = await fixture();
  const inspection = await f.inspection(index);
  const headers = f.headers[index]!;
  const detail = async () => (await f.app.inject({ url: `/inspections/${inspection.id}`,headers })).json<InspectionDetail>();
  expect((await detail()).allowedActions).toEqual(['start']);
  expect((await f.app.inject({ method: 'POST',url: `/inspections/${inspection.id}/complete`,headers })).statusCode).toBe(409);
  const started = await f.app.inject({ method: 'POST',url: `/inspections/${inspection.id}/start`,headers });
  expect(started.statusCode).toBe(200);
  expect(started.json().allowedActions).toEqual(['edit_answers','edit_readings','add_note']);
  expect(started.json().completionBlockers).toHaveLength(2);
  expect((await f.app.inject({ method: 'POST',url: `/inspections/${inspection.id}/complete`,headers })).statusCode).toBe(422);
  const answered = await f.app.inject({ method: 'PUT',url: `/inspections/${inspection.id}/checklist-items/${inspection.checklistItems[0]!.id}/result`,headers,payload: { result: 'pass' } });
  expect(answered.statusCode).toBe(200);
  const measured = await f.app.inject({ method: 'PUT',url: `/inspections/${inspection.id}/readings/${inspection.readings[0]!.id}`,headers,payload: { value: 3 } });
  expect(measured.statusCode).toBe(200);
  expect(measured.json().allowedActions).toContain('complete');
  expect((await f.app.inject({ method: 'POST',url: `/inspections/${inspection.id}/notes`,headers,payload: { text: 'Verified' } })).statusCode).toBe(201);
  const completed = await f.app.inject({ method: 'POST',url: `/inspections/${inspection.id}/complete`,headers });
  expect(completed.statusCode).toBe(200);
  expect(completed.json().allowedActions).toEqual([]);
  expect(completed.json().completionBlockers).toEqual([]);
  for (const action of ['start','complete','notes']) {
    const response = await f.app.inject({ method: 'POST',url: `/inspections/${inspection.id}/${action}`,headers,...(action === 'notes' ? { payload: { text: 'No' } } : {}) });
    expect(response.statusCode).toBe(409);
  }
});

test('supervisor read scope does not grant performance of another assignment or cross-organization assignment', async () => {
  const f = await fixture();
  const inspection = await f.inspection();
  const detail = await f.app.inject({ url: `/inspections/${inspection.id}`,headers: f.headers[0]! });
  expect(detail.json().allowedActions).toEqual([]);
  for (const path of ['start','complete','notes']) {
    const response = await f.app.inject({ method: 'POST',url: `/inspections/${inspection.id}/${path}`,headers: f.headers[0]!,...(path === 'notes' ? { payload: { text: 'Not assigned' } } : {}) });
    expect(response.statusCode).toBe(403);
  }
  for (const [assetId,assigneeId] of [[inspection.asset.id,f.users[4]!.id],[(await f.asset(3)).id,f.users[1]!.id]]) {
    const response = await f.app.inject({ method: 'POST',url: '/inspections',headers: f.headers[0]!,payload: {
      assetId,assigneeId,title: 'Invalid cross-org assignment',checklistItems: [{ label: 'Check',required: true }],readingDefinitions: [],
    } });
    expect(response.statusCode).toBe(422);
    expect(response.json().error.code).toBe('INVALID_ASSIGNMENT');
  }
});

test('permission changes and revocation affect existing tokens and are rechecked inside mutations', async () => {
  const f = await fixture();
  const formerSupervisor = f.users[0]!;
  f.db.prepare("UPDATE users SET role = 'technician' WHERE id = ?").run(formerSupervisor.id);
  const me = (await f.app.inject({ url: '/me',headers: f.headers[0]! })).json();
  expect(me.roles).toEqual(['technician']);
  expect(me.capabilities).not.toContain('assets.manage');
  expect((await f.app.inject({ method: 'POST',url: '/assets',headers: f.headers[0]!,payload: { assetTag: 'NO',name: 'No' } })).statusCode).toBe(403);
  const refreshed = await f.app.inject({ method: 'POST',url: '/auth/refresh',payload: { refreshToken: f.pairs[0].refreshToken } });
  expect(refreshed.json().user).toEqual(me);
  // Even a previously authenticated, stale service actor cannot retain management authority.
  expect(() => inspectionService(f.db,() => instant).createAsset(formerSupervisor,{ assetTag: 'STALE',name: 'No' })).toThrow('Permission required');
  const inspection = await f.inspection(4,3);
  f.db.prepare('UPDATE users SET active = 0 WHERE id = ?').run(f.users[4]!.id);
  expect(() => workflowService(f.db,() => instant).start(f.users[4]!,inspection.id)).toThrow('Authentication required');
  expect((await f.app.inject({ url: '/me',headers: f.headers[4]! })).statusCode).toBe(401);
  expect((await f.app.inject({ method: 'POST',url: '/auth/refresh',payload: { refreshToken: f.pairs[4].refreshToken } })).statusCode).toBe(401);
  await f.app.inject({ method: 'POST',url: '/auth/logout',headers: f.headers[1]! });
  expect((await f.app.inject({ url: '/inspections',headers: f.headers[1]! })).statusCode).toBe(401);
});

test('clients cannot inject roles, capabilities, membership or allowed actions', async () => {
  const f = await fixture();
  for (const field of ['role','roles','capabilities','organizationId','allowedActions']) {
    const login = await f.app.inject({ method: 'POST',url: '/auth/login',payload: {
      email: `${f.users[1]!.id}@fieldops.test`,password,[field]: ['supervisor'],
    } });
    expect(login.statusCode).toBe(400);
    const response = await f.app.inject({ method: 'POST',url: '/assets',headers: f.headers[0]!,payload: { assetTag: 'ESCALATE',name: 'No',[field]: ['all'] } });
    expect(response.statusCode).toBe(400);
  }
  expect((await f.app.inject({ method: 'PATCH',url: '/me',headers: f.headers[1]!,payload: { role: 'supervisor' } })).statusCode).toBe(404);
});

test('database constraints prevent missing organizations and cross-organization assignments', async () => {
  const f = await fixture();
  expect(() => f.db.prepare('INSERT INTO users(id,email,password_hash,role) VALUES (?,?,?,?)')
    .run(randomUUID(),'missing@fieldops.test',hash,'technician')).toThrow();
  const inspection = await f.inspection();
  expect(() => f.db.prepare('UPDATE inspections SET assignee_id = ? WHERE id = ?').run(f.users[4]!.id,inspection.id)).toThrow();
  expect(() => f.db.prepare('UPDATE users SET organization_id = ? WHERE id = ?').run(f.users[4]!.organizationId,f.users[1]!.id)).toThrow();
});

test('organization changes and reassignment invalidate stale visibility and actions', async () => {
  const f = await fixture();
  const inspection = await f.inspection();
  expect((await f.app.inject({ url: `/inspections/${inspection.id}`,headers: f.headers[1]! })).json().allowedActions).toEqual(['start']);
  // A trusted internal assignment change cannot leave the former assignee authorized.
  f.db.prepare('UPDATE inspections SET assignee_id = ? WHERE id = ?').run(f.users[2]!.id,inspection.id);
  expect((await f.app.inject({ url: `/inspections/${inspection.id}`,headers: f.headers[1]! })).statusCode).toBe(404);
  expect(() => workflowService(f.db,() => instant).start(f.users[1]!,inspection.id)).toThrow('Resource not found');
  // This now-unassigned user can move organizations administratively; old tokens do not retain the old scope.
  f.db.prepare('UPDATE users SET organization_id = ? WHERE id = ?').run(f.users[4]!.organizationId,f.users[1]!.id);
  const me = await f.app.inject({ url: '/me',headers: f.headers[1]! });
  expect(me.json().organizationId).toBe(f.users[4]!.organizationId);
  expect((await f.app.inject({ url: '/inspections/statistics',headers: f.headers[1]! })).json().total).toBe(0);
});

test('cursor scopes include organization and read policy and never authorize a cross-org read', async () => {
  const f = await fixture();
  await f.inspection(4,3);
  await f.inspection(4,3);
  const first = (await f.app.inject({ url: '/inspections?limit=1',headers: f.headers[3]! })).json();
  expect(first.nextCursor).toBeTypeOf('string');
  expect((await f.app.inject({ url: `/inspections?cursor=${first.nextCursor}`,headers: f.headers[0]! })).statusCode).toBe(400);
  const decoded = JSON.parse(Buffer.from(first.nextCursor,'base64url').toString());
  decoded.scope = JSON.stringify(['inspections',f.users[0]!.id,defaultOrganizationId,true,null,null,null]);
  const forged = Buffer.from(JSON.stringify(decoded)).toString('base64url');
  expect((await f.app.inject({ url: `/inspections?cursor=${forged}`,headers: f.headers[0]! })).json()).toEqual({ items: [],nextCursor: null });
});

test('migration 4 preserves existing sessions, definitions, completed work and history', () => {
  const dir = mkdtempSync(join(tmpdir(),'fieldops-authz-migration-'));
  cleanup.push(() => rmSync(dir,{ recursive: true,force: true }));
  const db = openDatabase(join(dir,'legacy.sqlite'));
  cleanup.push(() => { db.close(); });
  db.exec(authSchema + inspectionSchema + workflowSchema);
  db.exec(`CREATE TABLE schema_migrations (version INTEGER PRIMARY KEY, applied_at TEXT NOT NULL DEFAULT '') STRICT;
    INSERT INTO schema_migrations(version) VALUES (1),(2),(3);`);
  const user = randomUUID(), asset = randomUUID(), inspection = randomUUID(), check = randomUUID(), reading = randomUUID();
  const timestamp = new Date(instant).toISOString();
  db.prepare('INSERT INTO users(id,email,password_hash,role) VALUES (?,?,?,?)').run(user,'legacy@fieldops.test',hash,'technician');
  db.prepare('INSERT INTO sessions(id,user_id,expires_at) VALUES (?,?,?)').run('legacy-session',user,Math.floor(instant/1000)+300);
  db.prepare('INSERT INTO refresh_tokens(hash,session_id) VALUES (?,?)').run('legacy-hash','legacy-session');
  db.prepare('INSERT INTO assets(id,asset_tag,name,created_at,updated_at) VALUES (?,?,?,?,?)').run(asset,'LEGACY','Legacy pump',timestamp,timestamp);
  db.prepare(`INSERT INTO inspections(id,asset_id,assignee_id,title,asset_tag,asset_name,status,created_at,updated_at,started_at,completed_at,version)
    VALUES (?,?,?,?,?,?,'completed',?,?,?,?,7)`).run(inspection,asset,user,'Legacy inspection','LEGACY','Legacy pump',timestamp,timestamp,timestamp,timestamp);
  db.prepare(`INSERT INTO checklist_items(id,inspection_id,position,label,required,result) VALUES (?,?,0,'Check',1,'pass')`).run(check,inspection);
  db.prepare(`INSERT INTO reading_definitions(id,inspection_id,position,label,unit,required,min_value,max_value) VALUES (?,?,0,'Pressure','bar',1,1,5)`).run(reading,inspection);
  db.prepare('INSERT INTO reading_measurements(id,definition_id,value,author_id,created_at) VALUES (?,?,3,?,?)').run(randomUUID(),reading,user,timestamp);
  db.prepare(`INSERT INTO inspection_notes(id,inspection_id,author_id,text,created_at) VALUES (?,?,?,'Legacy note',?)`).run(randomUUID(),inspection,user,timestamp);
  migrate(db);
  migrate(db);
  for (const table of ['users','assets','inspections']) {
    expect(db.prepare(`SELECT organization_id FROM ${table}`).get()).toEqual({ organization_id: defaultOrganizationId });
  }
  expect(db.prepare('SELECT status,version,completed_at FROM inspections').get()).toEqual({ status: 'completed',version: 7,completed_at: timestamp });
  expect(db.prepare('SELECT result FROM checklist_items').get()).toEqual({ result: 'pass' });
  expect(db.prepare('SELECT value FROM reading_measurements').get()).toEqual({ value: 3 });
  expect(db.prepare('SELECT text FROM inspection_notes').get()).toEqual({ text: 'Legacy note' });
  expect(db.prepare('SELECT revoked_at FROM sessions').get()).toEqual({ revoked_at: null });
  expect(db.prepare('SELECT hash FROM refresh_tokens').get()).toEqual({ hash: 'legacy-hash' });
  expect(db.prepare('PRAGMA foreign_key_check').all()).toEqual([]);
});
