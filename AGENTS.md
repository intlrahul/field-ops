# FieldOps working agreement

Read README.md, docs/CONTEXT.md, docs/ARCHITECTURE.md, and docs/PLAN.md before changing the backend. Consult docs/openapi.yaml before changing HTTP behavior.

- The user writes all iOS code. Do not create or modify Swift, Xcode projects, or iOS tests without an explicit request. Do not change ios/ as part of backend work.
- Teach decisions, trade-offs, and failure modes. Explain each small vertical slice before implementing it and report verification afterward.
- Inspect existing work and preserve it. Do not implement the entire backend in one pass.
- Backend: Node.js, strict TypeScript, Fastify, SQLite. Local development and integration tests must not require Docker.
- Use explicit SQL and focused database modules. Keep HTTP, application rules, and persistence separate where those responsibilities exist. Avoid generic repository or speculative database-portability frameworks.
- Run integration tests against isolated temporary file-backed SQLite databases with real migrations. Never use the development database for tests.
- Enforce authorization and business rules on the server. Do not implement placeholder authentication or invent cryptography.
- Maintain API examples, architecture decisions, setup instructions, and current context as behavior changes. Mark proposals and unresolved questions clearly.
- No secrets in source control. Run npm run check in backend/ after backend changes.
- Do not implement offline synchronization before agreeing its contract. Never claim exactly-once delivery or resolve conflicts solely using device time.
