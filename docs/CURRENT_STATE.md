# People's Priorities — Current State

> Last updated: 2026-07-05  
> Firebase project: `mpconnect-67f6c`  
> Constituency demo: `PC-MALKAJGIRI`

This document is the single reference for what exists today, how to run it locally, what works, what was fixed, and what remains.

---

## 1. What this project is

**People's Priorities** is a voice-first, multilingual system that turns scattered citizen input (app, WhatsApp, YouTube, portal fixtures) into a **ranked, evidence-backed priorities list** for an MP constituency.

| Layer | Technology | Role |
|-------|------------|------|
| Mobile / web UI | Flutter (Riverpod, go_router, Dio) | Citizen submit + MP/staff dashboard |
| API gateway | `intake-api` (Express, TypeScript) | Auth, submissions, clusters, ingest, webhooks |
| Enrichment | `enrich-worker` | Gemini triage, geocode, embed, cluster assignment |
| Connectors | `connectors` | YouTube + fixture replay → intake ingest |
| Scoring | `score-runner` | Composite score (E/D/V/R), anomalies, justification |
| Contracts | `@pp/schema` (Zod) | Shared types, scoring math, env loading |
| Data | Firestore (+ optional BigQuery) | Submissions, clusters, users, centroids |

Design specs: [`docs/peoples-priorities-architecture.md`](peoples-priorities-architecture.md) · [`docs/peoples-priorities-review-and-build-prompt.md`](peoples-priorities-review-and-build-prompt.md)

---

## 2. Repository layout

```
MPconnect/
├── app/                          Flutter app (People's Priorities UI)
├── services/
│   ├── intake-api/               REST API, auth, ingest, WhatsApp webhook
│   ├── enrich-worker/            Triage + clustering pipeline
│   ├── connectors/               External source connectors
│   └── score-runner/             Batch scoring + justification
├── shared/schema/                @pp/schema — Zod + scoring helpers
├── evidence_specs/               YAML evidence indicator specs
├── fixtures/                     Seed submissions, UDISE sample, connector batches
├── scripts/                      seed, e2e, smoke, dev-local.ps1, load scripts
├── test/golden/                  Cross-language clustering golden tests
├── infra/                        Docker, Firestore rules, service account paths
├── docs/                         Architecture + deploy guides
├── SECURITY.md                   Secret hygiene + rotation checklist (in backend/)
```

---

## 3. Local development — URLs and ports

| Service | Port | URL / check |
|---------|------|-------------|
| **Flutter web app** | **5050** | http://localhost:5050 |
| intake-api | 8092* | http://localhost:8092/health |
| enrich-worker | 8081 | http://localhost:8081/health |
| connectors | 8082 | http://localhost:8082/health |
| score-runner | 8083 | http://localhost:8083/health |

\* **Current `.env` uses `INTAKE_PORT=8092`** because port 8080 is sometimes blocked on Windows.  
**Rule:** `INTAKE_PORT`, `INTAKE_API_URL`, and Flutter `--dart-define=INTAKE_PORT=…` must all match.

Docker Compose defaults to **8080** for intake (see `infra/docker-compose.yml`).

### One-command startup (Windows)

```powershell
npm run dev:local    # single terminal — all 5 services (Ctrl+C stops all)
npm run stop:dev     # stop everything on ports 5050, 8081–8092, 8083
```

Or run the stack directly:

```powershell
npm run dev:stack
```

Starts backend + Flutter in **one terminal** (no extra PowerShell windows). Wait ~30s, then open **http://localhost:5050**.

### Manual startup

```powershell
# Terminal 1–4 (repo root)
npm run dev:enrich
npm run dev:intake
npm run dev:score
npm run dev:connectors

# Terminal 5 — Flutter (persists after closing browser tab)
npm run dev:app
# → http://localhost:5050
```

### Seed demo data

```powershell
npm run prepare:demo   # seed + score + e2e verify (services must be running)
# or manually:
npm run seed
Invoke-RestMethod -Uri http://localhost:8083/run -Method POST
npm run e2e
```

---

## 3b. Live testing checklist (ready now)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Open http://localhost:5050 | Landing → Sign in / Register |
| 2 | Register with email + password (6+ chars) | Lands on `/home`, stays logged in |
| 3 | **Priorities** tab | 12 ranked clusters with E/D/V/R scores + justification |
| 4 | **Voice** FAB → enter text → Submit | Success message; submission queued/enriched |
| 5 | **Map** tab | Hotspots from cluster centroids |
| 6 | http://localhost:5050/#/debug | `/health` 200, `/auth/me` returns profile |

**Start everything:** `npm run dev:local` (one terminal)  
**Stop everything:** `npm run stop:dev`  
**Refresh data:** `npm run prepare:demo`

If login bounces to landing: hard-refresh the browser (Ctrl+Shift+R) after auth fixes.

---

## 4. Environment variables

Copy [`.env.example`](../.env.example) → `.env`. Never commit `.env`.

| Variable | Required | Purpose |
|----------|----------|---------|
| `FIREBASE_SERVICE_ACCOUNT_PATH` | Yes | Path to Admin SDK JSON (`infra/serviceAccountKey.json`) |
| `FIREBASE_PROJECT_ID` | Yes | `mpconnect-67f6c` |
| `PEPPER` | Yes (prod) | HMAC salt for `citizen_hash` |
| `INTAKE_PORT` | Yes | intake-api listen port |
| `INTAKE_API_URL` | Yes | Connectors POST target (must match `INTAKE_PORT`) |
| `CONNECTOR_TOKEN` | Yes (ingest) | Shared secret for `/api/v1/ingest` |
| `GEMINI_API_KEY` | Optional | Live triage/embeddings; offline mocks work without it |
| `ENRICH_WORKER_URL` | Yes | intake → enrich callback |
| `GOOGLE_APPLICATION_CREDENTIALS` | Optional | BigQuery loader SA (`infra/Bigquery.json`) |

Secrets gitignored: `.env`, `infra/serviceAccountKey.json`, `infra/Bigquery.json`

---

## 5. Firebase setup (required for login)

1. Project: **mpconnect-67f6c**
2. Enable **Authentication → Sign-in method → Email/Password**
3. Web app configured in `app/lib/config/firebase_config.dart`
4. Admin SDK: `infra/serviceAccountKey.json`

**Web demo is fully supported.** Android/iOS use placeholder appIds — run `flutterfire configure` before device builds.

### Auth flow (fixed)

1. Flutter → Firebase Auth (SDK-first; REST fallback on web if plugin fails)
2. Flutter → `POST /api/v1/auth/register|login` with `idToken`
3. Backend verifies token, writes `users/{uid}` in Firestore
4. App waits for `FirebaseAuth.instance.currentUser` before navigating to `/home` (router guard)
5. Authenticated calls use `Authorization: Bearer <idToken>`

Debug: open **http://localhost:5050/#/debug** — shows `baseUrl`, `/health`, `/auth/me`, Firebase user.

---

## 6. Backend API surface (intake-api)

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/health` | — | Liveness |
| GET | `/` | — | API info (not the UI) |
| GET | `/api/v1/config` | — | Departments, priorities (stub) |
| POST | `/api/v1/auth/register` | idToken in body | Create citizen profile |
| POST | `/api/v1/auth/login` | idToken in body | Login / auto-provision |
| GET | `/api/v1/auth/me` | Bearer | Current user profile |
| PUT | `/api/v1/auth/me` | Bearer | Update profile |
| PUT | `/api/v1/auth/users/:uid/role` | MP only | Elevate role |
| POST | `/api/v1/submissions` | Bearer | Citizen submit |
| GET | `/api/v1/submissions` | Bearer | Own submissions (citizen) or all (staff) |
| GET | `/api/v1/clusters` | Bearer | Ranked priority clusters |
| POST | `/api/v1/ingest` | `x-connector-token` | Connector ingest |
| POST | `/api/v1/link/whatsapp/start` | Bearer | Identity link code |
| * | `/api/v1/webhooks/whatsapp` | WA verify token | WhatsApp webhook |

Legacy grievance routes (`/grievances`, `/notifications`, etc.) are **not implemented** — Flutter redirects those screens to `/home`.

---

## 7. Flutter app — demo path

| Screen | Route | Backend |
|--------|-------|---------|
| Landing / login / register | `/landing`, `/login`, `/register` | Firebase + `/auth/*` |
| Home shell (tabs) | `/home` | — |
| Priorities dashboard | tab in shell | `GET /clusters` |
| Citizen submit | `/submit` | `POST /submissions` |
| Hotspot map | tab in shell | cluster data |
| Profile | tab in shell | `GET /auth/me` |
| API debug | `/debug` | `/health`, `/auth/me` |

Redirected (no 404): `/grievances`, `/notifications`, `/admin/*`, `/department`, `/map` → hotspots

---

## 8. Security hardening (implemented)

| Item | Status |
|------|--------|
| Registration cannot self-promote to `mp`/`mp_staff` | Done — always `citizen`; MP-only `PUT /auth/users/:uid/role` |
| Connector ingest fail-closed without `CONNECTOR_TOKEN` | Done — 503 |
| WhatsApp verify fail-closed without `WA_VERIFY_TOKEN` | Done |
| Submission read scoped by `citizen_hash` | Done — API + Firestore rules (staff-only direct reads) |
| Identity link de-dup `unique_citizens` | Done |
| Embedding dim 768 unified offline/online | Done |
| p95 via shared `percentileIndex()` | Done |
| `multer` 2.x | Done |
| `SECURITY.md` | Done |

---

## 9. Test and build status

```powershell
npm run typecheck   # all workspaces + scripts
npm test            # 28 tests (17 schema + 9 intake-api + 2 enrich + 2 golden)
npm run smoke       # live Gemini triage + ingest (needs keys)
npm run e2e         # Firestore invariant checks after seed+score
cd app && flutter test
```

---

## 10. Data pipeline (happy path)

```
Citizen submit (Flutter)
  → intake-api POST /submissions
  → enrich-worker (triage, embed, cluster match/create)
  → Firestore submissions + clusters
  → score-runner POST /run (composite score + justification)
  → Flutter GET /clusters (ranked dashboard)
```

Connectors: fixtures/YouTube → `POST /ingest` → same enrich path.

---

## 11. Known limitations

| Area | Notes |
|------|-------|
| Web-only demo | Mobile Firebase config is placeholder |
| Port 8080 | May be blocked on some Windows setups — use 8092 consistently |
| Flutter web server | Use `npm run dev:app` (web-server), not `-d chrome`, for stable localhost:5050 |
| YouTube connector | Needs `YOUTUBE_API_KEY` — otherwise fixture mode only |
| Evidence term E | UDISE fixtures exist; restart score-runner after path fixes |
| Legacy API methods | Still in `api_service.dart` for compile compat; demo path avoids them |
| ~100+ debug prints | Remaining in non-demo grievance screens (PART 4 cleanup) |

---

## 12. Key files reference

| File | Purpose |
|------|---------|
| `app/lib/config/api_config.dart` | Backend base URL (port 8092 default) |
| `app/lib/config/firebase_config.dart` | Firebase web/mobile options |
| `app/lib/utils/firebase_auth_helper.dart` | SDK-first auth + web REST fallback |
| `app/lib/utils/auth_nav.dart` | Post-login navigation waits for Firebase session |
| `app/lib/routes/app_router.dart` | go_router + auth guards |
| `services/intake-api/src/routes/auth.ts` | Register/login/me |
| `services/intake-api/src/app.ts` | Express app factory |
| `shared/schema/src/config.ts` | Scoring math, `percentileIndex` |
| `scripts/dev-local.ps1` | Windows local dev orchestration |
| `scripts/seed.ts` | Load fixture submissions + clusters |
| `scripts/e2e_verify.ts` | Post-seed invariant checks |
| `infra/firestore.rules` | Client-side Firestore security |
| `.env` | Local secrets (gitignored) |

---

## 13. Troubleshooting

| Symptom | Fix |
|---------|-----|
| Blank page at `:8092` | That's the API — use **http://localhost:5050** |
| Login succeeds then bounces to landing | Fixed: auth waits for `currentUser`; hot-restart app |
| Register/login spinner forever | Backend is usually fine — caused by `getIdToken(true)` hanging on Flutter web; hard-refresh (Ctrl+Shift+R) after fix |
| `Cannot reach backend` snackbar | Run `npm run dev:intake`; verify port matches `.env` |
| Empty dashboard | `npm run seed` then `POST http://localhost:8083/run` |
| Connector replay fails | Align `INTAKE_API_URL` with `INTAKE_PORT` |

---

## 14. Related documents

- [`README.md`](../README.md) — quick start
- [`SECURITY.md`](../SECURITY.md) — secret rotation
- [`CURSOR_FIX_PROMPT.md`](../CURSOR_FIX_PROMPT.md) — agent fix checklist
- [`docs/peoples-priorities-architecture.md`](peoples-priorities-architecture.md)
- [`docs/peoples-priorities-review-and-build-prompt.md`](peoples-priorities-review-and-build-prompt.md)
