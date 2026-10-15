# Inspection workflow

Implemented online workflow. See openapi.yaml and inspection-workflow.openapi.json for the executable contract. Existing databases receive migration 3 automatically; do not delete your database. No Docker or iOS changes are needed.

## Permissions and lifecycle

Only the assigned, active technician may start, record work, add notes, or complete an inspection. Supervisors create/assign inspections and read progress; they cannot submit technician work or override completion. Missing/inaccessible inspections or child IDs return 404; supervisors attempting workflow mutations receive 403.

Lifecycle: assigned → in_progress → completed. Explicit start is required before recording any work. Completed inspections are permanently read-only. Definitions and asset snapshots remain frozen at creation.

| Method and path | Request | Success |
| --- | --- | --- |
| POST /inspections/{id}/start | No body or {} | 200 full inspection |
| PUT /inspections/{id}/checklist-items/{itemId}/result | result and optional failureNote | 200 full inspection |
| PUT /inspections/{id}/readings/{readingId} | value | 200 full inspection |
| POST /inspections/{id}/notes | text | 201 created note |
| POST /inspections/{id}/complete | No body or {} | 200 full inspection |

All calls require Authorization: Bearer ACCESS_TOKEN and return Cache-Control: no-store. JSON bodies reject unexpected fields. State operations accept only no body or an empty JSON object; clients cannot submit completion overrides, status, versions, or timestamps.

## Checklist results

PUT replaces the result and its failure explanation. result is pass, fail, or null (clear/unanswer). failureNote is optional, nullable, trimmed, and at most 2000 characters. Omitting it clears an existing explanation. A nonblank failureNote with a non-failed result is rejected (400 INVALID_REQUEST).

A failed item can be saved without an explanation while work is in progress, but completion requires a nonblank explanation on every failed item, including optional items. General inspection notes do not count as item-specific explanations. Mandatory items must be answered; unanswered optional items are allowed.

## Readings

PUT requires a finite JSON number; numeric strings, null, non-finite values, submitted units, and definition changes are rejected. Units and inclusive bounds come from the frozen definition. A saved value below minValue or above maxValue is returned as out_of_range and retained even though completion is blocked. Null bounds are unlimited. Missing optional readings are allowed; provided optional out-of-range readings block completion too. No reading-clear endpoint exists in this slice.

Distinct replacements append immutable internal measurements with author and server timestamp. The detail API exposes only the latest value/rangeStatus; measurement-history APIs are deferred. A newer acceptable measurement satisfies completion without deleting prior abnormal values. This records what was submitted; it does not prove that an equipment issue was physically resolved. A separate issue/remediation workflow would require product design.

## Notes and timestamps

General notes are append-only, nonblank after trimming, and at most 2000 characters. Author ID comes from the authenticated session; clients cannot impersonate an author. Notes contain id, authorId, text, createdAt. Server insertion order resolves equal-timestamp ordering. There is no edit/delete endpoint.

Start sets startedAt. Completion sets completedAt. Every persisted workflow change increments inspection.version once and updates updatedAt, all using the injected server clock and UTC RFC 3339 timestamps. An identical PUT or a repeated start while already in_progress is a no-op: no version/timestamp change or duplicate measurement. These operations still reject a completed inspection.

## Completion and errors

Completion reads persisted work, validates it, transitions to completed, and advances the version in one immediate SQLite transaction. Any failure rolls back all state/version/timestamp changes. Completion cannot accept a client's claim that requirements are met.

A blocked completion returns 422:

```json
{
  "error": {
    "code": "COMPLETION_BLOCKED",
    "message": "Inspection requirements are not satisfied",
    "details": {
      "blockers": [
        {"code":"FAILURE_NOTE_REQUIRED","itemId":"a85a572b-3ef5-444e-97c5-884d18934871"},
        {"code":"READING_OUT_OF_RANGE","itemId":"cc22d3e5-91d5-4942-88f6-971c94d85220"}
      ]
    }
  }
}
```

Blocker codes: CHECKLIST_UNANSWERED, FAILURE_NOTE_REQUIRED, READING_REQUIRED, READING_INVALID, READING_OUT_OF_RANGE. itemId identifies the checklist item or reading definition. Invalid data is rejected at the API; completion also defensively checks numeric validity.

Other errors keep the existing envelope: 400 INVALID_REQUEST, 401 UNAUTHORIZED, 403 FORBIDDEN, 404 NOT_FOUND, 409 INVALID_STATE (not started), 409 INSPECTION_READ_ONLY (completed), 413 INVALID_REQUEST (body too large), 500 INTERNAL_ERROR. A repeated completion returns 409; it does not reopen or change the inspection.

## Manual walkthrough

From backend/ with your configured .env:

```sh
npm run seed
npm run dev
```

Log in as technician@fieldops.test using AUTHENTICATION.md. GET /inspections and GET /inspections/{id} to obtain the seeded inspection, checklist item ID, and reading ID. Replace placeholders below with actual IDs and your technician access token.

```sh
curl -i -X POST http://127.0.0.1:3000/inspections/INSPECTION_ID/start \
  -H 'Authorization: Bearer ACCESS_TOKEN'

curl -i -X PUT http://127.0.0.1:3000/inspections/INSPECTION_ID/checklist-items/ITEM_ID/result \
  -H 'Authorization: Bearer ACCESS_TOKEN' -H 'Content-Type: application/json' \
  -d '{"result":"fail","failureNote":"Cracked housing reported to supervisor"}'

curl -i -X PUT http://127.0.0.1:3000/inspections/INSPECTION_ID/readings/READING_ID \
  -H 'Authorization: Bearer ACCESS_TOKEN' -H 'Content-Type: application/json' \
  -d '{"value":90}'

curl -i -X POST http://127.0.0.1:3000/inspections/INSPECTION_ID/complete \
  -H 'Authorization: Bearer ACCESS_TOKEN'
```

The demo temperature maximum is 80. The last request should return 422 READING_OUT_OF_RANGE in error.details.blockers, despite the explained failed check. Record an acceptable measurement, add a general note, and complete:

```sh
curl -i -X PUT http://127.0.0.1:3000/inspections/INSPECTION_ID/readings/READING_ID \
  -H 'Authorization: Bearer ACCESS_TOKEN' -H 'Content-Type: application/json' \
  -d '{"value":80}'

curl -i -X POST http://127.0.0.1:3000/inspections/INSPECTION_ID/notes \
  -H 'Authorization: Bearer ACCESS_TOKEN' -H 'Content-Type: application/json' \
  -d '{"text":"Rechecked temperature after servicing"}'

curl -i -X POST http://127.0.0.1:3000/inspections/INSPECTION_ID/complete \
  -H 'Authorization: Bearer ACCESS_TOKEN'
```

Expect completed status, persisted answers/readings/notes, and completedAt. Further work mutations return 409. Rerunning seed does not reset a completed inspection; create a new inspection as supervisor to repeat the walkthrough.

## Retry and concurrency limits

Immediate transactions serialize workflow writes and make validation/completion atomic. They do not detect stale client intent: without expectedVersion, two distinct PUTs use the latest committed write. A retried older PUT can overwrite a newer value. Version fields are currently informational. POST notes can duplicate after a lost response; completion retried after success returns 409, so fetch details to reconcile. Do not use these endpoints as an offline mutation queue yet.

Client operation IDs, general idempotency, expected-version conflicts, sync cursors, tombstones, access changes while offline, and deliberate conflict resolution belong to the next synchronization milestone. HTTPS and optional Docker packaging remain deferred.
