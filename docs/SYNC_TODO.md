# TODO: Offline synchronization and safe mutations

Status: deferred at the user's request. Discussion notes only; no sync endpoints or guarantees are implemented. Agree the contract before implementation. The existing online workflow remains available.

## Backend tasks

- [ ] Add client-generated operation IDs, with a defined user/resource scope, retention period, request fingerprint, and stored results.
- [ ] Atomically deduplicate mutations, apply writes, advance inspection versions, and record successful operation results. Check current authorization before replaying results; check for an already processed operation before comparing its expected version.
- [ ] Reject reuse of an operation ID with different content (proposed 409 OPERATION_ID_REUSED).
- [ ] Require expectedVersion for new mutations and return explicit conflicts (proposed 409 VERSION_CONFLICT with expected/current versions).
- [ ] Define whether failed operation outcomes are retained and how long retries remain supported.
- [ ] Design initial download, incremental download, pagination, consistent boundaries, and expired-cursor recovery.
- [ ] Write change entries atomically with domain mutations using a server-owned monotonic sequence; existing list cursors are not sync cursors.
- [ ] Return removal events/tombstones or equivalent reconciliation for deletion and loss of assignment/access. Filtering by current authorization alone cannot tell a previous assignee to remove cached data.
- [ ] Define conflict responses and deliberate resolution, including completion and immutable completed inspections.

## Proposed defaults — not yet agreed

One inspection-wide version, serialized uploads per inspection, full inspection snapshots plus removal events, and explicit conflict resolution while preserving pending local work. Defer automatic merging initially. Replayed operations require current resource authorization. Do not resolve conflicts using device timestamps alone or claim exactly-once network delivery.

Offline completion could be displayed as “completion pending sync” until the backend validates it. This was recommended but not confirmed before the user deferred the task. Local access after session expiry/revocation also remains undecided.

## iOS responsibilities to design with the user

- [ ] Durable pending operations and stable operation IDs across retries/restarts.
- [ ] Preserve edits on conflicts and provide a resolution UI.
- [ ] Reconcile acknowledgements and out-of-order responses without overwriting newer local state.
- [ ] Handle token expiry, access revocation, and removal of cached resources.

The user implements iOS; these are design tasks, not authorization to generate Swift code.

## Required failure-case tests

- [ ] Server commits but response is lost; retry has no duplicate effect.
- [ ] Same operation arrives repeatedly or concurrently, including with different content.
- [ ] Two clients edit from the same version; stale intent produces a conflict.
- [ ] Responses arrive out of order or the app restarts during synchronization.
- [ ] Assignment/access is revoked while a technician is offline.
- [ ] Download pagination overlaps mutations without silently losing changes.
- [ ] Cursor expires and the client safely rebuilds its authorized dataset.

Current limitations: versions increment but do not reject stale writes; notes can duplicate on retry; no incremental sync endpoint or offline mutation protocol exists. See INSPECTION_WORKFLOW.md for current behavior.
