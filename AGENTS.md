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

## Required iOS route-registration convention

Read docs/IOS_NAVIGATION.md and docs/decisions/0005-feature-owned-navigation.md before adding or changing routes. Existing restrictions on editing iOS without an explicit user request still apply.

- Define each screen once as a FeatureRoute in Features/<Feature>/Navigation/<Feature>Routes.swift. Keep its path, explicit parent, parameter validation, and deferred screen construction together.
- Add screens to an existing feature's registrations; add new features once in App/Navigation/AppRoutes.swift. Do not add screen switches, route lists, or feature-specific adapters to FieldOpsApp, AppComposition, or AppNavigation.
- AppComposition lives in App/Dependencies and owns shared dependency/lifecycle wiring. It may change for genuine shared dependency or app-action changes, not routine route registration. AppRoutes may use AppContainer; feature registrations receive explicit dependencies instead.
- Construct view models in deferred destination builders and let screens retain them in State. Inject app actions through NavigationActions; features must not depend on AppCoordinator or AppContainer.
- Use PathRouter for paths and deep links; do not create a parallel parser or pending-route store. Encode dynamic segments with RoutePath.encodeSegment, validate parameters in registrations, and declare actual screen parents explicitly.
- Keep loading/login outside the protected RouterStack. Preserve pending links through restoration/login; clear history and pending links on actual logout. Navigation guards do not replace backend authorization.
- Do not add a destination wrapper or per-feature factory merely for forwarding constructors. Retain factories/assemblies when they compose a meaningful dependency graph (as AuthFactory does).
- Verify relevant route resolution, auth handoff, back navigation, and logout behavior when changes affect them. Document manual gesture/cold-launch checks separately from automated test results.
