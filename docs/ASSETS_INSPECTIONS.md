# Assets and assigned-inspection API

Status: implemented. The main contract is openapi.yaml, which includes the assets-inspections.openapi.json contract module. Workflow mutations are documented in INSPECTION_WORKFLOW.md.

## Scope and access

| Endpoint | Supervisor | Technician |
| --- | --- | --- |
| POST /assets | Create | 403 |
| GET /assets | List all | 403 |
| GET /assets/{id} | Read | Read only if assigned an inspection for this asset |
| POST /inspections | Create and assign | 403 |
| GET /inspections | List all | List own assignments only |
| GET /inspections/{id} | Read all | Read own assignments only |

Every endpoint requires an active session. Validate resource access in SQL/application operations, not by filtering already-paginated results or trusting a submitted user ID. A technician requesting another technician's resource receives 404, identical to a missing resource. Supervisor-only actions return 403 for technicians without revealing whether supplied resources exist.

## Fields and validation

All IDs are server-generated UUIDs. All exposed timestamps are server-owned UTC RFC 3339 strings. New records start at version 1; later mutations increment versions. A version field alone does not implement optimistic concurrency or safe retry behavior.

Asset: id, assetTag, name, location, createdAt, updatedAt, version. assetTag is a unique uppercase identifier matching [A-Z0-9-], 1–40 characters; duplicates return 409 ASSET_TAG_EXISTS. Name is nonblank and at most 120 characters. Location is optional, nullable, nonblank when supplied, and at most 200 characters; it is free text, not coordinates. Trim human-readable text before validating/persisting. Reject unexpected request fields. Normalize absent location to null in responses.

Inspection creation: assetId, assigneeId, title, optional dueAt, checklistItems, readingDefinitions. Title is nonblank, at most 160 characters. dueAt is null or an RFC 3339 timestamp with an explicit offset; normalize to UTC. Past dates are accepted (overdue work is valid). Asset must exist; assignee must be an active technician. assigneeId is required: no unassigned/draft lifecycle in this slice. Missing references or an inactive/non-technician assignee return 422 INVALID_ASSIGNMENT with a generic message.

Create 1–30 checklist items and 0–10 reading definitions. These limits keep nested requests within the current 16 KiB request-body limit for typical inputs; a body exceeding that limit still returns 413. Array order defines display order. Create parent, items, and definitions atomically; failure leaves no partial inspection.

Checklist definition: label (nonblank, at most 160 characters) and required (boolean). Response adds id, position (zero-based), result (null initially), and failureNote (null initially). Future results are pass/fail; failed results require a nonblank failureNote for completion, as agreed. Optional unanswered checks are not completion blockers.

Reading definition: label (nonblank, at most 120 characters), unit (nonblank, at most 24 characters), required (boolean), minValue and maxValue (finite numbers, each explicitly nullable). Require minValue <= maxValue when both are provided. Bounds are inclusive: equality is in range. A null bound means no limit on that side. Unit is fixed for the definition; no automatic conversions. Use ordinary finite JSON numbers/SQLite REAL for this learning product; exact decimal/metrology requirements would need a separate decision. Reject numeric strings and non-finite values rather than silently coercing them.

Reading response adds id, position, value (null initially), and rangeStatus (unrecorded initially; later in_range/out_of_range). A provided optional reading outside its bounds also blocks completion, consistent with the agreed rule that out-of-range readings block completion. Missing optional readings do not block completion. Reading PUTs retain internal measurement history and expose the latest value; see INSPECTION_WORKFLOW.md.

## Confirmed immutability boundaries

The user confirmed that each inspection's checklist and reading definitions freeze at creation. There is no definition-edit endpoint in this slice. The user also confirmed saving a snapshot of assetTag, name, and location into the inspection at creation so historical/completed inspection details cannot change if asset-edit APIs are added later. The standalone asset endpoint represents current equipment data; the nested inspection asset represents its snapshot.

Keep one assignee. Reassignment and asset edits are deferred; their future APIs must prohibit changes to completed inspections. Start/completion/result/readings/notes mutations are implemented; see INSPECTION_WORKFLOW.md. Completed inspections remain permanently read-only for both roles, as agreed.

Inspection summary: id, title, status, asset snapshot, assigneeId, dueAt, createdAt, updatedAt, version. Status is assigned on creation; future values are in_progress/completed. Detail adds checklistItems, readings, notes, startedAt, completedAt. Notes start as an empty array, lifecycle timestamps as null. A note contains id, authorId, text, and createdAt.

## Pagination and filtering

Both lists accept limit (default 20, range 1–100) and an opaque cursor. Sort by immutable (createdAt DESC, id DESC), using keyset pagination. Return {items, nextCursor}; nextCursor is null on the last page. No total count initially.

GET /inspections additionally accepts one status filter and assetId. Supervisors may filter by assigneeId; technicians cannot submit assigneeId (403), even their own ID. Their authorization predicate always selects the current user's assignments. Asset list has no search/filter initially.

Cursors encode the last sort tuple and effective filters. Invalid or filter-mismatched cursors return 400 INVALID_CURSOR. They are continuation hints, never authorization credentials. Validate and bind effective user scope on every request. Restart pagination when changing filters. Pages are not snapshot-isolated across requests: concurrent changes may change membership. This list cursor is not a future synchronization cursor.

## Examples

POST /assets body:

```json
{"assetTag":"PUMP-001","name":"Cooling pump","location":"Plant A"}
```

POST /inspections body (use real IDs returned by asset creation and the technician's /me):

```json
{
  "assetId":"6a5e2b75-fb27-4f21-86bd-a811bc7e7f14",
  "assigneeId":"1e9b4150-c922-4e75-b0cb-d5996501b857",
  "title":"Cooling pump safety inspection",
  "dueAt":"2026-10-20T09:00:00Z",
  "checklistItems":[{"label":"Inspect housing for cracks","required":true}],
  "readingDefinitions":[
    {"label":"Temperature","unit":"°C","required":true,"minValue":0,"maxValue":80}
  ]
}
```

Creation returns 201 with the full resource and a relative Location header. GET /inspections?status=assigned&limit=20 returns summaries:

```json
{
  "items":[{
    "id":"a5534af5-5362-46bc-b7d3-e6d2dc1b06c1",
    "title":"Cooling pump safety inspection",
    "status":"assigned",
    "asset":{
      "id":"6a5e2b75-fb27-4f21-86bd-a811bc7e7f14",
      "assetTag":"PUMP-001","name":"Cooling pump","location":"Plant A"
    },
    "assigneeId":"1e9b4150-c922-4e75-b0cb-d5996501b857",
    "dueAt":"2026-10-20T09:00:00.000Z",
    "createdAt":"2026-10-15T10:00:00.000Z",
    "updatedAt":"2026-10-15T10:00:00.000Z",
    "version":1
  }],
  "nextCursor":null
}
```

Supervisor technician discovery is not included yet. Use the seeded technician ID from /me during manual testing; add a supervisor-only technician directory when the assignment UI needs it. Never enumerate all users to technicians.

Errors keep the current {error:{code,message}} envelope. See the OpenAPI for 400/401/403/404/409/413/422/500 responses. POST creation has no idempotency contract yet: a lost response followed by retry may create a duplicate inspection. Do not wire these creates into an offline retry queue before the later idempotency slice.

## Implemented slices and acceptance

1. Assets: migration, create/list/detail, supervisor restrictions, technician asset visibility, uniqueness, cursor pagination. Technician visibility requires an assigned inspection; assets without authorized assignments return 404.
2. Inspections: atomic creation/assignment, checklist/reading snapshots, scoped list/details, seeded example inspection. Freeze and validate definitions server-side.

Verify with isolated SQLite integration tests: technician cannot create/list assets or read another assignment; supervisors see all; invalid assignees fail atomically; duplicate tags return 409; equal-timestamp pagination is deterministic; cursors cannot bypass access filters; fresh details have unanswered results/readings and no notes; snapshots stay stable. No iOS changes.

## Run and test manually

Existing local databases upgrade automatically on startup; no database deletion is needed. Run from backend/ using your existing .env:

```sh
npm run seed
npm run dev
```

The seed command adds DEMO-PUMP-001 and a demo safety inspection assigned to technician@fieldops.test. Reruns preserve existing accounts and avoid duplicating the demo data. If the seeded technician has been deactivated or changed to another role, no demo inspection is created. Seed does not reset that account.

Log in as the technician using the authentication walkthrough, then:

```sh
curl -i http://127.0.0.1:3000/inspections \
  -H 'Authorization: Bearer YOUR_TECHNICIAN_ACCESS_TOKEN'

curl -i http://127.0.0.1:3000/inspections/INSPECTION_ID_FROM_LIST \
  -H 'Authorization: Bearer YOUR_TECHNICIAN_ACCESS_TOKEN'
```

Log in as supervisor@fieldops.test to create an asset:

```sh
curl -i -X POST http://127.0.0.1:3000/assets \
  -H 'Authorization: Bearer YOUR_SUPERVISOR_ACCESS_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{"assetTag":"PUMP-002","name":"Second cooling pump","location":"Plant B"}'
```

Use its returned id and the technician's id from /me in the inspection-creation example above, submitted to POST /inspections with the supervisor bearer token. Calling POST /assets or GET /assets as a technician should return 403. Continue with INSPECTION_WORKFLOW.md to start, record results/readings/notes, and complete the inspection.
