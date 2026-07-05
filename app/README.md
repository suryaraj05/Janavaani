# People's Priorities — Flutter app

Citizen intake (voice-first, Telugu/Hindi/English) and MP/staff dashboard in one
role-gated codebase.

## Run locally

```bash
flutter pub get
flutter run
```

Point API calls at `intake-api` (default `http://localhost:8080` in
`lib/config/api_config.dart`). Start the backend from the repo root first.

## Key screens

| Route | Role | Purpose |
|-------|------|---------|
| `/submit` | citizen | Voice/text/photo submission, TTS confirm, offline queue |
| `/dashboard` | mp_staff, mp | Ranked clusters, E/D/V/R bars, why-panel |
| `/hotspots` | mp_staff, mp | OSM map of cluster centroids by score |

## Firebase

Register this app in your Firebase project and replace the campus-connect
placeholders in `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`,
and `lib/config/firebase_config.dart`.

Legacy campus-connect setup notes live in `../docs/legacy/campus-connect-app/`.
