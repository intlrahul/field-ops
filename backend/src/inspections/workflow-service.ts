import type { SqliteDatabase } from '../db/database.js';
import { currentActor, requireAction, type InspectionAction } from '../authorization/policy.js';
import { DomainError, notFound } from './errors.js';
import { inspectionStore } from './store.js';
import { workflowStore } from './workflow-store.js';
import type { Actor, ChecklistResultInput, InspectionDetail } from './types.js';

export function workflowService(db: SqliteDatabase, now: () => number = Date.now) {
  const inspections = inspectionStore(db);
  const writes = workflowStore(db);
  function mutate<T>(actor: Actor, id: string, action: InspectionAction, operation: (inspection: InspectionDetail, timestamp: string) => T): T {
    return db.transaction(() => {
      actor = currentActor(db,actor,now());
      const inspection = inspections.getInspection(id,actor) ?? notFound();
      requireAction(actor,inspection,action);
      return operation(inspection,new Date(now()).toISOString());
    }).immediate();
  }
  const detail = (id: string, actor: Actor) => inspections.getInspection(id,currentActor(db,actor,now()))!;
  return {
    start(actor: Actor, id: string) {
      return mutate(actor,id,'start',(inspection,timestamp) => {
        if (inspection.status === 'assigned') { writes.start(id,timestamp); writes.touch(id,timestamp); }
        return detail(id,actor);
      });
    },
    result(actor: Actor, id: string, itemId: string, input: ChecklistResultInput) {
      return mutate(actor,id,'edit_answers',(inspection,timestamp) => {
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
      return mutate(actor,id,'edit_readings',(inspection,timestamp) => {
        if (!Number.isFinite(value)) throw new DomainError(400,'INVALID_REQUEST','Reading must be a finite number');
        const item = inspection.readings.find(item => item.id === definitionId) ?? notFound();
        if (item.value !== value) { writes.reading(definitionId,value,actor.id,timestamp); writes.touch(id,timestamp); }
        return detail(id,actor);
      });
    },
    note(actor: Actor, id: string, text: string) {
      return mutate(actor,id,'add_note',(inspection,timestamp) => {
        const trimmed = text.trim();
        if (!trimmed || trimmed.length > 2000) throw new DomainError(400,'INVALID_REQUEST','Note must contain 1–2000 characters');
        const note = writes.note(id,trimmed,actor.id,timestamp); writes.touch(id,timestamp); return note;
      });
    },
    complete(actor: Actor, id: string) {
      return mutate(actor,id,'complete',(inspection,timestamp) => {
        writes.complete(id,timestamp); writes.touch(id,timestamp); return detail(id,actor);
      });
    },
  };
}
