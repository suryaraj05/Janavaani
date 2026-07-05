import type { Firestore } from 'firebase-admin/firestore';
import { allowedMandalCodes, PLAN_CLUSTER_LINK_THRESHOLD, type DevelopmentPlan } from '@pp/schema';
import { embedText, cosineSimilarity } from '@pp/enrich-worker/embedding';
import { textSimilarity } from '@pp/enrich-worker/clustering';

export interface PlanMatchResult {
  plan_id: string;
  linked_cluster_id: string | null;
  similarity: number;
}

/**
 * Match development plans to citizen-demand clusters (Phase D).
 * Uses the same category + admin-unit filter and embedding similarity as clustering.
 */
export async function matchDevelopmentPlans(db: Firestore): Promise<PlanMatchResult[]> {
  const planSnap = await db.collection('development_plans').get();
  const clusterSnap = await db.collection('clusters').get();
  const results: PlanMatchResult[] = [];

  // Reset plan flags before re-linking.
  for (const doc of clusterSnap.docs) {
    await doc.ref.update({ has_existing_plan: false, linked_plan: null });
  }

  const clusters = clusterSnap.docs.map((d) => ({
    id: d.id,
    category: d.data().category as string,
    mandal: (d.data().admin_scope as { mandal_code?: string | null })?.mandal_code ?? null,
    title: d.data().canonical_title_en as string,
    embedding: null as number[] | null,
  }));

  for (const c of clusters) {
    const centroidDoc = await db.collection('cluster_centroids').doc(c.id).get();
    c.embedding = (centroidDoc.data()?.embedding as number[]) ?? null;
  }

  for (const planDoc of planSnap.docs) {
    const plan = planDoc.data() as DevelopmentPlan;
    if (plan.linked_cluster_id) {
      results.push({
        plan_id: plan.plan_id,
        linked_cluster_id: plan.linked_cluster_id,
        similarity: 1,
      });
      continue;
    }

    const planText = `${plan.title}. ${plan.description}`;
    const planEmbedding = await embedText(planText);
    const allowed = allowedMandalCodes(plan.admin_scope.mandal_code, 'medium');

    let best: { clusterId: string; similarity: number } | null = null;
    for (const c of clusters) {
      if (c.category !== plan.category) continue;
      if (allowed && c.mandal && !allowed.has(c.mandal)) continue;
      if (!c.embedding) continue;
      const embedSim = cosineSimilarity(planEmbedding, c.embedding);
      const textSim = Math.max(
        textSimilarity(plan.title, c.title),
        textSimilarity(planText, c.title),
      );
      const similarity = Math.max(embedSim, textSim);
      if (!best || similarity > best.similarity) best = { clusterId: c.id, similarity };
    }

    const linked =
      best && best.similarity >= PLAN_CLUSTER_LINK_THRESHOLD ? best.clusterId : null;

    await planDoc.ref.update({ linked_cluster_id: linked });

    if (linked) {
      await db.collection('clusters').doc(linked).update({
        has_existing_plan: true,
        linked_plan: {
          plan_id: plan.plan_id,
          title: plan.title,
          status: plan.status,
          source: plan.source,
        },
      });
    }

    results.push({
      plan_id: plan.plan_id,
      linked_cluster_id: linked,
      similarity: best?.similarity ?? 0,
    });
  }

  return results;
}
