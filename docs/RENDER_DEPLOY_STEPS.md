# Janavaani backend — Render deploy (step by step)

Deploy **enrich-worker** first, then **intake-api**. Both use the `backend/` folder in the GitHub repo.

---

## Step 0 — Pre-flight (local)

```powershell
cd backend
npm run typecheck
npm test
powershell -ExecutionPolicy Bypass -File scripts/check-render-env.ps1
```

Push latest code to GitHub:

```powershell
cd ..
git add .
git commit -m "Prepare Render backend deploy"
git push origin main
```

---

## Step 1 — Create Render account

1. Open https://render.com
2. Sign up with **GitHub**
3. Authorize access to **`suryaraj05/Janavaani`**

---

## Step 2 — Deploy with Blueprint (recommended)

1. Render Dashboard → **New** → **Blueprint**
2. Connect repo **`Janavaani`**
3. Render detects **`render.yaml`** at repo root
4. When prompted, set these **secret** variables (same values for both services where applicable):

| Variable | Where to get it |
|----------|-----------------|
| `FIREBASE_PROJECT_ID` | `mpconnect-67f6c` |
| `FIREBASE_CLIENT_EMAIL` | Firebase service account JSON → `client_email` |
| `FIREBASE_PRIVATE_KEY` | Service account JSON → `private_key` (paste with `\n` or real newlines) |
| `PEPPER` | Your `backend/.env` |
| `CONNECTOR_TOKEN` | Your `backend/.env` |
| `GEMINI_API_KEY` | Your `backend/.env` (optional) |

5. Click **Apply** — Render creates:
   - `janavaani-enrich`
   - `janavaani-intake`

Wait until both show **Live** (first deploy ~5–10 min).

---

## Step 2 (alternative) — Manual deploy

### 2A — enrich-worker

1. **New** → **Web Service**
2. Repo: `Janavaani`
3. **Root Directory:** `backend`
4. **Name:** `janavaani-enrich`
5. **Runtime:** Node
6. **Build Command:**
   ```
   npm ci && npm run build -w @pp/schema && npm run build -w @pp/enrich-worker
   ```
7. **Start Command:**
   ```
   node services/enrich-worker/dist/index.js
   ```
8. **Health Check Path:** `/health`
9. **Instance type:** Free
10. Add env vars: `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`, `GEMINI_API_KEY`
11. **Create Web Service**

Copy the public URL, e.g. `https://janavaani-enrich.onrender.com`

### 2B — intake-api

Repeat with:

- **Name:** `janavaani-intake`
- **Build:**
  ```
  npm ci && npm run build -w @pp/schema && npm run build -w @pp/intake-api
  ```
- **Start:**
  ```
  node services/intake-api/dist/index.js
  ```
- **Extra env vars:** `PEPPER`, `CONNECTOR_TOKEN`, `CONSTITUENCY_CODE=PC-MALKAJGIRI`
- **`ENRICH_WORKER_URL`:** `https://janavaani-enrich.onrender.com` (no trailing slash)

---

## Step 3 — Fix ENRICH_WORKER_URL (if submissions fail)

Blueprint may set host without `https://`. On **janavaani-intake** → **Environment**:

```
ENRICH_WORKER_URL=https://janavaani-enrich.onrender.com
```

Save → manual redeploy.

---

## Step 4 — Verify deployment

Replace with your intake URL:

```powershell
$env:INTAKE_API_URL='https://janavaani-intake.onrender.com'
cd backend
npm run verify:backend
```

Or in browser:

- `https://YOUR-INTAKE.onrender.com/health` → `{"status":"ok","service":"intake-api",...}`
- `https://YOUR-INTAKE.onrender.com/api/v1/config` → JSON config

First request after idle may take **30–60 seconds** (cold start).

---

## Step 5 — Point Flutter app at Render

```bash
cd app
flutter run -d web-server --web-port=5050 --dart-define=API_BASE_URL=https://janavaani-intake.onrender.com
```

Or build:

```bash
flutter build web --dart-define=API_BASE_URL=https://janavaani-intake.onrender.com
```

---

## Step 6 — Keep services awake (optional)

Free tier sleeps after ~15 min idle.

**Option A:** UptimeRobot (free) — ping `/health` every 5 min on both URLs.

**Option B:** Render cron + `backend/scripts/keepalive.js` (see `backend/render.yaml` legacy cron section).

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Build fails `npm ci` | Check Render logs; ensure root dir is `backend` |
| Service crashes on start | Missing `FIREBASE_PRIVATE_KEY` — check newlines |
| `/health` 502 | Wait for deploy; check logs for Firebase init errors |
| `Failed to parse private key` / `DECODER routines::unsupported` | Wrong `FIREBASE_PRIVATE_KEY` format — see **Firebase key fix** below |
| Register works locally but not prod | Set Flutter `API_BASE_URL` to Render intake URL |
| Submissions hang | `ENRICH_WORKER_URL` must be full `https://...` enrich URL |
| CORS errors | intake-api already uses `cors()` — wrong API URL in app |

---

## Do NOT put on Render

- `infra/serviceAccountKey.json` (use env vars instead)
- `infra/Bigquery.json`
- Local `.env` file upload

Use Render **Environment** tab for secrets only.

---

## Firebase key fix (`Failed to parse private key`)

Build succeeds but deploy crashes with `DECODER routines::unsupported` → **`FIREBASE_PRIVATE_KEY` is malformed** on Render.

### Fix (2 minutes)

1. Locally run (prints values from your service account file — do not commit output):

   ```powershell
   cd backend
   npm run print:render-firebase-key
   ```

2. Render → **janavaani-intake** → **Environment** → edit **`FIREBASE_PRIVATE_KEY`**
3. **Delete** the current value completely
4. Paste **only** the `FIREBASE_PRIVATE_KEY` line from the script (starts with `-----BEGIN PRIVATE KEY-----\n`)
5. **Do not** wrap in extra quotes — Render adds its own
6. **Do not** paste the whole JSON file — only the private key string
7. Repeat for **janavaani-enrich** (same three Firebase vars)
8. **Save** → **Manual Deploy** on each service

### Common mistakes

| Mistake | Result |
|---------|--------|
| Pasted entire `serviceAccountKey.json` | Decoder error |
| Extra `"` quotes around the key | Decoder error |
| Real line breaks in Render textarea (sometimes) | Can work, but `\n` escaped form is safer |
| Key truncated / missing `END PRIVATE KEY` | Decoder error |

After fix, logs should show the server starting without Firebase errors, and `/health` returns 200.
