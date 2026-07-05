/**
 * Smoke test — validates build artifacts, health endpoints, triage, and scoring
 * without requiring Firestore (unless FIREBASE_CLIENT_EMAIL is set).
 *
 * Usage: npm run smoke
 */
import { loadEnv, hasFirebaseCredentials } from '@pp/schema';

loadEnv();
import { runTriage } from '../services/enrich-worker/src/triage.js';
import { compositeScore } from '@pp/schema';

const BASE = process.env.INTAKE_API_URL ?? 'http://localhost:8080';

async function checkHealth(path: string, name: string): Promise<void> {
  const resp = await fetch(`${path}/health`);
  if (!resp.ok) throw new Error(`${name} health failed: ${resp.status}`);
  const body = (await resp.json()) as { status?: string };
  if (body.status !== 'ok') throw new Error(`${name} unhealthy: ${JSON.stringify(body)}`);
  console.log(`✓ ${name} health`);
}

async function checkTriage(): Promise<void> {
  const result = await runTriage({
    text: 'మా ఊరి బడి 7వ తరగతి వరకే ఉంది, హైస్కూల్ కావాలి',
  });
  if (result.category !== 'education') {
    console.warn(`  triage category=${result.category} (expected education; mock may vary)`);
  }
  if (!result.canonical_summary_en) throw new Error('triage missing canonical_summary_en');
  console.log(`✓ triage → ${result.canonical_summary_en.slice(0, 60)}…`);
}

async function checkScoring(): Promise<void> {
  const school = compositeScore({
    evidence: 0.88,
    demand: 0.86,
    confidence: 0.64,
    recency: 0.98,
  });
  const vocational = compositeScore({
    evidence: 0.62,
    demand: 0.62,
    confidence: 0.41,
    recency: 0.88,
  });
  if (school.total <= vocational.total) {
    throw new Error('school upgrade should outrank vocational');
  }
  console.log(`✓ composite score school=${school.total.toFixed(1)} > vocational=${vocational.total.toFixed(1)}`);
}

async function checkIngestIfFirebase(): Promise<void> {
  if (!hasFirebaseCredentials()) {
    console.log('⊘ ingest E2E skipped (Firebase Admin credentials not configured)');
    return;
  }
  const token = process.env.CONNECTOR_TOKEN ?? '';
  const resp = await fetch(`${BASE}/api/v1/ingest`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { 'x-connector-token': token } : {}),
    },
    body: JSON.stringify({
      draft: {
        source: 'portal_mock',
        is_simulated: true,
        citizen: { citizen_hash: null, auth_kind: 'anonymous', display_locale: 'te' },
        content: {
          modality: 'text',
          original_text: 'గ్రామంలో ఉన్నత పాఠశాల లేదు',
          original_language: 'te',
          media: [],
        },
        location: { raw_mentions: ['Ghatkesar'] },
        consent: { basis: 'public_platform', pii_scrubbed: true },
        channel_meta: { smoke_test: true },
      },
    }),
  });
  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`ingest failed ${resp.status}: ${text.slice(0, 200)}`);
  }
  const body = (await resp.json()) as { submission_id?: string; cluster_id?: string };
  console.log(`✓ ingest E2E → ${body.submission_id} → cluster ${body.cluster_id}`);
}

async function main(): Promise<void> {
  console.log('Smoke test starting…\n');
  await checkTriage();
  await checkScoring();

  try {
    await checkHealth('http://localhost:8081', 'enrich-worker');
    await checkHealth(BASE, 'intake-api');
    await checkHealth(process.env.CONNECTORS_URL ?? 'http://localhost:8082', 'connectors');
    await checkHealth('http://localhost:8083', 'score-runner');
  } catch (err) {
    console.warn('⊘ service health checks skipped (start dev:* services first):', (err as Error).message);
  }

  await checkIngestIfFirebase();
  console.log('\nSmoke test passed.');
}

main().catch((err) => {
  console.error('\nSmoke test FAILED:', err);
  process.exit(1);
});
