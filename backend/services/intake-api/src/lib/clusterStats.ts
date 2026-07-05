import type { Firestore } from 'firebase-admin/firestore';

/** Recompute unique_citizens from member submission hashes (§3.1 / identity link). */
export async function recomputeClusterCitizenCounts(
  db: Firestore,
  clusterId: string,
): Promise<void> {
  const ref = db.collection('clusters').doc(clusterId);
  const clusterDoc = await ref.get();
  if (!clusterDoc.exists) return;

  const members = await db
    .collection('submissions')
    .where('cluster_id', '==', clusterId)
    .get();

  const citizenHashes = new Set<string>();
  for (const m of members.docs) {
    const hash = (m.data().citizen as { citizen_hash?: string })?.citizen_hash;
    if (hash) citizenHashes.add(hash);
  }

  const existing = clusterDoc.data()!;
  const stats = existing.stats as Record<string, unknown>;
  await ref.update({
    stats: {
      ...stats,
      submission_count: members.size,
      unique_citizens: citizenHashes.size,
    },
  });
}
