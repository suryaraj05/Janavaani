import { GoogleGenerativeAI, SchemaType } from '@google/generative-ai';
import {
  TRIAGE_SYSTEM_PROMPT,
  TriageResponseSchema,
  TRIAGE_MODEL,
  TRIAGE_MODEL_FALLBACK,
  type TriageResponse,
} from '@pp/schema';

export interface TriageInput {
  text?: string;
  audioBase64?: string;
  audioMime?: string;
  imagesBase64?: string[];
}

export async function runTriage(input: TriageInput): Promise<TriageResponse> {
  const apiKey = process.env.GEMINI_API_KEY?.trim();
  if (!apiKey) {
    return mockTriage(input);
  }

  const genAI = new GoogleGenerativeAI(apiKey);
  const responseSchema = {
    type: SchemaType.OBJECT,
    properties: {
      original_language: { type: SchemaType.STRING },
      transcript_original: { type: SchemaType.STRING, nullable: true },
      text_en: { type: SchemaType.STRING },
      canonical_summary_en: { type: SchemaType.STRING },
      category: { type: SchemaType.STRING },
      subcategory: { type: SchemaType.STRING },
      kind: { type: SchemaType.STRING },
      urgency: { type: SchemaType.STRING },
      location_mentions: {
        type: SchemaType.ARRAY,
        items: {
          type: SchemaType.OBJECT,
          properties: {
            original: { type: SchemaType.STRING },
            latin: { type: SchemaType.STRING },
          },
          required: ['original', 'latin'],
        },
      },
      photo_observations: { type: SchemaType.ARRAY, items: { type: SchemaType.STRING } },
      entities: { type: SchemaType.ARRAY, items: { type: SchemaType.STRING } },
      triage_confidence: { type: SchemaType.NUMBER },
      triage_notes: { type: SchemaType.STRING, nullable: true },
    },
    required: [
      'original_language',
      'text_en',
      'canonical_summary_en',
      'category',
      'subcategory',
      'kind',
      'urgency',
      'location_mentions',
      'triage_confidence',
    ],
  };

  const models = [TRIAGE_MODEL, TRIAGE_MODEL_FALLBACK];
  let lastError: unknown;

  for (const modelId of models) {
    try {
      const model = genAI.getGenerativeModel({
        model: modelId,
        systemInstruction: TRIAGE_SYSTEM_PROMPT,
        generationConfig: {
          responseMimeType: 'application/json',
          responseSchema,
        },
      });

      const parts: Array<{ text: string } | { inlineData: { mimeType: string; data: string } }> =
        [];

      if (input.text) {
        parts.push({ text: `Submission text:\n${input.text}` });
      }

      if (input.audioBase64) {
        parts.push({
          inlineData: {
            mimeType: input.audioMime ?? 'audio/ogg',
            data: input.audioBase64,
          },
        });
      }

      for (const img of input.imagesBase64 ?? []) {
        const match = img.match(/^data:(image\/\w+);base64,(.+)$/);
        if (match) {
          parts.push({ inlineData: { mimeType: match[1], data: match[2] } });
        } else {
          parts.push({ inlineData: { mimeType: 'image/jpeg', data: img } });
        }
      }

      if (parts.length === 0) {
        parts.push({ text: 'Empty submission' });
      }

      const result = await model.generateContent({ contents: [{ role: 'user', parts }] });
      const text = result.response.text();
      const parsed = TriageResponseSchema.parse(JSON.parse(text));
      return parsed;
    } catch (err) {
      lastError = err;
      console.warn(`Triage failed with model ${modelId}:`, err);
    }
  }

  console.warn('All triage models failed — falling back to mock triage:', lastError);
  return mockTriage(input);
}

function mockTriage(input: TriageInput): TriageResponse {
  const text = input.text ?? 'Voice submission about school upgrade in Ghatkesar';
  return {
    original_language: 'te',
    transcript_original: input.audioBase64
      ? 'మా ఊరి బడి 7వ తరగతి వరకే ఉంది; పిల్లలు ఘట్కేసర్‌కు 6 కి.మీ నడుస్తున్నారు'
      : null,
    text_en:
      text.includes('हाई') || text.includes('स्कूल')
        ? 'No high school in village; children travel to Ghatkesar — requests secondary school'
        : 'Our village school only goes to grade 7; children walk 6 km to Ghatkesar for high school.',
    canonical_summary_en:
      'Upgrade village school beyond grade 7 / secondary school access; ~6 km travel to Ghatkesar',
    category: 'education',
    subcategory: 'school_upgrade',
    kind: 'development_request',
    urgency: 'medium',
    location_mentions: [{ original: 'Ghatkesar', latin: 'Ghatkesar' }],
    triage_confidence: 0.86,
    entities: ['Ghatkesar', 'village school'],
  };
}
