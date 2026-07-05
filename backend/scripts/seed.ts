/**
 * Seed script — loads fixture submissions into Firestore and derives clusters
 * (+ centroid embeddings) from them, so a fresh project boots into a coherent
 * demo state. Run: npm run seed (requires Firebase credentials in .env).
 *
 * After seeding, run score-runner's POST /run to compute composite scores +
 * justifications over these clusters.
 */
import { loadEnv, findRepoRoot } from '@pp/schema';

loadEnv();
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import admin from 'firebase-admin';
import { embedText } from '../services/enrich-worker/src/embedding.js';
import { resolveFirebaseCredentials } from './lib/firebase_credentials.js';

const fixturesPath = join(findRepoRoot(), 'fixtures/submissions_seed.json');

interface SeedSubmission {
  submission_id: string;
  source: string;
  is_simulated: boolean;
  created_at: string;
  occurred_at: string;
  citizen: { citizen_hash: string | null };
  content: { original_language?: string };
  ai: {
    canonical_summary_en: string;
    category: string;
    subcategory: string;
  } | null;
  location: { point: { lat: number; lng: number } | null; admin: { constituency_code: string; mandal_code: string | null } };
  cluster_id: string | null;
  [key: string]: unknown;
}

function initFirebase() {
  const creds = resolveFirebaseCredentials();
  if (!creds) {
    console.error(
      'Missing Firebase Admin credentials.\n' +
        'Option A: set FIREBASE_CLIENT_EMAIL + FIREBASE_PRIVATE_KEY in .env\n' +
        'Option B: download service-account JSON to infra/serviceAccountKey.json\n' +
        '         and set FIREBASE_SERVICE_ACCOUNT_PATH=infra/serviceAccountKey.json',
    );
    process.exit(1);
  }

  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: creds.projectId,
      clientEmail: creds.clientEmail,
      privateKey: creds.privateKey,
    }),
  });
  return admin.firestore();
}

async function main() {
  const db = initFirebase();
  const fixtures = JSON.parse(readFileSync(fixturesPath, 'utf-8')) as SeedSubmission[];

  for (const submission of fixtures) {
    await db.collection('submissions').doc(submission.submission_id).set(submission);
  }
  console.log(`Seeded ${fixtures.length} submissions.`);

  // Group submissions into clusters and derive stats + centroid embeddings.
  const byCluster = new Map<string, SeedSubmission[]>();
  for (const s of fixtures) {
    if (!s.cluster_id || !s.ai) continue;
    const arr = byCluster.get(s.cluster_id) ?? [];
    arr.push(s);
    byCluster.set(s.cluster_id, arr);
  }

  for (const [clusterId, subs] of byCluster) {
    const first = subs[0];
    const citizens = new Set(subs.map((s) => s.citizen.citizen_hash).filter(Boolean));
    const sources: Record<string, number> = {};
    const languages = new Set<string>();
    let simulated = 0;
    let latSum = 0;
    let lngSum = 0;
    let points = 0;
    let firstSeen = subs[0].created_at;
    let lastActivity = subs[0].created_at;

    for (const s of subs) {
      sources[s.source] = (sources[s.source] ?? 0) + 1;
      if (s.content.original_language) languages.add(s.content.original_language);
      if (s.is_simulated) simulated++;
      if (s.location.point) {
        latSum += s.location.point.lat;
        lngSum += s.location.point.lng;
        points++;
      }
      if (s.created_at < firstSeen) firstSeen = s.created_at;
      if (s.created_at > lastActivity) lastActivity = s.created_at;
    }

    const now = new Date().toISOString();
    await db.collection('clusters').doc(clusterId).set({
      cluster_id: clusterId,
      canonical_title_en: first.ai!.canonical_summary_en,
      category: first.ai!.category,
      subcategory: first.ai!.subcategory,
      admin_scope: {
        constituency_code: first.location.admin.constituency_code,
        mandal_code: first.location.admin.mandal_code,
      },
      centroid_point: points > 0 ? { lat: latSum / points, lng: lngSum / points } : null,
      stats: {
        submission_count: subs.length,
        unique_citizens: citizens.size,
        unique_provisional: 0,
        sources,
        simulated_count: simulated,
        first_seen: firstSeen,
        last_activity: lastActivity,
        languages: [...languages],
      },
      score: {
        total: 0,
        demand: 0,
        evidence: 0,
        confidence: 0,
        recency: 1,
        evidence_available: false,
        computed_at: now,
      },
      anomaly_flags: [],
      lifecycle: { status: 'acknowledged', history: [{ action: 'seeded', by: 'system', at: now }] },
      review_queue: [],
    });

    const embedding = await embedText(first.ai!.canonical_summary_en);
    await db.collection('cluster_centroids').doc(clusterId).set({
      cluster_id: clusterId,
      category: first.ai!.category,
      mandal_code: first.location.admin.mandal_code,
      embedding,
      n: subs.length,
    });
    console.log(`Seeded cluster ${clusterId} (${subs.length} submissions, ${citizens.size} citizens)`);
  }

  console.log('Done. Next: start score-runner and POST /run to compute scores.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
