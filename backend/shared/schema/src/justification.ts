import { z } from 'zod';

/** Fixed caveat vocabulary for the "why" panel (§3c). */
export const CAVEAT_VALUES = [
  'low_geocode_confidence',
  'no_dataset_coverage',
  'single_channel',
  'mostly_simulated_sources',
  'low_speaker_confidence',
  'small_sample',
  'suspected_coordination',
] as const;

export const CaveatSchema = z.enum(CAVEAT_VALUES);

export const EvidenceRowSchema = z.object({
  label: z.string(),
  value: z.union([z.number(), z.string()]),
  dataset: z.string(),
  ref_year: z.string(),
});

export const JustificationInputSchema = z.object({
  cluster_title: z.string(),
  category: z.string(),
  admin_unit_names: z.array(z.string()),
  score: z.object({
    total: z.number(),
    demand: z.number(),
    evidence: z.number(),
    confidence: z.number(),
    recency: z.number(),
    evidence_available: z.boolean(),
  }),
  demand_stats: z.object({
    unique_citizens: z.number(),
    sources: z.record(z.number()),
    languages: z.array(z.string()),
    first_seen: z.string(),
    last_activity: z.string(),
    simulated_count: z.number(),
  }),
  anomaly_flags: z.array(z.string()),
  evidence_rows: z.array(EvidenceRowSchema),
  linked_plan: z
    .object({
      plan_id: z.string(),
      title: z.string(),
      status: z.string(),
      source: z.string(),
    })
    .nullable()
    .optional(),
});

export const JustificationOutputSchema = z.object({
  text_en: z.string(),
  evidence_bullets: z.array(z.string()),
  caveats: z.array(z.string()),
});

export const JUSTIFICATION_SYSTEM_PROMPT = `You write the "Why is this ranked here?" explanation shown to an MP and their staff on a
development-priorities dashboard.

You will receive one JSON payload: cluster title, category, admin unit names, the four score
components (demand, evidence, confidence, recency, each 0-1) and total, demand statistics
(unique citizens, sources, languages, first/last activity, simulated_count), anomaly_flags,
and evidence_rows - the exact public-dataset figures used, each with dataset name and
reference year.

Write:
1. \`text_en\`: 2-4 sentences, plain language. Sentence 1: what is asked and by how many
   citizens through which channels. Sentences 2-3: the strongest evidence figures, citing
   dataset name and year inline. Final sentence: any material caveat.
2. \`evidence_bullets\`: <=4 bullets, each ONE figure with its source, verbatim from evidence_rows.
3. \`caveats\`: from the fixed set [low_geocode_confidence, no_dataset_coverage, single_channel,
   mostly_simulated_sources, low_speaker_confidence, small_sample, suspected_coordination].

HARD RULES:
- Use ONLY numbers present in the payload. Never estimate, extrapolate, round beyond one
  decimal, or add outside context.
- If evidence_available=false: say plainly that no public-dataset evidence is loaded for this
  category yet and the rank reflects demand, source quality and recency only.
- If anomaly_flags is non-empty, include suspected_coordination and mention it neutrally.
- Neutral tone. No advocacy - the score speaks; you explain it.
Return ONLY JSON: {"text_en": str, "evidence_bullets": [str], "caveats": [str]}.`;

/**
 * Validate that the justification prose introduces no numbers absent from the
 * input payload (invariant #3). Returns the offending digit-strings, if any.
 */
export function findHallucinatedNumbers(
  input: z.infer<typeof JustificationInputSchema>,
  output: z.infer<typeof JustificationOutputSchema>,
): string[] {
  const allowed = new Set<string>();
  const collect = (value: unknown): void => {
    if (typeof value === 'number') {
      allowed.add(String(value));
      allowed.add(String(Math.round(value)));
      allowed.add(value.toFixed(1));
    } else if (typeof value === 'string') {
      for (const m of value.matchAll(/\d+(?:\.\d+)?/g)) allowed.add(m[0]);
    } else if (Array.isArray(value)) {
      value.forEach(collect);
    } else if (value && typeof value === 'object') {
      Object.values(value).forEach(collect);
    }
  };
  collect(input);

  const prose = [output.text_en, ...output.evidence_bullets].join(' ');
  const found = new Set<string>();
  for (const m of prose.matchAll(/\d+(?:\.\d+)?/g)) {
    const num = m[0];
    // year-like tokens (2024, 2026) and single digits used as ordinals are common; still enforce membership
    if (!allowed.has(num)) found.add(num);
  }
  return [...found];
}

export type JustificationInput = z.infer<typeof JustificationInputSchema>;
export type JustificationOutput = z.infer<typeof JustificationOutputSchema>;
export type Caveat = z.infer<typeof CaveatSchema>;
