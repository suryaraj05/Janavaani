# Janavaani — deployment guide

## Short answer: Vercel for backend? **No — not without a rewrite.**

Janavaani’s backend is **four long-running Express services** (intake-api, enrich-worker, score-runner, connectors). They:

- Listen on ports and stay alive
- Call each other (`intake-api` → `enrich-worker` for every submission)
- Run Gemini triage/embeddings (can take many seconds)
- Use Firestore, multer uploads (25MB), and batch scoring

**Vercel** is built for **serverless functions** and static frontends — not multi-service Express. Putting this backend on Vercel would mean:

| Problem | Why it hurts |
|---------|----------------|
| **10–60s function timeout** | Enrichment + Gemini often exceeds limits |
| **No private service mesh** | enrich-worker can’t live as an internal sibling easily |
| **Cold starts** | First request after idle is slow |
| **4 services → 1 rewrite** | You’d need one serverless entry or a monolith refactor |

### What Vercel *is* good for

- **Flutter web** (static build): `flutter build web` → deploy `app/build/web` to Vercel
- **Not** the Node.js API as-is

---

## Recommended cheap stack

| Layer | Platform | Cost | Notes |
|-------|----------|------|--------|
| **Backend API** | [Render](https://render.com) | Free tier (sleeps after idle) | Docker or Node web service from `backend/` |
| **Enrich worker** | Render (2nd service) | Free tier | Private URL or env `ENRICH_WORKER_URL` |
| **Flutter web** | Vercel or Firebase Hosting | Free | Static files only |
| **Flutter mobile** | Play Store / APK | — | Points at public API URL |
| **Database** | Firebase (existing) | Spark free tier | Already using Firestore |

**Railway** works but usage-based billing adds up if services run 24/7. **Render free** spins down when idle — fine for demos/hackathons.

**Google Cloud Run** is also a strong fit (architecture doc target): scale-to-zero, same Dockerfiles as `backend/infra/Dockerfile`.

---

## Minimum production backend (2 services)

1. **intake-api** — public HTTPS URL (Flutter `API_BASE_URL`)
2. **enrich-worker** — internal URL only

Optional later: score-runner (cron `POST /run`), connectors (fixtures/YouTube).

---

## Keep Render free tier awake

Render free web services **sleep after 15 minutes** of no traffic. Cold start adds ~30–60s.

**Option A — Render Cron Job (included in `backend/render.yaml`):**
- `janavaani-keepalive` runs every **10 minutes**
- Pings `GET /health` on intake-api and enrich-worker
- Free tier cron — keeps both services warm during demos

**Option B — External ping (no Render cron):**
- [UptimeRobot](https://uptimerobot.com) free plan: monitor `https://your-intake.onrender.com/health` every 5 min
- [cron-job.org](https://cron-job.org): same URL every 10 min

**Option C — Paid Render ($7/mo per service):**
- Services never sleep — no keep-alive needed

> **Note:** Keep-alive only prevents sleep. First request after a long gap may still be slow if enrich-worker was also cold. Ping **both** services (intake + enrich) for reliable demos.

---

## Deploy backend on Render

**One-click (recommended):** Render → **New → Blueprint** → connect `Janavaani` repo → uses `backend/render.yaml` (intake + enrich + keep-alive cron).

### Manual: intake-api

1. Render → **New → Web Service** → connect `Janavaani` repo  
2. **Root directory:** `backend`  
3. **Build:** `npm install && npm run build -w @pp/schema && npm run build -w @pp/intake-api`  
4. **Start:** `node services/intake-api/dist/index.js`  
5. **Env vars:** copy from `backend/.env.example` (Firebase email/key, PEPPER, CONNECTOR_TOKEN, etc.)  
6. Set `PORT` (Render sets automatically) and `ENRICH_WORKER_URL` after worker is live  

Or use **Docker**: Dockerfile path `infra/Dockerfile`, build arg `SERVICE=intake-api`, context `backend`.

### enrich-worker

Same repo, second service:

- Build arg / start: `enrich-worker`  
- Start: `node services/enrich-worker/dist/index.js`  
- Copy `ENRICH_WORKER_URL` from Render’s internal URL or public URL into intake-api  

### Verify

```powershell
$env:INTAKE_API_URL='https://your-intake.onrender.com'
npm run verify:backend --prefix backend
```

---

## Deploy Flutter web on Vercel (optional)

```bash
cd app
flutter build web --dart-define=API_BASE_URL=https://your-intake.onrender.com
```

Vercel project:

- **Root directory:** `app`
- **Build command:** `flutter build web --dart-define=API_BASE_URL=...` (or use Vercel env)
- **Output directory:** `build/web`

---

## Environment variables (all platforms)

Never commit `.env`. On the host, set:

- `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`
- `PEPPER`, `CONNECTOR_TOKEN`, `CONSTITUENCY_CODE`
- `ENRICH_WORKER_URL` (intake-api only)
- `GEMINI_API_KEY` (optional — offline mocks work)

See `backend/.env.example`.

---

## Summary

| Your plan | Verdict |
|-----------|---------|
| Backend as its own repo folder | Done — `backend/` |
| Backend on Vercel | **Avoid** — wrong tool for Express microservices |
| Backend on Render / Cloud Run | **Recommended** — use existing Dockerfiles |
| App on Vercel | **Yes** — static Flutter web only |
| Railway | OK but often pricier for always-on services |

Next step: deploy **intake-api + enrich-worker** on Render, then set Flutter `API_BASE_URL` to the public intake URL.
