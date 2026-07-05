# Deploy Janavaani backend to Railway

Deploy from the **`backend/`** directory in this repo.

## 1. Verify backend locally first

```powershell
cd backend
npm run dev:stack
npm run verify:backend
npm test
npm run typecheck
```

All four services should report `ok` on `/health`.

## 2. Railway project setup

1. Create a project at [railway.app](https://railway.app)
2. Connect your GitHub repo (`Janavaani`)
3. Set **Root Directory** to `backend` for each service (or use config paths below)
4. Create **two services**:

| Service | Config path | Docker build arg |
|---------|-------------|------------------|
| **intake-api** | `backend/infra/railway/intake-api/railway.toml` | `SERVICE=intake-api` |
| **enrich-worker** | `backend/infra/railway/enrich-worker/railway.toml` | `SERVICE=enrich-worker` |

In each service → **Settings → Build → Docker build args**, set:

```
SERVICE=intake-api
```

(or `enrich-worker` for the second service)

Railway injects `PORT` automatically — services listen on `process.env.PORT`.

## 3. Environment variables (intake-api)

Set in Railway **Variables** (never commit secrets):

| Variable | Required | Example |
|----------|----------|---------|
| `FIREBASE_PROJECT_ID` | Yes | `mpconnect-67f6c` |
| `FIREBASE_CLIENT_EMAIL` | Yes | from Firebase service account JSON |
| `FIREBASE_PRIVATE_KEY` | Yes | full key with `\n` for newlines |
| `PEPPER` | Yes | long random string |
| `CONNECTOR_TOKEN` | Yes | random secret for ingest |
| `GEMINI_API_KEY` | Optional | offline mocks work without it |
| `ENRICH_WORKER_URL` | Yes | private URL (step 4) |
| `CONSTITUENCY_CODE` | Yes | `PC-MALKAJGIRI` |

**Do not** set `FIREBASE_SERVICE_ACCOUNT_PATH` on Railway — use email + private key env vars instead.

Copy values from your local `.env` / `infra/serviceAccountKey.json` (client_email, private_key, project_id).

## 4. Wire enrich-worker (private networking)

1. Deploy **enrich-worker** first; confirm `/health` in Railway logs
2. In Railway → enrich-worker → **Settings → Networking** → enable private networking
3. On **intake-api**, set:

```
ENRICH_WORKER_URL=http://enrich-worker.railway.internal:<PORT>
```

Use the internal hostname and port shown in Railway (often the service's `PORT` variable).

4. Redeploy intake-api

## 5. Public URL for Flutter

1. intake-api → **Settings → Networking** → **Generate domain**
2. Test:

```powershell
$env:INTAKE_API_URL='https://YOUR-SERVICE.up.railway.app'
npm run verify:backend
```

## 6. Point Flutter at Railway (after deploy)

Web / mobile build:

```bash
flutter run --dart-define=API_BASE_URL=https://YOUR-SERVICE.up.railway.app
```

Or update `app/lib/config/api_config.dart` default for production builds.

## Optional services

| Service | Build arg | Purpose |
|---------|-----------|---------|
| score-runner | `SERVICE=score-runner` | `POST /run` to score clusters |
| connectors | `SERVICE=connectors` | YouTube/fixture ingest; set `INTAKE_API_URL` to intake public URL |

## CLI deploy (optional)

```powershell
npm i -g @railway/cli
railway login
railway link
railway up --service intake-api
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| intake-api crashes on start | Check Firebase env vars (private key newlines) |
| Submissions hang | `ENRICH_WORKER_URL` wrong — use private `.railway.internal` URL |
| 503 on `/ingest` | Set `CONNECTOR_TOKEN` on intake-api |
| CORS errors from Flutter web | intake-api already uses `cors()` — ensure Flutter uses correct `API_BASE_URL` |
