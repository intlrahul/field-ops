import { randomUUID } from 'node:crypto';
import type { SqliteDatabase } from '../db/database.js';
import type { ChecklistResultInput, InspectionNote } from './types.js';

export function workflowStore(db: SqliteDatabase) {
  return {
    touch(id: string, timestamp: string) {
      db.prepare('UPDATE inspections SET version = version + 1, updated_at = ? WHERE id = ?').run(timestamp,id);
    },
    start(id: string, timestamp: string) {
      db.prepare("UPDATE inspections SET status = 'in_progress',started_at = ? WHERE id = ?").run(timestamp,id);
    },
    complete(id: string, timestamp: string) {
      db.prepare("UPDATE inspections SET status = 'completed',completed_at = ? WHERE id = ?").run(timestamp,id);
    },
    result(inspectionId: string, itemId: string, input: ChecklistResultInput) {
      db.prepare('UPDATE checklist_items SET result = ?,failure_note = ? WHERE inspection_id = ? AND id = ?')
        .run(input.result,input.failureNote ?? null,inspectionId,itemId);
    },
    reading(definitionId: string, value: number, authorId: string, timestamp: string) {
      db.prepare('INSERT INTO reading_measurements (id,definition_id,value,author_id,created_at) VALUES (?,?,?,?,?)')
        .run(randomUUID(),definitionId,value,authorId,timestamp);
    },
    note(inspectionId: string, text: string, authorId: string, timestamp: string): InspectionNote {
      const note = { id: randomUUID(),text,authorId,createdAt: timestamp };
      db.prepare('INSERT INTO inspection_notes (id,inspection_id,text,author_id,created_at) VALUES (?,?,?,?,?)')
        .run(note.id,inspectionId,text,authorId,timestamp);
      return note;
    },
  };
}
