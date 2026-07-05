# Janavaani Error Log

This file records the major errors encountered during development, what caused them, how they were fixed, and how each fix was verified.

No secrets are included here. API keys, Firebase service account values, private keys, and connector tokens must stay only in local environment files or the hosting provider's secret manager.

---

## 1. Flutter web registration froze the browser tab

### Symptom

- Register screen showed a spinner forever.
- Chrome displayed **Page Unresponsive**.
- The app appeared stuck before reaching `/home`.
- Backend logs showed no meaningful matching error, which made it look like the backend was frozen.

### Root cause

On Flutter web, the Firebase Auth SDK call:

```dart
FirebaseAuth.instance.createUserWithEmailAndPassword(...)
```

could block the browser tab during registration. Earlier code also waited for Firebase plugin auth state before navigating, so the UI could hang even after credentials were accepted.

### Fix

- Changed web auth to use the Firebase Identity Toolkit REST API first.
- Kept Firebase plugin session sync as a background task only.
- Removed blocking waits from the register/login path.
- Added a lightweight `AuthSessionGate` so the router can treat the user as authenticated after the backend accepts the ID token.
- Kept backend auth token in `ApiService` instead of clearing it while Firebase plugin session is still syncing.

### Verification

- Backend `/health` stayed OK.
- Register/login no longer waits for plugin `currentUser`.
- App can route to `/home` after backend auth succeeds.

---

## 2. Login/register spinner caused by forced Firebase token refresh

### Symptom

- Login/register seemed successful but the app spinner stayed active.
- App sometimes bounced back to `/landing`.
- It looked like `/auth/me` or dashboard loading was stuck.

### Root cause

`auth_provider.dart` used:

```dart
user.getIdToken(true)
```

On Flutter web this force-refresh can hang. The app then waited for user-data loading and never finished rendering the authenticated state.

### Fix

- Replaced `getIdToken(true)` with `getIdToken(false)` and a timeout.
- Simplified post-login user-data refresh to a single provider invalidation.
- Avoided retry loops that repeatedly triggered token refresh.

### Verification

- `flutter analyze` on the changed auth files showed only existing non-blocking warnings.
- Backend health endpoints remained OK.
- App no longer relies on forced refresh immediately after auth.

---

## 3. Router bounced authenticated users back to landing

### Symptom

- Login/register appeared to complete.
- App navigated toward `/home`.
- Router immediately redirected to `/landing`.

### Root cause

The router guard checked only:

```dart
FirebaseAuth.instance.currentUser
```

On web, after REST auth, Firebase plugin state may not be immediately populated.

### Fix

- Added `AuthSessionGate`.
- Router now accepts either Firebase `currentUser` or the active backend session gate.
- Splash route also respects the session gate.

### Verification

- Web auth no longer depends on immediate Firebase plugin state.
- `/home` is allowed after backend auth succeeds.

---

## 4. Backend looked stuck, but all services were healthy

### Symptom

- Frontend spinner caused suspicion that the backend was down.
- User asked to check backend logs.

### Evidence

Health checks returned OK:

- `intake-api` on `8092`
- `enrich-worker` on `8081`
- `connectors` on `8082`
- `score-runner` on `8083`

### Root cause

The visible freeze was client-side Flutter web auth, not backend failure.

### Fix

- Fixed Flutter web auth flow as described above.
- Added `npm run verify:backend` to quickly verify backend health.

### Verification

`npm run verify:backend` checks:

- `GET /health`
- `GET /`
- `GET /api/v1/config`
- local worker health endpoints

---

## 5. Backend port mismatch

### Symptom

- App called one port while backend listened on another.
- Some requests returned 404 or connection errors.
- API root opened in the browser and looked like the wrong page.

### Root cause

Some files referenced `8080`, while local `.env` and Flutter web used `8092`.

### Fix

- Standardized local intake API on `8092`.
- Updated `.env.example`, `api_config.dart`, README, and dev scripts.
- API root now returns JSON explaining that it is the REST API, not the Flutter UI.

### Verification

- `http://localhost:8092/health` returns OK.
- Flutter uses `--dart-define=INTAKE_PORT=8092`.
- Debug screen shows the resolved API base URL.

---

## 6. Dead legacy routes caused 404s

### Symptom

- Some screens called endpoints that did not exist in the new backend.
- Browser console showed 404 errors.

### Root cause

The Flutter app still had compatibility methods and routes for older grievance-style endpoints:

- `/grievances`
- `/notifications`
- `/admin/*`
- `/department`
- `/map`

The Janavaani backend only exposes:

- `/auth/*`
- `/submissions`
- `/clusters`
- `/ingest`
- `/link`
- `/webhooks/whatsapp`
- `/config`

### Fix

- Demo path redirects unsupported legacy routes to `/home`, `/dashboard`, or `/hotspots`.
- Real demo screens use real backend endpoints:
  - Submit -> `POST /api/v1/submissions`
  - Priorities -> `GET /api/v1/clusters`
  - Profile -> `GET /api/v1/auth/me`

### Verification

- Demo navigation avoids nonexistent endpoints.
- API debug screen can verify `/health` and `/auth/me`.

---

## 7. Registration role escalation risk

### Symptom

Client-side registration allowed selecting privileged roles.

### Root cause

The register route originally trusted role values from the client.

### Fix

- Backend registration always creates/updates a `citizen`.
- MP/staff elevation is only possible through an authenticated MP-only endpoint:

```http
PUT /api/v1/auth/users/:uid/role
```

- Register screen was simplified to citizen-only.

### Verification

- Route tests cover registration role behavior.
- Register UI now states that staff roles are assigned by an administrator.

---

## 8. Connector ingest and WhatsApp verification fail-open risk

### Symptom

Connector and webhook routes could behave insecurely if tokens were missing.

### Root cause

Some checks skipped validation when secrets were unset.

### Fix

- `/api/v1/ingest` fails closed if `CONNECTOR_TOKEN` is missing or incorrect.
- WhatsApp verification fails closed if `WA_VERIFY_TOKEN` is missing or incorrect.

### Verification

- Added intake-api route tests for fail-closed behavior.

---

## 9. Over-broad submission reads

### Symptom

Citizens could potentially read more submissions than their own.

### Root cause

Submission read access was not scoped tightly enough for citizen users.

### Fix

- Citizens only read submissions matching their own `citizen_hash`.
- MP/staff roles can read all submissions.
- Firestore rules were aligned with API behavior.

### Verification

- Added tests for submission ownership and access behavior.

---

## 10. Identity linking could double-count citizens

### Symptom

Cross-channel identity linking could inflate `unique_citizens` in clusters.

### Root cause

Redeeming a link code rewrote `citizen_hash`, but cluster stats were not recomputed.

### Fix

- Identity link redemption now recomputes affected cluster `unique_citizens`.
- Cluster stats update after identity changes.

### Verification

- Added tests for identity-link de-duplication behavior.

---

## 11. Embedding dimension mismatch

### Symptom

Online and offline embeddings could become incomparable.

### Root cause

Offline fallback embeddings used a different dimension than the configured online embedding dimension.

### Fix

- Standardized fallback embeddings to `768` dimensions.
- Added guards in cosine similarity / centroid logic to reject cross-dimension comparisons.

### Verification

- Typecheck passed.
- Clustering tests passed.

---

## 12. Scoring and percentile inconsistency

### Symptom

Scoring percentile logic could drift between scripts/services.

### Root cause

Percentile math was implemented in more than one place.

### Fix

- Moved percentile math into shared schema helper `percentileIndex()`.
- Removed expensive p95 scanning from hot write paths.

### Verification

- Schema tests passed.
- Golden scoring tests passed.

---

## 13. Flutter Android build failed with `record_linux`

### Symptom

Running Flutter on a physical Android device failed during Gradle build with errors like:

```text
record_linux.dart: Error: The non-abstract class 'RecordLinux' is missing implementations
RecordMethodChannelPlatformInterface.startStream
```

### Root cause

The `record_linux` package version was incompatible with the resolved `record_platform_interface` version. This is a dependency version mismatch in the Flutter audio recording stack.

### Fix status

Not fixed yet. It is separate from backend deployment and web testing.

### Recommended fix

- Update the `record` package family to compatible versions.
- Run:

```bash
cd app
flutter pub upgrade record record_platform_interface
flutter clean
flutter pub get
flutter run
```

If that still fails, pin compatible versions in `pubspec.yaml`.

---

## 14. Too many terminal sessions and duplicate dev servers

### Symptom

Many stale terminal sessions were running old service commands.

### Root cause

Services had been started in multiple independent terminals while debugging.

### Fix

- Added a single-terminal dev stack using `concurrently`.
- Added:

```bash
npm run dev:stack
npm run stop:dev
```

- Removed stale terminal log files.

### Verification

All known local ports were checked:

- `5050`
- `8092`
- `8081`
- `8082`
- `8083`

---

## 15. Repo was too messy for deployment

### Symptom

Backend, Flutter app, legacy references, local folders, and deployment files were mixed together.

### Root cause

The project evolved quickly during debugging and needed a clean deployment-oriented structure.

### Fix

Restructured into:

```text
Janavaani/
├── app/
├── backend/
│   └── services/
├── docs/
└── package.json
```

Also removed:

- root empty `services/` folders
- deleted local-only reference folder
- excluded secrets and build artifacts in `.gitignore`

### Verification

- Backend tests passed after restructure.
- Initial GitHub push succeeded.
- Root README now documents `app/` and `backend/` separately.

---

## 16. Railway deployment was prepared, then hosting strategy changed

### Symptom

Railway was considered for backend hosting, but cost was a concern.

### Root cause

The backend has multiple always-running services. Railway can work, but usage-based billing may become costly.

### Fix / decision

- Added Railway config and docs for reference.
- Recommended Render or Cloud Run for backend.
- Recommended Vercel only for Flutter web/static frontend, not Express backend.

### Verification

`docs/DEPLOY.md` explains:

- why Vercel is not ideal for this backend as-is
- how to deploy backend on Render
- how to use Vercel for static Flutter web

---

## 17. Render free tier can sleep

### Symptom

Render free services sleep after idle time, causing slow first request.

### Root cause

Free tier web services are suspended after inactivity.

### Fix

Added:

- `backend/scripts/keepalive.js`
- `backend/render.yaml`

The keep-alive cron pings:

```text
GET /health
```

on both intake-api and enrich-worker every 10 minutes.

### Notes

- This helps for demos and testing.
- It may be against the spirit of some free-tier usage policies, so review Render terms before long-term use.
- For production reliability, use a paid always-on service or Cloud Run.

---

## 18. Previous-work references needed to be removed

### Symptom

Docs and platform files still contained old project names and origin references.

### Root cause

Some documentation and generated platform files retained old naming.

### Fix

- Deleted old reference folder.
- Removed old-origin mentions from architecture and build-prompt docs.
- Updated user-facing app names to Janavaani.
- Updated notification channels and in-app strings.

### Remaining technical note

Some low-level package/build identifiers may still need a careful rename before Play Store release, especially Android package ID. This must be coordinated with Firebase app registration and `google-services.json`.

---

## Current verification commands

Backend:

```bash
cd backend
npm install
npm run verify:backend
npm test
npm run typecheck
```

Flutter web:

```bash
cd app
flutter pub get
flutter run -d web-server --web-port=5050 --dart-define=INTAKE_PORT=8092
```

Render keep-alive test:

```bash
cd backend
INTAKE_API_URL=https://your-api.onrender.com ENRICH_WORKER_URL=https://your-enrich.onrender.com node scripts/keepalive.js
```

---

## Final stable local URLs

```text
Flutter web:    http://localhost:5050
intake-api:     http://localhost:8092/health
enrich-worker:  http://localhost:8081/health
connectors:     http://localhost:8082/health
score-runner:   http://localhost:8083/health
```

