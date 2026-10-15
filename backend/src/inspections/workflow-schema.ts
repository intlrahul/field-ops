export const workflowSchema = `
ALTER TABLE checklist_items ADD COLUMN result TEXT CHECK(result IS NULL OR result IN ('pass','fail'));
ALTER TABLE checklist_items ADD COLUMN failure_note TEXT;
CREATE TABLE reading_measurements (
 sequence INTEGER PRIMARY KEY, id TEXT NOT NULL UNIQUE,
 definition_id TEXT NOT NULL REFERENCES reading_definitions(id),
 value REAL NOT NULL, author_id TEXT NOT NULL REFERENCES users(id), created_at TEXT NOT NULL
) STRICT;
CREATE INDEX measurements_latest ON reading_measurements(definition_id,sequence DESC);
CREATE TABLE inspection_notes (
 sequence INTEGER PRIMARY KEY, id TEXT NOT NULL UNIQUE,
 inspection_id TEXT NOT NULL REFERENCES inspections(id),
 author_id TEXT NOT NULL REFERENCES users(id), text TEXT NOT NULL CHECK(length(trim(text)) > 0), created_at TEXT NOT NULL
) STRICT;
CREATE INDEX notes_inspection ON inspection_notes(inspection_id,sequence);
`;
