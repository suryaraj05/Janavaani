import { z } from 'zod';
import {
  AuthKindSchema,
  CategorySchema,
  ClusterDecisionSchema,
  DisplayLocaleSchema,
  GeocodeConfidenceSchema,
  GeocodeMethodSchema,
  KindSchema,
  ModalitySchema,
  SourceSchema,
  UrgencySchema,
} from './taxonomy.js';

export const MediaItemSchema = z.object({
  kind: z.enum(['audio', 'image']),
  gcs_uri: z.string(),
  mime: z.string(),
  duration_s: z.number().optional(),
});

export const CitizenSchema = z.object({
  citizen_hash: z.string().nullable(),
  auth_kind: AuthKindSchema,
  display_locale: DisplayLocaleSchema,
});

export const ContentSchema = z.object({
  modality: ModalitySchema,
  original_text: z.string().nullable(),
  original_language: z.string(),
  media: z.array(MediaItemSchema).default([]),
  transcript_original: z.string().nullable().optional(),
  text_en: z.string().optional(),
});

export const AiEnrichmentSchema = z.object({
  canonical_summary_en: z.string().max(220),
  category: CategorySchema,
  subcategory: z.string(),
  kind: KindSchema,
  urgency: UrgencySchema,
  entities: z.array(z.string()).default([]),
  triage_confidence: z.number().min(0).max(1),
  model_versions: z.object({
    triage: z.string(),
    embedding: z.string().optional(),
  }),
});

export const GeoPointSchema = z.object({
  lat: z.number(),
  lng: z.number(),
});

export const AdminUnitSchema = z.object({
  constituency_code: z.string(),
  mandal_code: z.string().nullable(),
  lgd_village_code: z.string().nullable(),
  ulb_ward_code: z.string().nullable(),
});

export const LocationSchema = z.object({
  raw_mentions: z.array(z.string()).default([]),
  point: GeoPointSchema.nullable(),
  method: GeocodeMethodSchema,
  geocode_confidence: GeocodeConfidenceSchema,
  admin: AdminUnitSchema,
});

export const ClusterAssignmentSchema = z.object({
  similarity: z.number().min(0).max(1).optional(),
  decided_by: ClusterDecisionSchema,
  pinned: z.boolean().default(false),
  at: z.string().datetime().optional(),
});

export const ConsentSchema = z.object({
  basis: z.enum(['direct_submission', 'public_meeting_notice', 'public_platform']),
  pii_scrubbed: z.boolean().default(true),
});

export const SubmissionSchema = z.object({
  submission_id: z.string(),
  schema_version: z.literal(1),
  source: SourceSchema,
  is_simulated: z.boolean().default(false),
  created_at: z.string().datetime(),
  occurred_at: z.string().datetime(),
  citizen: CitizenSchema,
  content: ContentSchema,
  ai: AiEnrichmentSchema.nullable().optional(),
  location: LocationSchema,
  cluster_id: z.string().nullable().optional(),
  cluster_assignment: ClusterAssignmentSchema.nullable().optional(),
  consent: ConsentSchema,
  channel_meta: z.record(z.unknown()).default({}),
});

export const SubmissionDraftSchema = z.object({
  source: SourceSchema.default('app'),
  is_simulated: z.boolean().default(false),
  occurred_at: z.string().datetime().optional(),
  citizen: CitizenSchema,
  content: ContentSchema,
  location: LocationSchema.partial({
    raw_mentions: true,
    method: true,
    geocode_confidence: true,
    admin: true,
  }).extend({
    point: GeoPointSchema.nullable().optional(),
    method: GeocodeMethodSchema.optional(),
    geocode_confidence: GeocodeConfidenceSchema.optional(),
    admin: AdminUnitSchema.partial().optional(),
  }),
  consent: ConsentSchema.optional(),
  channel_meta: z.record(z.unknown()).default({}),
});

export type Submission = z.infer<typeof SubmissionSchema>;
export type SubmissionDraft = z.infer<typeof SubmissionDraftSchema>;
export type AiEnrichment = z.infer<typeof AiEnrichmentSchema>;
