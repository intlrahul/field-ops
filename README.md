# FieldOps

A learning-focused native iOS app for equipment inspections, backed by a TypeScript API. Technicians work through assigned inspections; supervisors manage assets and assignments. Offline synchronization is a later milestone.

The user implements iOS. Backend work proceeds in small, explained slices. See [working agreement](AGENTS.md), [context](docs/CONTEXT.md), [architecture](docs/ARCHITECTURE.md), and [plan](docs/PLAN.md).

## Local backend

Requires Node.js 24 LTS and npm. No Docker or database server required.

```sh
cd backend
npm ci
npm run dev
```

The server defaults to 127.0.0.1:3000 and creates backend/data/fieldops.sqlite when launched from backend/. Override DATABASE_PATH, HOST, or PORT through the process environment. Relative database paths resolve from the working directory. To use a physical iPhone on a trusted local network, explicitly set HOST=0.0.0.0; transport security must be designed before real credentials are used.

```sh
curl http://127.0.0.1:3000/health
npm run check
npm run build
npm start
```

GET /health checks database availability and returns {"status":"ok"}. Each startup applies pending migrations. Tests use temporary databases and remove them after closing connections.

## Current limits

Only the backend foundation exists. There are no user, asset, inspection, login, or seed endpoints yet. Do not use this as a production service. Seed accounts will arrive with real authentication; no sample passwords or authentication bypasses are provided now.

Repository layout: ios/ contains the existing iOS project; backend/ contains the API; docs/ holds the contract and persistent design context. CI is defined at .github/workflows/backend.yml. The full project is initialized as one Git repository at the workspace root, with origin https://github.com/intlrahul/field-ops.git. The previous nested ios/.git repository was removed at the user’s request. CI runs after the workflow is committed and pushed to GitHub.
