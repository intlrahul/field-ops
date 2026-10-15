# ADR 0003: Freeze inspection definitions and asset details at creation

Status: accepted and implemented, 2026-10-15.

Each inspection owns ordered checklist and reading definitions that cannot be edited after creation. It also stores the asset tag, name, and location at creation. Live assets remain separately addressable; inspection responses expose the historical snapshot. These boundaries were explicitly confirmed by the user.

Creation validates an active technician assignee and existing asset, then inserts the inspection and all definitions in one immediate SQLite transaction. No update methods or endpoints exist for definitions. Reusable templates, reassignment, and asset edits are deferred.

This duplicates a small amount of data to protect historical meaning and completion requirements from later equipment/catalog changes. A future template feature must copy its definitions into new inspections rather than make old inspections depend on mutable templates. Future mutation APIs must enforce completed-inspection immutability.

Version fields start at 1. Idempotency, optimistic concurrency, and sync cursors remain separate work; list pagination cursors provide none of those guarantees.
