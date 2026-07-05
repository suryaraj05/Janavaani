# Janavaani — citizen voice → ranked, evidence-backed priorities

Monorepo with a **Flutter app** and a **TypeScript backend** (deploy backend to Railway; app calls the public API).

```
Janavaani/
├── app/          Flutter — citizen submit + MP dashboard (web / mobile)
├── backend/      Node.js services — intake-api, enrich-worker, score-runner, connectors
└── docs/         Architecture, deploy guides, current state
```

## Quick start

### Backend

```bash
cd backend
cp .env.example .env    # add Firebase + PEPPER + CONNECTOR_TOKEN
npm install
npm run dev:stack       # intake :8092, enrich :8081, score :8083, connectors :8082
npm run verify:backend
```

Deploy to Railway: [`docs/RAILWAY_DEPLOY.md`](docs/RAILWAY_DEPLOY.md)

### App

```bash
cd app
flutter pub get
flutter run -d web-server --web-port=5050 --dart-define=INTAKE_PORT=8092
# Production API:
# flutter run --dart-define=API_BASE_URL=https://your-app.up.railway.app
```

Open **http://localhost:5050**

## From repo root

```bash
npm run install:backend
npm run dev:backend
npm run dev:app          # separate terminal
```

## What gets deployed

| Piece | Where | Notes |
|-------|--------|------|
| **intake-api** | Railway (public) | REST + auth — point Flutter `API_BASE_URL` here |
| **enrich-worker** | Railway (private) | Triage, embed, cluster |
| **app** | Web / Play Store | No secrets in repo; Firebase web config only |

**Not in git:** `.env`, service account JSON, `node_modules`, `dist/`, `campus-connect/`

## Docs

- [`docs/CURRENT_STATE.md`](docs/CURRENT_STATE.md) — what works today
- [`docs/RAILWAY_DEPLOY.md`](docs/RAILWAY_DEPLOY.md) — backend deploy
- [`docs/peoples-priorities-architecture.md`](docs/peoples-priorities-architecture.md) — system design

Firebase project: `mpconnect-67f6c` · Constituency demo: `PC-MALKAJGIRI`
