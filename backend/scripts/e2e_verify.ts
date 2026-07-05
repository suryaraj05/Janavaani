/**
 * E2E verification — reads Firestore after seed/score/ingest and asserts
 * flagship invariants (school-upgrade ranks above vocational, scores > 0).
 */
import { loadEnv } from '@pp/schema';
import admin from 'firebase-admin';
import { resolveFirebaseCredentials } from '@pp/schema';
import { mapClusterDoc, type ClusterDoc } from './types/cluster.js';

loadEnv();

const creds = resolveFirebaseCredentials();
if (!creds) {
  console.error('Firebase credentials missing');
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: creds.projectId,
      clientEmail: creds.clientEmail,
      privateKey: creds.privateKey,
    }),
  });
}

const db = admin.firestore();

async function main(): Promise<void> {
  const snap = await db.collection('clusters').get();
  const clusters: ClusterDoc[] = snap.docs
    .map((d) => mapClusterDoc(d.id, d.data()))
    .sort((a, b) => (b.score?.total ?? 0) - (a.score?.total ?? 0));

  console.log(`\nTop 5 clusters (${clusters.length} total):\n`);
  for (const c of clusters.slice(0, 5)) {
    const score = c.score ?? {};
    const stats = c.stats ?? {};
    const title = c.canonical_title_en?.slice(0, 55) ?? c.id;
    console.log(
      `#${clusters.indexOf(c) + 1} ${c.id} score=${score.total?.toFixed(1)} ` +
        `(D=${score.demand?.toFixed(2)} E=${score.evidence?.toFixed(2)} ` +
        `V=${score.confidence?.toFixed(2)} R=${score.recency?.toFixed(2)}) ` +
        `citizens=${stats.unique_citizens} subs=${stats.submission_count}`,
    );
    console.log(`   ${title}`);
    if (c.justification?.text_en) {
      console.log(`   why: ${c.justification.text_en.slice(0, 100)}…`);
    }
  }

  const school = clusters.find((c) => c.id === 'clu_edu_00042');
  const vocational = clusters.find((c) => c.id === 'clu_edu_voc01');

  const failures: string[] = [];
  if (!school) failures.push('missing flagship school cluster clu_edu_00042');
  if (!vocational) failures.push('missing vocational cluster clu_edu_voc01');
  if (clusters.length < 10) failures.push(`expected >=10 clusters, got ${clusters.length}`);

  const schoolScore = school?.score?.total ?? 0;
  const vocScore = vocational?.score?.total ?? 0;
  if (schoolScore <= vocScore) {
    failures.push(`school (${schoolScore}) should outrank vocational (${vocScore})`);
  }
  if (schoolScore <= 0) failures.push('school cluster score should be > 0');

  const withJustification = clusters.filter((c) => c.justification?.text_en).length;
  if (withJustification < 5) {
    failures.push(`expected justifications on most clusters, got ${withJustification}`);
  }

  const subCount = (await db.collection('submissions').count().get()).data().count;
  console.log(`\nSubmissions in Firestore: ${subCount}`);

  if (failures.length) {
    console.error('\nE2E VERIFY FAILED:');
    for (const f of failures) console.error(`  ✗ ${f}`);
    process.exit(1);
  }

  console.log('\nE2E VERIFY PASSED');
  console.log(`  ✓ ${clusters.length} clusters ranked`);
  console.log(`  ✓ school-upgrade (${schoolScore.toFixed(1)}) > vocational (${vocScore.toFixed(1)})`);
  console.log(`  ✓ ${withJustification} clusters have justification text`);
  console.log(`  ✓ ${subCount} submissions in Firestore`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
