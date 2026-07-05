# Golden + integration tests

Per the repo layout spec, cross-service acceptance tests live here. Package-level
unit tests stay in each workspace (`shared/schema/test`, `services/*/test`).

| Path | What it checks |
|------|----------------|
| `golden/cross_language_clustering.test.ts` | Telugu/Hindi/English school demands cluster together; ITI stays separate (§4.3) |
| `labeled_pairs.example.csv` | Example input for `npm run eval:clustering` |

Run: `npm run test:golden` (also included in root `npm test`).
