# Janavaani — citizen voice → ranked, evidence-backed priorities

Monorepo with a **Flutter app** and a **TypeScript backend** (deploy API to Render/Cloud Run; app calls the public URL).

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

- [`docs/CURRENT_STATE.md`](docs/CURRENT_STATE.md) — what works today
- [`docs/DEPLOY.md`](docs/DEPLOY.md) — where to host backend + app
- [`docs/RAILWAY_DEPLOY.md`](docs/RAILWAY_DEPLOY.md) — Railway (optional)

### App

```bash
cd app
flutter pub get
flutter run -d web-server --web-port=5050 --dart-define=INTAKE_PORT=8092
# Production API:
# flutter run --dart-define=API_BASE_URL=https://your-api.onrender.com
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
| **intake-api** | Render / Cloud Run (public) | REST + auth — Flutter `API_BASE_URL` |
| **enrich-worker** | Same host, 2nd service | Internal URL → `ENRICH_WORKER_URL` |
| **Flutter web** | Vercel (optional) | `flutter build web` static files only |
| **Flutter mobile** | APK / Play Store | Same API URL |

## Deploy

See [`docs/DEPLOY.md`](docs/DEPLOY.md) — **Render or Cloud Run for backend**, Vercel for Flutter web only.

## Docs

- [`docs/CURRENT_STATE.md`](docs/CURRENT_STATE.md) — what works today
- [`docs/peoples-priorities-architecture.md`](docs/peoples-priorities-architecture.md) — system design

Firebase project: `mpconnect-67f6c` · Constituency demo: `PC-MALKAJGIRI`
