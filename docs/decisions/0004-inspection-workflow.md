# ADR 0004: Atomic online inspection workflow

Status: implemented, 2026-10-15.

Assigned technicians submit work after explicitly starting an inspection. Supervisors review but cannot override completion. Completed inspections reject further mutations.

Completion evaluates persisted answers/readings and updates lifecycle, timestamps, and version inside one immediate SQLite transaction. Pure rules report every unmet requirement. Failed checks require item-specific explanations at completion; out-of-range readings remain saved but block completion. General notes cannot waive either requirement.

Distinct measurements append internal author/timestamp history; details expose the latest value. Checklist PUT replaces its current result/explanation; general notes append. Repeating an identical PUT or start while in progress is a no-op. Parent version advances once per actual change. A failed transaction advances nothing.

This provides database atomicity, not stale-intent detection or general retry guarantees. Different concurrent PUTs use the latest committed write. Retrying POST notes can duplicate them; repeated completion returns a read-only error. Idempotency keys, expected-version conflict checks, history APIs, and offline synchronization are separate work. See ../INSPECTION_WORKFLOW.md for the public contract and manual tests.
