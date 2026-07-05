import { z } from 'zod';
import { CategorySchema, KindSchema, UrgencySchema } from './taxonomy.js';

export const LocationMentionSchema = z.object({
  original: z.string(),
  latin: z.string(),
});

export const TriageResponseSchema = z.object({
  original_language: z.string(),
  transcript_original: z.string().nullable().optional(),
  text_en: z.string(),
  canonical_summary_en: z.string().max(220),
  category: CategorySchema,
  subcategory: z.string(),
  kind: KindSchema,
  urgency: UrgencySchema,
  location_mentions: z.array(LocationMentionSchema).default([]),
  photo_observations: z.array(z.string()).optional(),
  entities: z.array(z.string()).optional(),
  triage_confidence: z.number().min(0).max(1),
  triage_notes: z.string().nullable().optional(),
});

export const TRIAGE_RESPONSE_JSON_SCHEMA = {
  type: 'object',
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
  properties: {
    original_language: { type: 'string' },
    transcript_original: { type: 'string', nullable: true },
    text_en: { type: 'string' },
    canonical_summary_en: { type: 'string', maxLength: 220 },
    category: {
      type: 'string',
      enum: [
        'roads',
        'water',
        'education',
        'health',
        'electricity',
        'sanitation',
        'transport',
        'agriculture',
        'welfare',
        'other',
      ],
    },
    subcategory: { type: 'string' },
    kind: {
      type: 'string',
      enum: ['development_request', 'grievance', 'question', 'other'],
    },
    urgency: {
      type: 'string',
      enum: ['safety_critical', 'high', 'medium', 'low'],
    },
    location_mentions: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          original: { type: 'string' },
          latin: { type: 'string' },
        },
        required: ['original', 'latin'],
      },
    },
    photo_observations: { type: 'array', items: { type: 'string' } },
    entities: { type: 'array', items: { type: 'string' } },
    triage_confidence: { type: 'number' },
    triage_notes: { type: 'string', nullable: true },
  },
} as const;

export const TRIAGE_SYSTEM_PROMPT = `You are the intake triage system for "People's Priorities", a platform where citizens of an
Indian parliamentary constituency submit local development requests in any language, by text,
voice, or photo. You will receive one citizen submission. Do ALL of the following and return
ONLY the JSON object described by the response schema:

1. LANGUAGE: Identify the primary language (BCP-47, e.g. "te", "hi", "en", "ur"). Code-switched
   speech (Telugu-English) → the dominant language.
2. TRANSCRIPT: If audio is present, transcribe it faithfully in the original script into
   \`transcript_original\`. Do not translate inside the transcript.
3. TRANSLATION: Produce \`text_en\`, a faithful English translation. Preserve place names as
   proper nouns (transliterate, do not translate them).
4. CANONICAL SUMMARY: Write \`canonical_summary_en\` — one neutral English sentence stating the
   underlying REQUEST (not the complaint narrative): what is being asked for, and where.
   Normalize aggressively: "our school has no 10th class" and "we need a high school" both
   become a request for secondary school access. This field is used to detect that two
   submissions ask for the same thing, so identical demands must produce near-identical
   summaries. Do NOT include the citizen's name, emotion, or channel.
5. CLASSIFY into exactly one category/subcategory:
   roads(new_road, repair, bridge_culvert, streetlights), water(drinking_water, irrigation,
   drainage), education(school_upgrade, new_school, school_infrastructure, vocational_training),
   health(phc_upgrade, new_facility, staffing_equipment), electricity(new_connection,
   reliability), sanitation(toilets, waste_management), transport(bus_service, rail),
   agriculture(market_access, storage, subsidy_access), welfare(pension_schemes, housing,
   ration), other(other).
   Use photos as classification evidence; describe each briefly in \`photo_observations\`.
6. KIND: development_request | grievance | question | other (spam, politics-only, abuse).
7. URGENCY: safety_critical (immediate danger to life) | high | medium | low.
8. LOCATIONS: Extract every location mention verbatim into \`location_mentions\` (village,
   colony, landmark, road names), original script AND transliterated Latin.
9. PII: In text_en and canonical_summary_en, replace private individuals' names with "[name]"
   and phone numbers with "[phone]". Keep public place names and officials' role titles.
10. CONFIDENCE: \`triage_confidence\` 0.0–1.0 for category + summary combined. Below 0.5 the
    item goes to human review; be honest.

Never invent locations or facts not present in the submission. If the submission is empty,
unintelligible, or pure abuse, set kind="other" and explain in \`triage_notes\`.`;

export type TriageResponse = z.infer<typeof TriageResponseSchema>;
