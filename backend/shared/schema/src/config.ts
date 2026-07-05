export const TRIAGE_MODEL = process.env.TRIAGE_MODEL ?? 'gemini-2.5-flash';
export const TRIAGE_MODEL_FALLBACK = process.env.TRIAGE_MODEL_FALLBACK ?? 'gemini-2.0-flash';
export const JUSTIFICATION_MODEL = process.env.JUSTIFICATION_MODEL ?? TRIAGE_MODEL;
export const EMBEDDING_MODEL = 'gemini-embedding-001';
export const EMBEDDING_DIM = 768;

/**
 * Composite score weights (§6). Evidence deliberately edges out demand;
 * demand + confidence together (0.50) still outweigh evidence.
 */
export const SCORE_WEIGHTS = {
  evidence: 0.35,
  demand: 0.3,
  confidence: 0.2,
  recency: 0.15,
} as const;

export const RECENCY_HALF_LIFE_DAYS = 90;

/**
 * Source-confidence weights (w_src) — an explicit editorial policy (§6).
 * Keyed by (source, evidence quality) tuples resolved by `sourceWeight()`.
 */
export const SOURCE_WEIGHTS = {
  app_gps_photo: 1.0,
  app_text: 0.85,
  whatsapp_media: 0.8,
  whatsapp_text_voice: 0.65,
  meeting: 0.5,
  portal_mock: 0.5,
  youtube: 0.3,
} as const;

/** Geocode factor g applied to source weight in V (§6). */
export const GEOCODE_FACTORS: Record<string, number> = {
  high: 1.0,
  medium: 0.85,
  low: 0.6,
  none: 0.4,
};

export interface SubmissionScoreInput {
  source: string;
  modality: string;
  has_media: boolean;
  geocode_confidence: 'high' | 'medium' | 'low' | 'none';
}

/** Resolve w_src for one submission based on source + modality + media. */
export function sourceWeight(sub: SubmissionScoreInput): number {
  switch (sub.source) {
    case 'app':
      return sub.has_media && sub.geocode_confidence === 'high'
        ? SOURCE_WEIGHTS.app_gps_photo
        : SOURCE_WEIGHTS.app_text;
    case 'whatsapp':
      return sub.has_media ? SOURCE_WEIGHTS.whatsapp_media : SOURCE_WEIGHTS.whatsapp_text_voice;
    case 'meeting':
      return SOURCE_WEIGHTS.meeting;
    case 'portal_mock':
      return SOURCE_WEIGHTS.portal_mock;
    case 'meta_mock':
      return SOURCE_WEIGHTS.portal_mock;
    case 'youtube':
      return SOURCE_WEIGHTS.youtube;
    default:
      return 0.5;
  }
}

/** D — citizen demand (0–1), log-damped, flood-resistant (§6). */
export function demandTerm(uEff: number, p95Unique: number): number {
  if (p95Unique <= 0) return uEff > 0 ? 1 : 0;
  const value = Math.log(1 + uEff) / Math.log(1 + p95Unique);
  return Math.min(1, Math.max(0, value));
}

/** V — source-confidence (0–1): mean over submissions of w_src · g (§6). */
export function confidenceTerm(subs: SubmissionScoreInput[]): number {
  if (subs.length === 0) return 0;
  const sum = subs.reduce((acc, s) => {
    const g = GEOCODE_FACTORS[s.geocode_confidence] ?? 0.4;
    return acc + sourceWeight(s) * g;
  }, 0);
  return sum / subs.length;
}

/** R — recency (0–1): 90-day half-life (§6). */
export function recencyTerm(daysSinceActivity: number): number {
  return Math.pow(2, -daysSinceActivity / RECENCY_HALF_LIFE_DAYS);
}

export interface CompositeScoreResult {
  total: number;
  evidence: number;
  demand: number;
  confidence: number;
  recency: number;
  evidence_available: boolean;
}

/**
 * PriorityScore = 100 · (0.35·E + 0.30·D + 0.20·V + 0.15·R).
 * When no evidence spec covers the subcategory, the remaining weights
 * renormalize (÷0.65) so a missing dataset never silently zeros a demand (§6).
 */
export function compositeScore(params: {
  evidence: number | null;
  demand: number;
  confidence: number;
  recency: number;
}): CompositeScoreResult {
  const { demand, confidence, recency } = params;
  const evidenceAvailable = params.evidence !== null;

  if (evidenceAvailable) {
    const e = params.evidence as number;
    const total =
      100 *
      (SCORE_WEIGHTS.evidence * e +
        SCORE_WEIGHTS.demand * demand +
        SCORE_WEIGHTS.confidence * confidence +
        SCORE_WEIGHTS.recency * recency);
    return {
      total,
      evidence: e,
      demand,
      confidence,
      recency,
      evidence_available: true,
    };
  }

  const renorm = SCORE_WEIGHTS.demand + SCORE_WEIGHTS.confidence + SCORE_WEIGHTS.recency;
  const total =
    100 *
    ((SCORE_WEIGHTS.demand * demand +
      SCORE_WEIGHTS.confidence * confidence +
      SCORE_WEIGHTS.recency * recency) /
      renorm);
  return {
    total,
    evidence: 0,
    demand,
    confidence,
    recency,
    evidence_available: false,
  };
}

/** Index into a sorted array for the p-th percentile (0–1), consistent across services. */
export function percentileIndex(length: number, percentile: number): number {
  if (length <= 0) return 0;
  return Math.floor(Math.max(0, length - 1) * percentile);
}

/** Percentile-rank normalization used by evidence indicators (§5.3). */
export function percentRank(values: number[], value: number): number {
  if (values.length <= 1) return 0;
  const below = values.filter((v) => v < value).length;
  return below / (values.length - 1);
}

/**
 * Phase-1 interim score (demand + recency only) — kept for the sync pipeline
 * before score-runner + evidence land. Superseded by compositeScore().
 */
export function computeInterimScore(
  uniqueCitizens: number,
  p95Unique: number,
  daysSinceActivity: number,
): { total: number; demand: number; recency: number } {
  const demand = demandTerm(uniqueCitizens, p95Unique);
  const recency = recencyTerm(daysSinceActivity);
  const total = 100 * (0.55 * demand + 0.45 * recency);
  return { total, demand, recency };
}
