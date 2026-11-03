# ADR 0007: Capabilities with separate resource scope

Status: accepted and implemented, 2026-11-03.

Use two static role-to-capability mappings in the backend authorization policy. Keep scope separate: technicians read assigned resources, supervisors read their organization. Both roles may perform only their assignments. One organization membership per user initially. templates.manage is reserved, not granted while template APIs remain deferred.

Migration 4 backfills existing data into one default organization with foreign keys, ownership/assignment triggers, and organization indexes. Existing globally unique asset tags remain unchanged. No organization switch, role/profile administration, user-specific grants, or generic policy engine is introduced.

Return roles, organizationId and effective capabilities in the consistent login/refresh/me user shape while retaining legacy role. Return actor-specific allowedActions and completionBlockers on full inspection details. Shared policies govern advertised actions and actual workflow enforcement; mutation transactions reload current permissions/session state. Retain 401/403/404 concealment, lifecycle 409 and completion 422 distinctions. Idempotent start retries remain no-ops.

Authorization stays authoritative on the server, independent of UI feature flags and cached/offline permissions. See AUTHORIZATION.md for the contract, compatibility limits, migration behavior and tests. No iOS implementation is included.
