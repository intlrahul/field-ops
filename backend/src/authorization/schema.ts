// Existing rows are assigned to the initial organization without rewriting historical migrations.
export const defaultOrganizationId = '00000000-0000-4000-8000-000000000001';
export const authorizationSchema = `
CREATE TABLE organizations (id TEXT PRIMARY KEY, name TEXT NOT NULL) STRICT;
INSERT INTO organizations VALUES ('${defaultOrganizationId}','FieldOps');
ALTER TABLE users ADD COLUMN organization_id TEXT REFERENCES organizations(id);
ALTER TABLE assets ADD COLUMN organization_id TEXT REFERENCES organizations(id);
ALTER TABLE inspections ADD COLUMN organization_id TEXT REFERENCES organizations(id);
UPDATE users SET organization_id = '${defaultOrganizationId}';
UPDATE assets SET organization_id = '${defaultOrganizationId}';
UPDATE inspections SET organization_id = '${defaultOrganizationId}';
CREATE INDEX assets_organization_page ON assets(organization_id,created_at DESC,id DESC);
CREATE INDEX inspections_organization_page ON inspections(organization_id,created_at DESC,id DESC);
CREATE INDEX inspections_organization_assignee ON inspections(organization_id,assignee_id,created_at DESC,id DESC);
CREATE TRIGGER users_org_insert BEFORE INSERT ON users WHEN NEW.organization_id IS NULL
BEGIN SELECT RAISE(ABORT,'Organization required'); END;
CREATE TRIGGER users_org_update BEFORE UPDATE OF organization_id ON users WHEN NEW.organization_id IS NULL
 OR EXISTS (SELECT 1 FROM inspections WHERE assignee_id = OLD.id AND organization_id != NEW.organization_id)
BEGIN SELECT RAISE(ABORT,'Invalid organization membership'); END;
CREATE TRIGGER assets_org_insert BEFORE INSERT ON assets WHEN NEW.organization_id IS NULL
BEGIN SELECT RAISE(ABORT,'Organization required'); END;
CREATE TRIGGER assets_org_update BEFORE UPDATE OF organization_id ON assets WHEN NEW.organization_id IS NOT OLD.organization_id
BEGIN SELECT RAISE(ABORT,'Asset organization is immutable'); END;
CREATE TRIGGER inspections_org_insert BEFORE INSERT ON inspections WHEN NEW.organization_id IS NULL
 OR NOT EXISTS (SELECT 1 FROM assets WHERE id = NEW.asset_id AND organization_id = NEW.organization_id)
 OR NOT EXISTS (SELECT 1 FROM users WHERE id = NEW.assignee_id AND organization_id = NEW.organization_id)
BEGIN SELECT RAISE(ABORT,'Invalid inspection organization'); END;
CREATE TRIGGER inspections_org_update BEFORE UPDATE OF organization_id,asset_id,assignee_id ON inspections
 WHEN NEW.organization_id IS NOT OLD.organization_id
 OR NOT EXISTS (SELECT 1 FROM assets WHERE id = NEW.asset_id AND organization_id = NEW.organization_id)
 OR NOT EXISTS (SELECT 1 FROM users WHERE id = NEW.assignee_id AND organization_id = NEW.organization_id)
BEGIN SELECT RAISE(ABORT,'Invalid inspection organization'); END;
`;
