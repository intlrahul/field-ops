export const inspectionSchema = `
CREATE TABLE assets (
 id TEXT PRIMARY KEY,
 asset_tag TEXT NOT NULL UNIQUE CHECK(length(asset_tag) BETWEEN 1 AND 40),
 name TEXT NOT NULL CHECK(length(trim(name)) > 0), location TEXT,
 created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
 version INTEGER NOT NULL DEFAULT 1 CHECK(version >= 1)
) STRICT;
CREATE TABLE inspections (
 id TEXT PRIMARY KEY, asset_id TEXT NOT NULL REFERENCES assets(id),
 assignee_id TEXT NOT NULL REFERENCES users(id), title TEXT NOT NULL,
 asset_tag TEXT NOT NULL, asset_name TEXT NOT NULL, asset_location TEXT,
 status TEXT NOT NULL DEFAULT 'assigned' CHECK(status IN ('assigned','in_progress','completed')),
 due_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
 started_at TEXT, completed_at TEXT, version INTEGER NOT NULL DEFAULT 1 CHECK(version >= 1)
) STRICT;
CREATE INDEX assets_page ON assets(created_at DESC,id DESC);
CREATE INDEX inspections_page ON inspections(created_at DESC,id DESC);
CREATE INDEX inspections_assignee_page ON inspections(assignee_id,created_at DESC,id DESC);
CREATE INDEX inspections_asset ON inspections(asset_id,assignee_id);
CREATE TABLE checklist_items (
 id TEXT PRIMARY KEY, inspection_id TEXT NOT NULL REFERENCES inspections(id),
 position INTEGER NOT NULL CHECK(position >= 0), label TEXT NOT NULL,
 required INTEGER NOT NULL CHECK(required IN (0,1)), UNIQUE(inspection_id,position)
) STRICT;
CREATE TABLE reading_definitions (
 id TEXT PRIMARY KEY, inspection_id TEXT NOT NULL REFERENCES inspections(id),
 position INTEGER NOT NULL CHECK(position >= 0), label TEXT NOT NULL, unit TEXT NOT NULL,
 required INTEGER NOT NULL CHECK(required IN (0,1)), min_value REAL, max_value REAL,
 CHECK(min_value IS NULL OR max_value IS NULL OR min_value <= max_value),
 UNIQUE(inspection_id,position)
) STRICT;
`;
