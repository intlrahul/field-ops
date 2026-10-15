import { readingStatus } from './rules.js';
import { randomUUID } from 'node:crypto';
import type { SqliteDatabase } from '../db/database.js';
import { DomainError } from './errors.js';
import type { Actor, Asset, AssetInput, InspectionInput, InspectionSummary, InspectionDetail, ListOptions, ChecklistItem, Reading, InspectionNote } from './types.js';

const assetColumns = `id, asset_tag AS assetTag, name, location, created_at AS createdAt, updated_at AS updatedAt, version`;
const inspectionColumns = `id, title, status, asset_id AS assetId, asset_tag AS assetTag, asset_name AS assetName,
 asset_location AS assetLocation, assignee_id AS assigneeId, due_at AS dueAt,
 created_at AS createdAt, updated_at AS updatedAt, version, started_at AS startedAt, completed_at AS completedAt`;
type InspectionRow = Omit<InspectionSummary,'asset'> & {
  assetId: string; assetTag: string; assetName: string; assetLocation: string | null;
  startedAt: string | null; completedAt: string | null;
};
function summary(row: InspectionRow): InspectionSummary {
  return { id: row.id, title: row.title, status: row.status,
    asset: { id: row.assetId, assetTag: row.assetTag, name: row.assetName, location: row.assetLocation },
    assigneeId: row.assigneeId, dueAt: row.dueAt, createdAt: row.createdAt, updatedAt: row.updatedAt, version: row.version };
}
function scope(actor: Actor) {
  return actor.role === 'supervisor' ? { sql: '1=1', params: [] as string[] }
    : { sql: 'assignee_id = ?', params: [actor.id] };
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
    const access = actor.role === 'supervisor' ? '' : ` AND EXISTS (
      SELECT 1 FROM inspections WHERE asset_id = assets.id AND assignee_id = ?)`;
    return db.prepare(`SELECT ${assetColumns} FROM assets WHERE id = ?${access}`)
      .get(...(actor.role === 'supervisor' ? [id] : [id,actor.id])) as Asset | undefined;
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
      return { ...summary(row), startedAt: row.startedAt, completedAt: row.completedAt, notes,
        checklistItems: checklist.map((item): ChecklistItem => ({ ...item,required: Boolean(item.required) })),
        readings: readings.map((item): Reading => ({ ...item,required: Boolean(item.required),rangeStatus: readingStatus(item.value,item) })) };
    })();
  }
  return {
    getAsset, getInspection,
    createAsset(input: AssetInput, timestamp: string): Asset {
      const id = randomUUID();
      try {
        db.prepare('INSERT INTO assets (id,asset_tag,name,location,created_at,updated_at) VALUES (?,?,?,?,?,?)')
          .run(id,input.assetTag,input.name,input.location ?? null,timestamp,timestamp);
      } catch (error) {
        if (error instanceof Error && 'code' in error && error.code === 'SQLITE_CONSTRAINT_UNIQUE') {
          throw new DomainError(409,'ASSET_TAG_EXISTS','Asset tag already exists');
        }
        throw error;
      }
      return getAsset(id,{ id: '',role: 'supervisor' })!;
    },
    listAssets(options: ListOptions) {
      const clauses = ['1=1']; const params: (string | number)[] = [];
      continuation(options,clauses,params);
      return db.prepare(`SELECT ${assetColumns} FROM assets WHERE ${clauses.join(' AND ')}
        ORDER BY created_at DESC,id DESC LIMIT ?`).all(...params) as Asset[];
    },
    createInspection(input: InspectionInput, timestamp: string): InspectionDetail {
      return db.transaction(() => {
        const asset = getAsset(input.assetId,{ id: '',role: 'supervisor' });
        const assignee = db.prepare("SELECT id FROM users WHERE id = ? AND role = 'technician' AND active = 1").get(input.assigneeId);
        if (!asset || !assignee) throw new DomainError(422,'INVALID_ASSIGNMENT','Valid asset and active technician required');
        const id = randomUUID();
        db.prepare(`INSERT INTO inspections (id,asset_id,assignee_id,title,asset_tag,asset_name,asset_location,due_at,created_at,updated_at)
          VALUES (?,?,?,?,?,?,?,?,?,?)`).run(id,asset.id,input.assigneeId,input.title,asset.assetTag,asset.name,asset.location,input.dueAt ?? null,timestamp,timestamp);
        const insertCheck = db.prepare('INSERT INTO checklist_items (id,inspection_id,position,label,required) VALUES (?,?,?,?,?)');
        input.checklistItems.forEach((item,index) => insertCheck.run(randomUUID(),id,index,item.label,Number(item.required)));
        const insertReading = db.prepare(`INSERT INTO reading_definitions (id,inspection_id,position,label,unit,required,min_value,max_value) VALUES (?,?,?,?,?,?,?,?)`);
        input.readingDefinitions.forEach((item,index) => insertReading.run(randomUUID(),id,index,item.label,item.unit,Number(item.required),item.minValue,item.maxValue));
        return getInspection(id,{ id: '',role: 'supervisor' })!;
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
