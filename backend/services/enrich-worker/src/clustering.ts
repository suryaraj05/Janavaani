import type { Firestore } from 'firebase-admin/firestore';
import { percentileIndex, computeInterimScore, allowedMandalCodes } from '@pp/schema';
import { cosineSimilarity, l2normalize } from './embedding.js';

/** Threshold bands (§4.2). */
export const AUTO_MERGE_THRESHOLD = 0.8;
export const PROVISIONAL_THRESHOLD = 0.65;
const CENTROID_FREEZE_N = 50;

export interface ClusterCandidate {
  cluster_id: string;
  mandal_code: string | null;
  embedding: number[];
}

export interface ClusterMatch {
  cluster_id: string;
  similarity: number;
  decided_by: 'auto' | 'staff_review';
}

/**
 * Pure vector-search step over pre-filtered candidates (testable without Firestore).
 * Returns null when no candidate clears the provisional band.
 */
export function pickClusterMatch(
  embedding: number[],
  candidates: ClusterCandidate[],
): ClusterMatch | null {
  let best: { cluster_id: string; similarity: number } | null = null;

  for (const c of candidates) {
    const similarity = cosineSimilarity(embedding, c.embedding);
    if (!best || similarity > best.similarity) {
      best = { cluster_id: c.cluster_id, similarity };
    }
  }

  if (!best) return null;
  if (best.similarity >= AUTO_MERGE_THRESHOLD) {
    return { ...best, decided_by: 'auto' };
  }
  if (best.similarity >= PROVISIONAL_THRESHOLD) {
    return { ...best, decided_by: 'staff_review' };
  }
  return null;
}

function tokenize(text: string): Set<string> {
  return new Set(
    text
      .toLowerCase()
      .replace(/[^a-z0-9\s]/g, ' ')
      .split(/\s+/)
      .filter((w) => w.length > 2),
  );
}

export function textSimilarity(a: string, b: string): number {
  const ta = tokenize(a);
  const tb = tokenize(b);
  if (ta.size === 0 || tb.size === 0) return 0;
  let intersection = 0;
  for (const t of ta) {
    if (tb.has(t)) intersection++;
  }
  return intersection / Math.sqrt(ta.size * tb.size);
}

/**
 * Incremental cluster assignment (§4.2). Hard pre-filter (category + mandal /
 * adjacent-mandal) before cosine similarity against centroid embeddings.
 */
export async function findMatchingCluster(
  db: Firestore,
  category: string,
  embedding: number[],
  opts: {
    mandalCode: string | null;
    geocodeConfidence: 'high' | 'medium' | 'low' | 'none';
  },
): Promise<ClusterMatch | null> {
  const allowed = allowedMandalCodes(opts.mandalCode, opts.geocodeConfidence);

  const snapshot = await db.collection('clusters').where('category', '==', category).limit(80).get();
  const candidates: ClusterCandidate[] = [];

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const clusterMandal = (data.admin_scope as { mandal_code?: string | null })?.mandal_code ?? null;
    if (allowed && clusterMandal && !allowed.has(clusterMandal)) continue;

    const centroidDoc = await db.collection('cluster_centroids').doc(doc.id).get();
    const centroid = centroidDoc.data()?.embedding as number[] | undefined;
    if (!centroid) continue;
    candidates.push({ cluster_id: doc.id, mandal_code: clusterMandal, embedding: centroid });
  }

  return pickClusterMatch(embedding, candidates);
}

/** Store/refresh a cluster's centroid embedding (running mean, frozen at n>50). */
export async function updateCentroid(
  db: Firestore,
  clusterId: string,
  category: string,
  mandalCode: string | null,
  embedding: number[],
): Promise<void> {
  const ref = db.collection('cluster_centroids').doc(clusterId);
  const doc = await ref.get();
  if (!doc.exists) {
    await ref.set({ cluster_id: clusterId, category, mandal_code: mandalCode, embedding, n: 1 });
    return;
  }
  const data = doc.data()!;
  const n = (data.n as number) ?? 1;
  if (n > CENTROID_FREEZE_N) return;
  const current = data.embedding as number[];
  if (current.length !== embedding.length) {
    await ref.set({ cluster_id: clusterId, category, mandal_code: mandalCode, embedding, n: 1 });
    return;
  }
  const merged = current.map((v, i) => (n * v + embedding[i]) / (n + 1));
  await ref.update({ embedding: l2normalize(merged), n: n + 1 });
}

export async function createCluster(
  db: Firestore,
  params: {
    category: string;
    subcategory: string;
    canonicalTitle: string;
    constituencyCode: string;
    mandalCode: string | null;
    point: { lat: number; lng: number } | null;
    source: string;
    language: string;
    citizenHash: string | null;
    now: string;
  },
): Promise<string> {
  const seq = Date.now().toString(36).slice(-5);
  const clusterId = `clu_${params.category.slice(0, 3)}_${seq}`;

  const cluster = {
    cluster_id: clusterId,
    canonical_title_en: params.canonicalTitle,
    category: params.category,
    subcategory: params.subcategory,
    admin_scope: {
      constituency_code: params.constituencyCode,
      mandal_code: params.mandalCode,
    },
    centroid_point: params.point,
    stats: {
      submission_count: 1,
      unique_citizens: params.citizenHash ? 1 : 0,
      unique_provisional: 0,
      sources: { [params.source]: 1 },
      simulated_count: 0,
      first_seen: params.now,
      last_activity: params.now,
      languages: [params.language],
    },
    score: {
      total: 0,
      demand: 0,
      evidence: 0,
      confidence: 0,
      recency: 1,
      evidence_available: false,
      computed_at: params.now,
    },
    anomaly_flags: [],
    has_existing_plan: false,
    linked_plan: null,
    lifecycle: {
      status: 'acknowledged',
      history: [{ action: 'created', by: 'system', at: params.now }],
    },
    review_queue: [],
  };

  await db.collection('clusters').doc(clusterId).set(cluster);
  return clusterId;
}

export async function updateClusterStats(
  db: Firestore,
  clusterId: string,
  params: {
    source: string;
    language: string;
    citizenHash: string | null;
    now: string;
    provisional: boolean;
  },
): Promise<void> {
  const ref = db.collection('clusters').doc(clusterId);
  const doc = await ref.get();
  if (!doc.exists) return;

  const data = doc.data()!;
  const stats = data.stats as Record<string, unknown>;
  const sources = (stats.sources as Record<string, number>) ?? {};
  sources[params.source] = (sources[params.source] ?? 0) + 1;

  const languages = new Set([...(stats.languages as string[]), params.language]);
  const submissionCount = ((stats.submission_count as number) ?? 0) + 1;

  let uniqueCitizens = (stats.unique_citizens as number) ?? 0;
  let uniqueProvisional = (stats.unique_provisional as number) ?? 0;

  if (params.citizenHash) {
    const existingSnap = await db
      .collection('submissions')
      .where('cluster_id', '==', clusterId)
      .where('citizen.citizen_hash', '==', params.citizenHash)
      .limit(1)
      .get();

    const isNewCitizen = existingSnap.empty;
    if (isNewCitizen) {
      if (params.provisional) uniqueProvisional += 1;
      else uniqueCitizens += 1;
    }
  }

  await ref.update({
    stats: {
      ...stats,
      submission_count: submissionCount,
      unique_citizens: uniqueCitizens,
      unique_provisional: uniqueProvisional,
      sources,
      languages: [...languages],
      last_activity: params.now,
    },
  });
}

export async function rescoreAllClusters(db: Firestore): Promise<void> {
  const snapshot = await db.collection('clusters').get();
  const uniqueCounts = snapshot.docs.map(
    (d) => (d.data().stats as { unique_citizens: number }).unique_citizens,
  );
  uniqueCounts.sort((a, b) => a - b);
  const p95 = uniqueCounts[percentileIndex(uniqueCounts.length, 0.95)] ?? 1;
  const now = new Date();

  const batch = db.batch();
  for (const doc of snapshot.docs) {
    const data = doc.data();
    const stats = data.stats as { unique_citizens: number; last_activity: string };
    const lastActivity = new Date(stats.last_activity);
    const daysSince = (now.getTime() - lastActivity.getTime()) / (1000 * 60 * 60 * 24);
    const interim = computeInterimScore(stats.unique_citizens, p95, daysSince);
    batch.update(doc.ref, {
      score: {
        total: interim.total,
        demand: interim.demand,
        evidence: 0,
        confidence: 0,
        recency: interim.recency,
        evidence_available: false,
        computed_at: now.toISOString(),
      },
    });
  }
  await batch.commit();
}
