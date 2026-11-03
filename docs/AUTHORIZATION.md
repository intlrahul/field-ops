# Capability-based authorization

Status: implemented on the backend. SQLite migration 4 adds organizations and preserves existing data in the default FieldOps organization (00000000-0000-4000-8000-000000000001). The initial backend slice changed no iOS code; client integration is documented below. Restart the backend to migrate its configured database; do not delete or reset it.

## Capabilities and scope

Roles group capabilities in src/authorization/policy.ts. Each user has one primary role and one organization. `roles` is currently a one-element array; `role` remains for client compatibility. No per-user grants, public permission/profile endpoints, policy engine, or permission-management UI are introduced.

| Capability | Technician | Supervisor |
| --- | --- | --- |
| assets.read | Assets linked to own assignments | Own organization |
| assets.manage | No | Own organization; currently asset creation |
| inspections.read | Own assignments | Own organization |
| inspections.create | No | Own organization |
| inspections.assign | No | Eligible assignees in own organization |
| inspections.perform | Assigned inspections only | Assigned inspections only |
| templates.manage | Reserved, not granted | Reserved, not granted |

Template persistence/API is deferred. Do not advertise template management until it exists. Management capability names do not imply unimplemented edit/delete/reassign endpoints. Creating an inspection requires both create and assign. Eligible assignees are active same-organization users with inspections.perform, including supervisors. No supervisor override of assignment, organization, frozen definitions, read-only completed records, or completion validation exists.

Scope is a separate policy from capability membership. Every inspection list, detail, and statistics query binds organization plus assigned-only/organization-wide scope. Asset reads apply the corresponding scope; technicians can now list their visible assets. Children are accessed only through an authorized parent. Pagination cursors bind actor, organization, read scope, and filters; cursors themselves never authorize access. Old cursors may return INVALID_CURSOR after this change or a permission change; restart pagination.

Database foreign keys and triggers require organization membership, prevent cross-organization asset/assignee links, and prevent changing asset/inspection ownership. Membership transfer is unsupported while a user has assignments in another organization; there is no public transfer API. Historical globally unique asset tags are retained in this slice, so tag availability is global even though record visibility is organization-scoped. A tenant-local tag namespace would require a separate schema migration.

## Authentication responses

Login and refresh return the same user representation inside their existing token envelope. GET /me returns that representation directly:

```json
{
  "id": "0190b6c1-b11d-4db0-8891-124ddfa32784",
  "email": "technician@fieldops.test",
  "role": "technician",
  "roles": ["technician"],
  "organizationId": "00000000-0000-4000-8000-000000000001",
  "capabilities": ["assets.read", "inspections.read", "inspections.perform"]
}
```

Capabilities are derived from current database roles, never accepted from requests or embedded as authoritative JWT permission claims. Access tokens still identify user/session. Every protected HTTP request verifies session validity, revocation, active user, and current database membership/role. Write operations reload mutable authorization inside their immediate transaction, including session state when called through HTTP. Role changes, deactivation, assignment changes, and revocation affect subsequent checks without waiting for access-token expiry. Already committed operations are not undone. Code-based capability mapping changes take effect when the updated server runs.

## Inspection actions

Full inspection details, including create and workflow responses, add organizationId, allowedActions, and completionBlockers. Actions are computed for the requesting actor through the same policy used by workflow enforcement:

| State and actor | allowedActions |
| --- | --- |
| Assigned to actor, authorized performer | start |
| In progress, assigned performer | edit_answers, edit_readings, add_note |
| In progress, assigned performer, no completion blockers | Also complete |
| Readable but assigned to another user | Empty |
| Completed | Empty |

```json
{
  "status": "in_progress",
  "allowedActions": ["edit_answers", "edit_readings", "add_note"],
  "completionBlockers": [{"code": "READING_REQUIRED", "itemId": "8eeb69e7-715b-45a3-9914-3acbdadad62a"}]
}
```

Completion blockers reuse the existing pure checklist/reading rules. Empty blockers on an assigned inspection do not authorize completion before start. Completed inspections report no remaining blockers. edit_answers controls checklist result PUT; edit_readings controls reading value PUT. add_note controls note POST. Child IDs and input values are still validated independently.

Action metadata is a current snapshot, never a mutation credential. It is recomputed after work changes and checked again on each mutation. Existing repeated-start behavior is retained: start on an already in-progress assigned inspection is an accepted no-op even though a new start is no longer advertised. All other lifecycle restrictions apply normally.

## Errors and client responsibilities

- 401 UNAUTHORIZED: missing, expired, invalid, revoked authentication or inactive user.
- 403 FORBIDDEN: missing operation capability, or a readable inspection that the actor is not assigned to perform. Capability checks precede resource lookup at HTTP boundaries.
- 404 NOT_FOUND: missing resource, outside organization/read scope, or a child outside the authorized parent. Technicians cannot discover other assignments; supervisors cannot discover other organizations.
- 409 INVALID_STATE / INSPECTION_READ_ONLY: visible and assigned, but lifecycle prohibits the action.
- 422 COMPLETION_BLOCKED: completion requirements fail. INVALID_ASSIGNMENT uses the same generic 422 response for invalid, inactive, ineligible, or cross-organization references.
- 400 INVALID_REQUEST: attempts to submit server-owned permission/membership/action fields are rejected by request schemas.

Responses are additive: existing role and token fields remain. String arrays deliberately allow future capability/action names rather than using closed enums. Clients should use capabilities for general feature visibility and allowedActions for individual inspection actions, ignore unknown strings, and treat absent entries as unavailable. Cached permissions may be stale: display server denials and refresh profile/resource state. Feature flags are a separate concern and cannot authorize operations.

Offline synchronization is still deferred. Any queued work must be reauthorized against current organization, capability, assignment and lifecycle during synchronization; previously cached allowedActions never grant offline server access.

## Verification

npm run check uses temporary file-backed SQLite databases and real migrations, without Docker. Authorization tests cover consistent login/me/refresh, technician/supervisor assignment and scope, cross-organization read/write/assignment denial, statistics and cursor isolation, lifecycle/action agreement, permission changes with existing tokens and stale service actors, privilege-injection rejection, database constraints, and historical session/work preservation. Existing workflow/rule tests cover completion blockers, children, immutability, and rollback. Seed accounts remain in the default organization with capabilities derived from their roles. Existing seed work is preserved. No production/development database was used for tests.

## iOS integration

UserDTO and persisted User now retain raw roles/capability strings, organizationId and legacy role compatibility. Unknown strings do not fail decoding. Legacy cached users decode with an empty permission set; role names never infer UI grants. Login and refresh use the same DTO, so newly saved sessions preserve these fields automatically.

DefaultGetCurrentUserUseCase fetches authenticated GET /me through AuthRepository. Dashboard and status-list view models check that live profile before refreshing or loading more data; no inspection/statistics calls are made without inspections.read. Capability failures hide the feature and offer retry. A changed identity, organization, role set or capability set invalidates previous rows/cursors/totals; authorization failures clear access and discard late responses. A profile connectivity failure does not fall back to cached grants. Account/sign-out navigation remains available. No global coordinator/container environment or role-based UI switch was introduced.

InspectionDetailDTO retains allowedActions and completionBlockers as open strings. Detail view models expose typed checks for known actions and suppress them while loading or after errors; permission/not-found errors clear old details. Read-only/review messaging reflects current metadata. Work forms and mutation buttons are still a separate slice; no unsupported asset/template management navigation is advertised merely because its capability exists.

Permissions are not live-pushed: visible state can age until the next request/refresh. /me results used for screen visibility are not written over session credentials; cached session permission fields update on login/token refresh. The backend remains authoritative for each operation. Automatic token refresh after a 401 and offline synchronization remain outside this change. No feature flags are treated as permissions.

Frontend verification: generic-device app and test targets compile. Added tests cover unknown/missing permissions and actions, legacy user persistence, denied inspection requests, changed permissions clearing prior content, and revoked detail actions. Tests were compiled only, not executed; no simulator was launched. Manually verify login/restoration, pull-to-refresh, status-list links, unknown/missing permissions, server denials, and account access.
