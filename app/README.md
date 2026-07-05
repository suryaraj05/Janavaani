# Janavaani — Flutter app

Citizen intake (voice-first, Telugu/Hindi/English) and MP/staff dashboard.

## Run locally

```bash
flutter pub get
flutter run -d web-server --web-port=5050 --dart-define=INTAKE_PORT=8092
```

Start the backend first: `cd ../backend && npm run dev:stack`

Production API:

```bash
flutter run --dart-define=API_BASE_URL=https://your-api.onrender.com
```

## Key screens

| Route | Role | Purpose |
|-------|------|---------|
| `/submit` | citizen | Voice/text/photo submission, offline queue |
| `/home` → Priorities | all | Ranked clusters, E/D/V/R, map |
| `/debug` | dev | API health + auth check |

## Firebase

Project: `mpconnect-67f6c` — config in `lib/config/firebase_config.dart`.  
Enable **Email/Password** in Firebase Console before register/login.
