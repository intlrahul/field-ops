import type { SqliteDatabase } from '../db/database.js';
import { DomainError, notFound } from '../inspections/errors.js';
import { completionBlockers } from '../inspections/rules.js';
import type { InspectionDetail } from '../inspections/types.js';

export type Role = 'technician' | 'supervisor';
export type Capability = 'assets.read' | 'assets.manage' | 'inspections.read' | 'inspections.create' | 'inspections.assign' | 'inspections.perform' | 'templates.manage';
export type Actor = { id: string; role: Role; organizationId: string; sessionId?: string };
const roles: Record<Role, { capabilities: readonly Capability[]; readScope: 'assigned' | 'organization' }> = {
  technician: { capabilities: ['assets.read','inspections.read','inspections.perform'],readScope: 'assigned' },
  supervisor: { capabilities: ['assets.read','assets.manage','inspections.read','inspections.create','inspections.assign','inspections.perform'],readScope: 'organization' },
};
export function capabilities(role: Role): Capability[] { return [...roles[role].capabilities]; }
export function organizationWide(actor: Actor): boolean { return roles[actor.role].readScope === 'organization'; }
export function hasCapability(actor: Actor, capability: Capability): boolean { return roles[actor.role].capabilities.includes(capability); }
export function requireCapability(actor: Actor, capability: Capability): void {
  if (!hasCapability(actor,capability)) throw new DomainError(403,'FORBIDDEN','Permission required');
}
// Re-read mutable permissions inside write transactions; request/token claims are not authority.
export function currentActor(db: SqliteDatabase, actor: Actor, now = Date.now()): Actor {
  const user = db.prepare('SELECT id,role,organization_id AS organizationId,active FROM users WHERE id = ?').get(actor.id) as (Actor & { active: number }) | undefined;
  if (!user?.active || !user.organizationId) throw new DomainError(401,'UNAUTHORIZED','Authentication required');
  if (actor.sessionId && !db.prepare('SELECT id FROM sessions WHERE id = ? AND user_id = ? AND revoked_at IS NULL AND expires_at > ?')
    .get(actor.sessionId,actor.id,Math.floor(now / 1000))) throw new DomainError(401,'UNAUTHORIZED','Authentication required');
  return { id: user.id,role: user.role,organizationId: user.organizationId,sessionId: actor.sessionId };
}
export type InspectionAction = 'start' | 'edit_answers' | 'edit_readings' | 'add_note' | 'complete';
export function requirePerformer(actor: Actor, inspection: Pick<InspectionDetail,'organizationId' | 'assigneeId'>): void {
  requireCapability(actor,'inspections.perform');
  if (actor.organizationId !== inspection.organizationId) notFound();
  if (actor.id !== inspection.assigneeId) throw new DomainError(403,'FORBIDDEN','Inspection assignment required');
}
export function allowedActions(actor: Actor, inspection: InspectionDetail): InspectionAction[] {
  if (!hasCapability(actor,'inspections.perform') || actor.organizationId !== inspection.organizationId
    || actor.id !== inspection.assigneeId || inspection.status === 'completed') return [];
  if (inspection.status === 'assigned') return ['start'];
  const actions: InspectionAction[] = ['edit_answers','edit_readings','add_note'];
  if (completionBlockers(inspection.checklistItems,inspection.readings).length === 0) actions.push('complete');
  return actions;
}
export function requireAction(actor: Actor, inspection: InspectionDetail, action: InspectionAction): void {
  requirePerformer(actor,inspection);
  if (inspection.status === 'completed') throw new DomainError(409,'INSPECTION_READ_ONLY','Completed inspections are read-only');
  // Preserve the existing idempotent start retry (no new transition).
  if (action === 'start' && inspection.status === 'in_progress') return;
  if (allowedActions(actor,inspection).includes(action)) return;
  if (action === 'complete' && inspection.status === 'in_progress') {
    throw new DomainError(422,'COMPLETION_BLOCKED','Inspection requirements are not satisfied',{
      blockers: completionBlockers(inspection.checklistItems,inspection.readings),
    });
  }
  throw new DomainError(409,'INVALID_STATE','Start the inspection before recording work or completing it');
}
export function presentInspection(actor: Actor, inspection: InspectionDetail): InspectionDetail {
  return { ...inspection,allowedActions: allowedActions(actor,inspection),
    completionBlockers: inspection.status === 'completed' ? [] : completionBlockers(inspection.checklistItems,inspection.readings) };
}
