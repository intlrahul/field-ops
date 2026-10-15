# Inspection rules

Status: inspection creation/list/details, frozen definitions, and asset snapshots are implemented. Result/reading/note/lifecycle mutations and completion enforcement are implemented; see INSPECTION_WORKFLOW.md.

## Checklist results

A failed check does not by itself prevent completion. Each failed item must have its own nonblank explanatory note attached to its result. A general inspection note does not substitute for this explanation. Mandatory checklist items must be answered before completion.

Example: a failed visual inspection with an explanation can satisfy completion requirements if every other requirement is met. A failed result without an explanation blocks completion.

## Readings

Save valid numeric measurements even when outside the configured operating range. Flag them as out of range and block completion while an out-of-range measurement remains. An explanatory note does not override this block. Invalid input differs from a valid out-of-range measurement; invalid data must not satisfy a required reading.

Example: a reading of 90 against a configured maximum of 80 is retained and flagged. Completion is blocked. Recording a subsequently acceptable measurement is distinct from rejecting or silently discarding the original out-of-range value; distinct measurements remain in internal append-only history; the current detail API exposes the latest value.

Missing or invalid required readings block completion.

## Definitions and lifecycle

Supervisors define checklist items directly per inspection. Checklist and reading definitions freeze when the inspection is created, for all roles. Results and measurements can subsequently be recorded through authorized workflow operations; definitions cannot be edited. Reusable templates are deferred.

Each inspection preserves an immutable snapshot of the asset’s tag, name, and location at creation. Later asset edits must not alter the inspection’s historical asset details.

Once completed, an inspection is read-only for everyone, including supervisors: no result changes, reading changes, added notes, definition edits, or reopening initially. Completion must validate persisted requirements and transition state atomically on the backend.

## Implemented workflow defaults

Only the assigned technician may submit work. Explicit start is required before results, readings, notes, or completion. Mandatory checks must be answered; every failure, including optional checks, requires a nonblank item-specific explanation for completion. Failed checks may be saved incomplete while drafting. General notes cannot substitute for failure explanations.

Bounds are inclusive; absent optional readings do not block completion, but any provided out-of-range reading does. Values are finite JSON numbers with fixed units. Internal measurement history preserves distinct replacements; only the latest measurement is exposed in details. Notes are append-only. Workflow changes increment the parent version atomically. See INSPECTION_WORKFLOW.md for state errors, retries, and limitations.

Reassignment, stale-write detection, idempotent note creation, history APIs, and synchronization remain deferred.

Do not infer an exception allowing completion of out-of-range readings. A waiver or supervisor override would require a separate product decision.
