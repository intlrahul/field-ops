import type { SqliteDatabase } from '../db/database.js';
import { currentActor, organizationWide, requireCapability } from '../authorization/policy.js';
import { DomainError, notFound } from './errors.js';
import { pagination, page } from './pagination.js';
import { inspectionStore } from './store.js';
import type { Actor, AssetInput, InspectionInput, ListQuery } from './types.js';

export function inspectionService(db: SqliteDatabase, now: () => number = Date.now) {
  const store = inspectionStore(db);
  const timestamp = () => new Date(now()).toISOString();
  return {
    createAsset(actor: Actor, input: AssetInput) {
      return db.transaction(() => {
        actor = currentActor(db,actor,now());
        requireCapability(actor,'assets.manage');
        return store.createAsset(input,timestamp(),actor);
      }).immediate();
    },
    getAsset(actor: Actor, id: string) { requireCapability(actor,'assets.read'); return store.getAsset(id,actor) ?? notFound(); },
    listAssets(actor: Actor, query: ListQuery) {
      requireCapability(actor,'assets.read');
      const scope = JSON.stringify(['assets',actor.id,actor.organizationId,organizationWide(actor)]);
      const options = pagination(query,scope);
      return page(store.listAssets(actor,options),options.limit,scope);
    },
    createInspection(actor: Actor, input: InspectionInput) {
      return db.transaction(() => {
        actor = currentActor(db,actor,now());
        requireCapability(actor,'inspections.create');
        requireCapability(actor,'inspections.assign');
        for (const reading of input.readingDefinitions) {
          if ((reading.minValue !== null && !Number.isFinite(reading.minValue))
            || (reading.maxValue !== null && !Number.isFinite(reading.maxValue))
            || (reading.minValue !== null && reading.maxValue !== null && reading.minValue > reading.maxValue)) {
            throw new DomainError(422,'INVALID_DEFINITION','Reading bounds must be finite and ordered');
          }
        }
        if (input.dueAt) {
          const date = new Date(input.dueAt);
          const calendar = input.dueAt.slice(0,10);
          const utcCalendar = new Date(`${calendar}T00:00:00.000Z`);
          if (!Number.isFinite(date.getTime()) || !Number.isFinite(utcCalendar.getTime())
            || utcCalendar.toISOString().slice(0,10) !== calendar) {
            throw new DomainError(400,'INVALID_REQUEST','Invalid due date');
          }
        }
        return store.createInspection({ ...input, dueAt: input.dueAt ? new Date(input.dueAt).toISOString() : null },timestamp(),actor);
      }).immediate();
    },
    getInspection(actor: Actor, id: string) { requireCapability(actor,'inspections.read'); return store.getInspection(id,actor) ?? notFound(); },
    inspectionStatistics(actor: Actor) { requireCapability(actor,'inspections.read'); return store.inspectionStatistics(actor); },
    listInspections(actor: Actor, query: ListQuery) {
      requireCapability(actor,'inspections.read');
      if (!organizationWide(actor) && query.assigneeId !== undefined) requireCapability(actor,'inspections.assign');
      const scope = JSON.stringify(['inspections',actor.id,actor.organizationId,organizationWide(actor),query.status ?? null,query.assetId ?? null,query.assigneeId ?? null]);
      const options = { ...pagination(query,scope), status: query.status,assetId: query.assetId,assigneeId: query.assigneeId };
      return page(store.listInspections(actor,options),options.limit,scope);
    },
  };
}
