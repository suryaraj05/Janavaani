import type { Firestore } from 'firebase-admin/firestore';
import {
  compositeScore,
  demandTerm,
  confidenceTerm,
  recencyTerm,
  percentileIndex,
  type SubmissionScoreInput,
  type JustificationInput,
} from '@pp/schema';
import { resolveEvidence } from './evidence.js';
import { loadEvidenceSpecs } from './evidenceSpecs.js';
import { detectAnomalies } from './anomaly.js';
import { generateJustification } from './justification.js';
import { matchDevelopmentPlans } from './planMatching.js';

export interface ScoreRunResult {
  clustersScored: number;
  updated: string[];
}

/**
 * Full composite-scoring pass over all clusters (§6). Runs every 30 min via
 * Cloud Scheduler in production; also invocable through POST /run.
 */
export async function runScoring(db: Firestore): Promise<ScoreRunResult> {
  const specs = loadEvidenceSpecs();
  const supported = new Set(specs.keys());

  await matchDevelopmentPlans(db);

  const clusterSnap = await db.collection('clusters').get();
  const clusters = clusterSnap.docs;

  // P95 of unique_citizens across the constituency for D normalization.
  const uniqueCounts = clusters
    .map((d) => (d.data().stats as { unique_citizens?: number })?.unique_citizens ?? 0)
    .sort((a, b) => a - b);
  const p95 =
    uniqueCounts.length > 0 ? uniqueCounts[percentileIndex(uniqueCounts.length, 0.95)] : 1;

  // Demand centroids per mandal for evidence distance calc.
  const centroids: Record<string, { lat: number; lng: number }> = {};
  for (const doc of clusters) {
    const data = doc.data();
    const mandal = (data.admin_scope as { mandal_code?: string })?.mandal_code;
    const pt = data.centroid_point as { lat: number; lng: number } | null;
    if (mandal && pt) centroids[mandal] = pt;
  }

  const now = new Date();
  const updated: string[] = [];

  for (const doc of clusters) {
    const data = doc.data();
    const stats = data.stats as {
      unique_citizens: number;
      unique_provisional?: number;
      last_activity: string;
      sources: Record<string, number>;
      languages: string[];
      first_seen: string;
      simulated_count?: number;
    };

    const subsSnap = await db
      .collection('submissions')
      .where('cluster_id', '==', doc.id)
      .limit(500)
      .get();

    const scoreInputs: SubmissionScoreInput[] = subsSnap.docs.map((s) => {
      const sd = s.data();
      const media = (sd.content as { media?: unknown[] })?.media ?? [];
      return {
        source: sd.source as string,
        modality: (sd.content as { modality?: string })?.modality ?? 'text',
        has_media: media.length > 0,
        geocode_confidence:
          ((sd.location as { geocode_confidence?: string })?.geocode_confidence as
            | 'high'
            | 'medium'
            | 'low'
            | 'none') ?? 'none',
      };
    });

    const uEff =
      (stats.unique_citizens ?? 0) + 0.5 * (stats.unique_provisional ?? 0);
    const D = demandTerm(uEff, p95);
    const V = confidenceTerm(scoreInputs);
    const daysSince =
      (now.getTime() - new Date(stats.last_activity).getTime()) / (24 * 60 * 60 * 1000);
    const R = recencyTerm(Math.max(0, daysSince));

    const evidence = resolveEvidence(
      data.subcategory as string,
      (data.admin_scope as { mandal_code?: string })?.mandal_code ?? null,
      centroids,
      supported,
    );

    const score = compositeScore({
      evidence: evidence ? evidence.score : null,
      demand: D,
      confidence: V,
      recency: R,
    });

    const anomaly = await detectAnomalies(db, doc.id);

    const linkedPlan = data.linked_plan as
      | { plan_id: string; title: string; status: string; source: string }
      | null
      | undefined;

    const justificationInput: JustificationInput = {
      cluster_title: data.canonical_title_en as string,
      category: data.category as string,
      admin_unit_names: [
        (data.admin_scope as { mandal_code?: string })?.mandal_code ?? 'unknown mandal',
      ],
      score: {
        total: score.total,
        demand: score.demand,
        evidence: score.evidence,
        confidence: score.confidence,
        recency: score.recency,
        evidence_available: score.evidence_available,
      },
      demand_stats: {
        unique_citizens: stats.unique_citizens ?? 0,
        sources: stats.sources ?? {},
        languages: stats.languages ?? [],
        first_seen: stats.first_seen ?? now.toISOString(),
        last_activity: stats.last_activity ?? now.toISOString(),
        simulated_count: stats.simulated_count ?? 0,
      },
      anomaly_flags: anomaly.flags,
      evidence_rows: evidence?.rows ?? [],
      linked_plan: linkedPlan ?? null,
    };

    const justification = await generateJustification(justificationInput);

    await doc.ref.update({
      score: {
        total: Number(score.total.toFixed(1)),
        demand: Number(score.demand.toFixed(3)),
        evidence: Number(score.evidence.toFixed(3)),
        confidence: Number(score.confidence.toFixed(3)),
        recency: Number(score.recency.toFixed(3)),
        evidence_available: score.evidence_available,
        computed_at: now.toISOString(),
      },
      anomaly_flags: anomaly.flags,
      justification: {
        ...justification,
        model: process.env.JUSTIFICATION_MODEL ?? 'deterministic',
        generated_at: now.toISOString(),
      },
    });

    updated.push(doc.id);
  }

  return { clustersScored: clusters.length, updated };
}
