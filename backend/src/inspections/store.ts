import { capabilities, organizationWide, presentInspection } from '../authorization/policy.js';
import { readingStatus } from './rules.js';
import { randomUUID } from 'node:crypto';
import type { SqliteDatabase } from '../db/database.js';
import { DomainError } from './errors.js';
import type { Actor, Asset, AssetInput, InspectionInput, InspectionSummary, InspectionDetail, ListOptions, ChecklistItem, Reading, InspectionNote, InspectionStatistics } from './types.js';

const assetColumns = `organization_id AS organizationId, id, asset_tag AS assetTag, name, location, created_at AS createdAt, updated_at AS updatedAt, version`;
const inspectionColumns = `organization_id AS organizationId, id, title, status, asset_id AS assetId, asset_tag AS assetTag, asset_name AS assetName,
 asset_location AS assetLocation, assignee_id AS assigneeId, due_at AS dueAt,
 created_at AS createdAt, updated_at AS updatedAt, version, started_at AS startedAt, completed_at AS completedAt`;
type InspectionRow = Omit<InspectionSummary,'asset'> & {
  assetId: string; assetTag: string; assetName: string; assetLocation: string | null;
  startedAt: string | null; completedAt: string | null;
};
function summary(row: InspectionRow): InspectionSummary {
  return { organizationId: row.organizationId,id: row.id, title: row.title, status: row.status,
    asset: { id: row.assetId, assetTag: row.assetTag, name: row.assetName, location: row.assetLocation },
    assigneeId: row.assigneeId, dueAt: row.dueAt, createdAt: row.createdAt, updatedAt: row.updatedAt, version: row.version };
}
function scope(actor: Actor) {
  return organizationWide(actor) ? { sql: 'organization_id = ?',params: [actor.organizationId] }
    : { sql: 'organization_id = ? AND assignee_id = ?',params: [actor.organizationId,actor.id] };
}
function continuation(options: ListOptions, clauses: string[], params: (string | number)[]) {
  if (options.position) {
    clauses.push('(created_at, id) < (?, ?)');
    params.push(options.position.createdAt,options.position.id);
  }
  params.push(options.limit+1);
}
export function inspectionStore(db: SqliteDatabase) {
  function getAsset(id: string, actor: Actor) {
    const access = organizationWide(actor) ? '' : ` AND EXISTS (
      SELECT 1 FROM inspections WHERE asset_id = assets.id AND organization_id = assets.organization_id AND assignee_id = ?)`;
    return db.prepare(`SELECT ${assetColumns} FROM assets WHERE id = ? AND organization_id = ?${access}`)
      .get(...(organizationWide(actor) ? [id,actor.organizationId] : [id,actor.organizationId,actor.id])) as Asset | undefined;
  }
  function getInspection(id: string, actor: Actor): InspectionDetail | undefined {
    return db.transaction(() => {
      const access = scope(actor);
      const row = db.prepare(`SELECT ${inspectionColumns} FROM inspections WHERE id = ? AND ${access.sql}`)
        .get(id,...access.params) as InspectionRow | undefined;
      if (!row) return undefined;
      const checklist = db.prepare(`SELECT id,position,label,required,result,failure_note AS failureNote FROM checklist_items WHERE inspection_id = ? ORDER BY position`)
        .all(id) as { id: string; position: number; label: string; required: number; result: ChecklistItem['result']; failureNote: string | null }[];
      const readings = db.prepare(`SELECT id,position,label,unit,required,min_value AS minValue,max_value AS maxValue,
        (SELECT value FROM reading_measurements WHERE definition_id = reading_definitions.id ORDER BY sequence DESC LIMIT 1) AS value
        FROM reading_definitions WHERE inspection_id = ? ORDER BY position`).all(id) as {
          id: string; position: number; label: string; unit: string; required: number; minValue: number | null; maxValue: number | null; value: number | null;
        }[];
      const notes = db.prepare(`SELECT id,author_id AS authorId,text,created_at AS createdAt
        FROM inspection_notes WHERE inspection_id = ? ORDER BY sequence`).all(id) as InspectionNote[];
      const detail: InspectionDetail = { allowedActions: [],completionBlockers: [],...summary(row), startedAt: row.startedAt, completedAt: row.completedAt, notes,
        checklistItems: checklist.map((item): ChecklistItem => ({ ...item,required: Boolean(item.required) })),
        readings: readings.map((item): Reading => ({ ...item,required: Boolean(item.required),rangeStatus: readingStatus(item.value,item) })) };
      return presentInspection(actor,detail);
    })();
  }
  return {
    getAsset, getInspection,
    inspectionStatistics(actor: Actor): InspectionStatistics {
      const access = scope(actor);
      return db.prepare(`SELECT COUNT(*) AS total,
        COUNT(CASE WHEN status = 'assigned' THEN 1 END) AS assigned,
        COUNT(CASE WHEN status = 'in_progress' THEN 1 END) AS inProgress,
        COUNT(CASE WHEN status = 'completed' THEN 1 END) AS completed
        FROM inspections WHERE ${access.sql}`).get(...access.params) as InspectionStatistics;
    },
    createAsset(input: AssetInput, timestamp: string, actor: Actor): Asset {
      const id = randomUUID();
      try {
        db.prepare('INSERT INTO assets (id,asset_tag,name,location,created_at,updated_at,organization_id) VALUES (?,?,?,?,?,?,?)')
          .run(id,input.assetTag,input.name,input.location ?? null,timestamp,timestamp,actor.organizationId);
      } catch (error) {
        if (error instanceof Error && 'code' in error && error.code === 'SQLITE_CONSTRAINT_UNIQUE') {
          throw new DomainError(409,'ASSET_TAG_EXISTS','Asset tag already exists');
        }
        throw error;
      }
      return getAsset(id,actor)!;
    },
    listAssets(actor: Actor, options: ListOptions) {
      const clauses = ['organization_id = ?']; const params: (string | number)[] = [actor.organizationId];
      if (!organizationWide(actor)) {
        clauses.push('EXISTS (SELECT 1 FROM inspections WHERE asset_id = assets.id AND inspections.organization_id = assets.organization_id AND assignee_id = ?)');
        params.push(actor.id);
      }
      continuation(options,clauses,params);
      return db.prepare(`SELECT ${assetColumns} FROM assets WHERE ${clauses.join(' AND ')}
        ORDER BY created_at DESC,id DESC LIMIT ?`).all(...params) as Asset[];
    },
    createInspection(input: InspectionInput, timestamp: string, actor: Actor): InspectionDetail {
      return db.transaction(() => {
        const asset = getAsset(input.assetId,actor);
        const assignee = db.prepare("SELECT id,role FROM users WHERE id = ? AND organization_id = ? AND active = 1").get(input.assigneeId,actor.organizationId) as { id: string; role: Actor['role'] } | undefined;
        if (!asset || !assignee || !capabilities(assignee.role).includes('inspections.perform')) throw new DomainError(422,'INVALID_ASSIGNMENT','Valid same-organization asset and eligible assignee required');
        const id = randomUUID();
        db.prepare(`INSERT INTO inspections (id,asset_id,assignee_id,title,asset_tag,asset_name,asset_location,due_at,created_at,updated_at,organization_id)
          VALUES (?,?,?,?,?,?,?,?,?,?,?)`).run(id,asset.id,input.assigneeId,input.title,asset.assetTag,asset.name,asset.location,input.dueAt ?? null,timestamp,timestamp,actor.organizationId);
        const insertCheck = db.prepare('INSERT INTO checklist_items (id,inspection_id,position,label,required) VALUES (?,?,?,?,?)');
        input.checklistItems.forEach((item,index) => insertCheck.run(randomUUID(),id,index,item.label,Number(item.required)));
        const insertReading = db.prepare(`INSERT INTO reading_definitions (id,inspection_id,position,label,unit,required,min_value,max_value) VALUES (?,?,?,?,?,?,?,?)`);
        input.readingDefinitions.forEach((item,index) => insertReading.run(randomUUID(),id,index,item.label,item.unit,Number(item.required),item.minValue,item.maxValue));
        return getInspection(id,actor)!;
      }).immediate();
    },
    listInspections(actor: Actor, options: ListOptions) {
      const access = scope(actor);
      const clauses = [access.sql]; const params: (string | number)[] = [...access.params];
      for (const [column,value] of [['status',options.status],['asset_id',options.assetId],['assignee_id',options.assigneeId]]) {
        if (value !== undefined) { clauses.push(`${column} = ?`); params.push(value); }
      }
      continuation(options,clauses,params);
      const rows = db.prepare(`SELECT ${inspectionColumns} FROM inspections WHERE ${clauses.join(' AND ')}
        ORDER BY created_at DESC,id DESC LIMIT ?`).all(...params) as InspectionRow[];
      return rows.map(summary);
    },
  };
}
