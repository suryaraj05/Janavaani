import { Router } from 'express';
import { ulid } from 'ulid';
import type { Firestore } from 'firebase-admin/firestore';
import { getDb } from '../firebase.js';
import { requireAuth, requireRole } from '../middleware/auth.js';

const router = Router();

/** Recompute a cluster's stats + centroid from its member submissions (§3.1). */
async function recomputeClusterFromMembers(db: Firestore, clusterId: string): Promise<void> {
  const ref = db.collection('clusters').doc(clusterId);
  const clusterDoc = await ref.get();
  if (!clusterDoc.exists) return;

  const members = await db
    .collection('submissions')
    .where('cluster_id', '==', clusterId)
    .get();

  const citizenHashes = new Set<string>();
  const sources: Record<string, number> = {};
  const languages = new Set<string>();
  let simulatedCount = 0;
  let latSum = 0;
  let lngSum = 0;
  let pointCount = 0;
  let firstSeen = new Date().toISOString();
  let lastActivity = '1970-01-01T00:00:00.000Z';

  for (const m of members.docs) {
    const d = m.data();
    const hash = (d.citizen as { citizen_hash?: string })?.citizen_hash;
    if (hash) citizenHashes.add(hash);
    const src = d.source as string;
    sources[src] = (sources[src] ?? 0) + 1;
    const lang = (d.content as { original_language?: string })?.original_language;
    if (lang) languages.add(lang);
    if (d.is_simulated) simulatedCount++;
    const pt = (d.location as { point?: { lat: number; lng: number } })?.point;
    if (pt) {
      latSum += pt.lat;
      lngSum += pt.lng;
      pointCount++;
    }
    const created = d.created_at as string;
    if (created && created < firstSeen) firstSeen = created;
    if (created && created > lastActivity) lastActivity = created;
  }

  const existing = clusterDoc.data()!;
  await ref.update({
    stats: {
      ...(existing.stats as Record<string, unknown>),
      submission_count: members.size,
      unique_citizens: citizenHashes.size,
      sources,
      simulated_count: simulatedCount,
      languages: [...languages],
      first_seen: firstSeen,
      last_activity: lastActivity,
    },
    centroid_point:
      pointCount > 0 ? { lat: latSum / pointCount, lng: lngSum / pointCount } : existing.centroid_point,
  });
}

function appendHistory(existing: Record<string, unknown>, action: string, by: string) {
  const lifecycle = (existing.lifecycle as { status?: string; history?: unknown[] }) ?? {};
  return {
    status: lifecycle.status ?? 'acknowledged',
    history: [...(lifecycle.history ?? []), { action, by, at: new Date().toISOString() }],
  };
}

router.get('/', requireAuth, async (_req, res) => {
  try {
    const snapshot = await getDb().collection('clusters').limit(100).get();

    const clusters = snapshot.docs
      .map((doc) => doc.data())
      .sort(
        (a, b) =>
          ((b.score as { total?: number })?.total ?? 0) -
          ((a.score as { total?: number })?.total ?? 0),
      );
    res.json({ clusters });
  } catch (err) {
    console.error('GET /clusters error:', err);
    res.status(500).json({ error: 'Failed to fetch clusters' });
  }
});

router.get('/:id', requireAuth, async (req, res) => {
  const id = String(req.params.id);
  const doc = await getDb().collection('clusters').doc(id).get();
  if (!doc.exists) {
    res.status(404).json({ error: 'Cluster not found' });
    return;
  }
  res.json({ cluster: doc.data() });
});

router.patch(
  '/:id/lifecycle',
  requireAuth,
  requireRole('mp_staff', 'mp'),
  async (req, res) => {
    const { status, by } = req.body as { status?: string; by?: string };
    if (!status) {
      res.status(400).json({ error: 'status is required' });
      return;
    }

    const clusterId = String(req.params.id);
    const ref = getDb().collection('clusters').doc(clusterId);
    const doc = await ref.get();
    if (!doc.exists) {
      res.status(404).json({ error: 'Cluster not found' });
      return;
    }

    const data = doc.data()!;
    const history = [
      ...(data.lifecycle?.history ?? []),
      { action: `status:${status}`, by: by ?? req.user?.uid ?? 'staff', at: new Date().toISOString() },
    ];

    await ref.update({
      'lifecycle.status': status,
      'lifecycle.history': history,
    });

    const updated = await ref.get();
    res.json({ cluster: updated.data() });
  },
);

/** Reassign one submission to another cluster; pin it against auto-remerge (§3.1). */
router.post(
  '/reassign',
  requireAuth,
  requireRole('mp_staff', 'mp'),
  async (req, res) => {
    const { submission_id, to_cluster_id } = req.body as {
      submission_id?: string;
      to_cluster_id?: string;
    };
    if (!submission_id || !to_cluster_id) {
      res.status(400).json({ error: 'submission_id and to_cluster_id are required' });
      return;
    }

    const db = getDb();
    const subRef = db.collection('submissions').doc(submission_id);
    const subDoc = await subRef.get();
    if (!subDoc.exists) {
      res.status(404).json({ error: 'Submission not found' });
      return;
    }
    const fromClusterId = subDoc.data()!.cluster_id as string | null;

    await subRef.update({
      cluster_id: to_cluster_id,
      cluster_assignment: {
        similarity: 1,
        decided_by: 'staff_repair',
        pinned: true,
        at: new Date().toISOString(),
      },
    });

    const by = req.user?.uid ?? 'staff';
    if (fromClusterId) {
      const fromRef = db.collection('clusters').doc(fromClusterId);
      const fromDoc = await fromRef.get();
      if (fromDoc.exists) {
        await fromRef.update({
          lifecycle: appendHistory(fromDoc.data()!, `reassign_out:${submission_id}`, by),
        });
        await recomputeClusterFromMembers(db, fromClusterId);
      }
    }
    const toRef = db.collection('clusters').doc(to_cluster_id);
    const toDoc = await toRef.get();
    if (toDoc.exists) {
      await toRef.update({
        lifecycle: appendHistory(toDoc.data()!, `reassign_in:${submission_id}`, by),
      });
    }
    await recomputeClusterFromMembers(db, to_cluster_id);

    res.json({ ok: true, from: fromClusterId, to: to_cluster_id });
  },
);

/** Split a set of submissions off into a new cluster (§3.1). */
router.post('/:id/split', requireAuth, requireRole('mp_staff', 'mp'), async (req, res) => {
  const sourceClusterId = String(req.params.id);
  const { submission_ids } = req.body as { submission_ids?: string[] };
  if (!submission_ids?.length) {
    res.status(400).json({ error: 'submission_ids array is required' });
    return;
  }

  const db = getDb();
  const srcDoc = await db.collection('clusters').doc(sourceClusterId).get();
  if (!srcDoc.exists) {
    res.status(404).json({ error: 'Cluster not found' });
    return;
  }
  const src = srcDoc.data()!;
  const newClusterId = `clu_${(src.category as string).slice(0, 3)}_${ulid().slice(-6).toLowerCase()}`;
  const now = new Date().toISOString();
  const by = req.user?.uid ?? 'staff';

  const firstSub = await db.collection('submissions').doc(submission_ids[0]).get();
  const title =
    (firstSub.data()?.ai as { canonical_summary_en?: string })?.canonical_summary_en ??
    `${src.canonical_title_en} (split)`;

  await db.collection('clusters').doc(newClusterId).set({
    cluster_id: newClusterId,
    canonical_title_en: title,
    category: src.category,
    subcategory: src.subcategory,
    admin_scope: src.admin_scope,
    centroid_point: src.centroid_point ?? null,
    stats: {
      submission_count: 0,
      unique_citizens: 0,
      unique_provisional: 0,
      sources: {},
      simulated_count: 0,
      first_seen: now,
      last_activity: now,
      languages: [],
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
    lifecycle: { status: 'acknowledged', history: [{ action: `split_from:${sourceClusterId}`, by, at: now }] },
    review_queue: [],
  });

  const batch = db.batch();
  for (const sid of submission_ids) {
    batch.update(db.collection('submissions').doc(sid), {
      cluster_id: newClusterId,
      cluster_assignment: { similarity: 1, decided_by: 'staff_repair', pinned: true, at: now },
    });
  }
  batch.update(db.collection('clusters').doc(sourceClusterId), {
    lifecycle: appendHistory(src, `split_out:${submission_ids.length}`, by),
  });
  await batch.commit();

  await recomputeClusterFromMembers(db, sourceClusterId);
  await recomputeClusterFromMembers(db, newClusterId);

  res.json({ ok: true, new_cluster_id: newClusterId, moved: submission_ids.length });
});

/** Merge two clusters into one (§3.1). */
router.post('/merge', requireAuth, requireRole('mp_staff', 'mp'), async (req, res) => {
  const { keep_cluster_id, merge_cluster_id } = req.body as {
    keep_cluster_id?: string;
    merge_cluster_id?: string;
  };
  if (!keep_cluster_id || !merge_cluster_id || keep_cluster_id === merge_cluster_id) {
    res.status(400).json({ error: 'Distinct keep_cluster_id and merge_cluster_id are required' });
    return;
  }

  const db = getDb();
  const now = new Date().toISOString();
  const by = req.user?.uid ?? 'staff';

  const members = await db.collection('submissions').where('cluster_id', '==', merge_cluster_id).get();
  const batch = db.batch();
  for (const m of members.docs) {
    batch.update(m.ref, {
      cluster_id: keep_cluster_id,
      cluster_assignment: { similarity: 1, decided_by: 'staff_repair', pinned: true, at: now },
    });
  }
  await batch.commit();

  const keepDoc = await db.collection('clusters').doc(keep_cluster_id).get();
  if (keepDoc.exists) {
    await db
      .collection('clusters')
      .doc(keep_cluster_id)
      .update({ lifecycle: appendHistory(keepDoc.data()!, `merged_in:${merge_cluster_id}`, by) });
  }
  await db.collection('clusters').doc(merge_cluster_id).delete();
  await recomputeClusterFromMembers(db, keep_cluster_id);

  res.json({ ok: true, kept: keep_cluster_id, merged: merge_cluster_id, moved: members.size });
});

export default router;
