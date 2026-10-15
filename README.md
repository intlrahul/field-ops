# FieldOps

A learning-focused native iOS app for equipment inspections, backed by a TypeScript API. Technicians work through assigned inspections; supervisors manage assets and assignments. Offline synchronization is a later milestone.

The user implements iOS. Backend work proceeds in small, explained slices. See [working agreement](AGENTS.md), [context](docs/CONTEXT.md), [architecture](docs/ARCHITECTURE.md), and [plan](docs/PLAN.md).

## Local backend

Requires Node.js 24 LTS and npm. No Docker or database server required.

```sh
cd backend
npm ci
cp .env.example .env
# Fill AUTH_SECRET and seed passwords; see docs/AUTHENTICATION.md
npm run seed
npm run dev
```

Follow the [authentication setup](docs/AUTHENTICATION.md) to generate a random signing secret and choose development seed passwords.

The server defaults to 127.0.0.1:3000 and creates backend/data/fieldops.sqlite when launched from backend/. Override DATABASE_PATH, HOST, or PORT through the process environment. Relative database paths resolve from the working directory. To use a physical iPhone on a trusted local network, explicitly set HOST=0.0.0.0; transport security must be designed before real credentials are used.

```sh
curl http://127.0.0.1:3000/health
npm run check
npm run build
npm start
```

GET /health checks database availability and returns {"status":"ok"}. Each startup applies pending migrations. Tests use temporary databases and remove them after closing connections.

## Current limits

Health, authentication, assets, and assigned-inspection creation/list/details APIs are implemented. See [authentication behavior and curl examples](docs/AUTHENTICATION.md) and the [OpenAPI contract](docs/openapi.yaml). See the [assets and inspections walkthrough](docs/ASSETS_INSPECTIONS.md). Start, checklist results, readings, notes, and validated completion are also implemented; see the [workflow testing guide](docs/INSPECTION_WORKFLOW.md). Offline synchronization and conflict handling are pending. Docker and HTTPS setup are deferred; use loopback HTTP only for local development. Password reset, email verification, and distributed rate limiting are not implemented.

Repository layout: ios/ contains the existing iOS project; backend/ contains the API; docs/ holds the contract and persistent design context. CI is defined at .github/workflows/backend.yml. The full project is initialized as one Git repository at the workspace root, with origin git@github.com:intlrahul/field-ops.git. The previous nested ios/.git repository was removed at the user’s request. CI runs after the workflow is committed and pushed to GitHub.
