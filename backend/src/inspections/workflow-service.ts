import type { SqliteDatabase } from '../db/database.js';
import { DomainError, notFound } from './errors.js';
import { completionBlockers } from './rules.js';
import { inspectionStore } from './store.js';
import { workflowStore } from './workflow-store.js';
import type { Actor, ChecklistResultInput, InspectionDetail } from './types.js';

export function workflowService(db: SqliteDatabase, now: () => number = Date.now) {
  const inspections = inspectionStore(db);
  const writes = workflowStore(db);
  function mutate<T>(actor: Actor, id: string, operation: (inspection: InspectionDetail, timestamp: string) => T): T {
    if (actor.role !== 'technician') throw new DomainError(403,'FORBIDDEN','Only the assigned technician may update inspection work');
    return db.transaction(() => {
      const inspection = inspections.getInspection(id,actor) ?? notFound();
      if (inspection.status === 'completed') throw new DomainError(409,'INSPECTION_READ_ONLY','Completed inspections are read-only');
      return operation(inspection,new Date(now()).toISOString());
    }).immediate();
  }
  function requireStarted(inspection: InspectionDetail) {
    if (inspection.status !== 'in_progress') throw new DomainError(409,'INVALID_STATE','Start the inspection before recording work or completing it');
  }
  const detail = (id: string, actor: Actor) => inspections.getInspection(id,actor)!;
  return {
    start(actor: Actor, id: string) {
      return mutate(actor,id,(inspection,timestamp) => {
        if (inspection.status === 'assigned') { writes.start(id,timestamp); writes.touch(id,timestamp); }
        return detail(id,actor);
      });
    },
    result(actor: Actor, id: string, itemId: string, input: ChecklistResultInput) {
      return mutate(actor,id,(inspection,timestamp) => {
        requireStarted(inspection);
        const item = inspection.checklistItems.find(item => item.id === itemId) ?? notFound();
        const failureNote = input.failureNote?.trim() || null;
        if (input.result !== 'fail' && failureNote !== null) throw new DomainError(400,'INVALID_REQUEST','Failure notes require a failed result');
        if (item.result !== input.result || item.failureNote !== failureNote) {
          writes.result(id,itemId,{ result: input.result,failureNote }); writes.touch(id,timestamp);
        }
        return detail(id,actor);
      });
    },
    reading(actor: Actor, id: string, definitionId: string, value: number) {
      return mutate(actor,id,(inspection,timestamp) => {
        requireStarted(inspection);
        if (!Number.isFinite(value)) throw new DomainError(400,'INVALID_REQUEST','Reading must be a finite number');
        const item = inspection.readings.find(item => item.id === definitionId) ?? notFound();
        if (item.value !== value) { writes.reading(definitionId,value,actor.id,timestamp); writes.touch(id,timestamp); }
        return detail(id,actor);
      });
    },
    note(actor: Actor, id: string, text: string) {
      return mutate(actor,id,(inspection,timestamp) => {
        requireStarted(inspection);
        const trimmed = text.trim();
        if (!trimmed || trimmed.length > 2000) throw new DomainError(400,'INVALID_REQUEST','Note must contain 1–2000 characters');
        const note = writes.note(id,trimmed,actor.id,timestamp); writes.touch(id,timestamp); return note;
      });
    },
    complete(actor: Actor, id: string) {
      return mutate(actor,id,(inspection,timestamp) => {
        requireStarted(inspection);
        const blockers = completionBlockers(inspection.checklistItems,inspection.readings);
        if (blockers.length) throw new DomainError(422,'COMPLETION_BLOCKED','Inspection requirements are not satisfied',{ blockers });
        writes.complete(id,timestamp); writes.touch(id,timestamp); return detail(id,actor);
      });
    },
  };
}
