import { GoogleGenerativeAI, SchemaType } from '@google/generative-ai';
import {
  JUSTIFICATION_SYSTEM_PROMPT,
  JustificationOutputSchema,
  JustificationInputSchema,
  findHallucinatedNumbers,
  JUSTIFICATION_MODEL,
  type JustificationInput,
  type JustificationOutput,
} from '@pp/schema';

/**
 * Generate the "why is this ranked here" prose (Prompt C). The model converts
 * provided numbers to prose only; a digit-validation retry enforces invariant #3.
 */
export async function generateJustification(
  input: JustificationInput,
): Promise<JustificationOutput> {
  JustificationInputSchema.parse(input);
  const apiKey = process.env.GEMINI_API_KEY?.trim();
  if (!apiKey) return deterministicJustification(input);

  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({
    model: JUSTIFICATION_MODEL,
    systemInstruction: JUSTIFICATION_SYSTEM_PROMPT,
    generationConfig: {
      responseMimeType: 'application/json',
      responseSchema: {
        type: SchemaType.OBJECT,
        properties: {
          text_en: { type: SchemaType.STRING },
          evidence_bullets: { type: SchemaType.ARRAY, items: { type: SchemaType.STRING } },
          caveats: { type: SchemaType.ARRAY, items: { type: SchemaType.STRING } },
        },
        required: ['text_en', 'evidence_bullets', 'caveats'],
      },
    },
  });

  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const result = await model.generateContent(JSON.stringify(input));
      const parsed = JustificationOutputSchema.parse(JSON.parse(result.response.text()));
      const hallucinated = findHallucinatedNumbers(input, parsed);
      if (hallucinated.length === 0) return parsed;
      console.warn(`Justification retry — hallucinated numbers: ${hallucinated.join(', ')}`);
    } catch (err) {
      console.warn('Justification generation failed:', err);
    }
  }

  return deterministicJustification(input);
}

/** Fallback prose built purely from payload numbers (never hallucinates). */
function deterministicJustification(input: JustificationInput): JustificationOutput {
  const channels = Object.keys(input.demand_stats.sources).join(', ');
  const caveats: string[] = [];
  if (!input.score.evidence_available) caveats.push('no_dataset_coverage');
  if (Object.keys(input.demand_stats.sources).length <= 1) caveats.push('single_channel');
  if (input.demand_stats.unique_citizens < 5) caveats.push('small_sample');
  if (input.demand_stats.simulated_count > input.demand_stats.unique_citizens / 2)
    caveats.push('mostly_simulated_sources');
  if (input.anomaly_flags.length > 0) caveats.push('suspected_coordination');

  const bullets = input.evidence_rows
    .slice(0, 4)
    .map((r) => `${r.label}: ${r.value} — ${r.dataset} ${r.ref_year}`);

  const evidenceSentence = input.score.evidence_available
    ? input.evidence_rows
        .slice(0, 2)
        .map((r) => `${r.value} (${r.dataset} ${r.ref_year})`)
        .join('; ')
    : 'No public-dataset evidence is loaded for this category yet; the rank reflects citizen demand, source quality and recency only.';

  const text = `${input.demand_stats.unique_citizens} citizens have raised "${input.cluster_title}" across ${channels} in ${input.admin_unit_names.join(', ')}. ${evidenceSentence}`;

  return { text_en: text, evidence_bullets: bullets, caveats: [...new Set(caveats)] };
}
