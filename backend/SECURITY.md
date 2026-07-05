# Security notes — People's Priorities

## Secrets on disk

This project stores sensitive credentials in local files that are **gitignored**:

- `.env` / `.env.local` — API keys, HMAC pepper, connector tokens
- `infra/serviceAccountKey.json` — Firebase Admin service account
- `infra/Bigquery.json` — BigQuery loader service account

Never commit these files or paste their values into source code, tests, or documentation.

## Before any public demo

Rotate credentials that may have been used on a developer machine:

1. **Firebase** — create a new service account key in the Firebase/Google Cloud console, replace `infra/serviceAccountKey.json`, and disable the old key.
2. **Gemini API** — revoke and reissue the key at [Google AI Studio](https://aistudio.google.com/apikey).
3. **CONNECTOR_TOKEN** and **PEPPER** — generate new random values in `.env` and restart all services.
4. **WhatsApp** — rotate `WA_VERIFY_TOKEN` and `WA_TOKEN` if the webhook was exposed.

## Auth model

- Citizen registration always assigns the `citizen` role; elevation to `mp` / `mp_staff` requires an authenticated MP via `PUT /api/v1/auth/users/:uid/role`.
- Connector ingest (`POST /api/v1/ingest`) requires `CONNECTOR_TOKEN`; requests are rejected when it is unset.
- Submission reads are scoped by `citizen_hash` for citizens; staff roles may read all submissions via the API.

## Production checklist

- Set `NODE_ENV=production`
- Require `PEPPER` (the server throws if missing in production)
- Require `CONNECTOR_TOKEN` for ingest
- Do not run with default or committed example secrets
