import { z } from 'zod';
import { CategorySchema, LifecycleStatusSchema } from './taxonomy.js';
import { GeoPointSchema } from './submission.js';

export const ClusterStatsSchema = z.object({
  submission_count: z.number().int().nonnegative(),
  unique_citizens: z.number().int().nonnegative(),
  unique_provisional: z.number().int().nonnegative().default(0),
  sources: z.record(z.number().int().nonnegative()).default({}),
  simulated_count: z.number().int().nonnegative().default(0),
  first_seen: z.string().datetime(),
  last_activity: z.string().datetime(),
  languages: z.array(z.string()).default([]),
});

export const ClusterScoreSchema = z.object({
  total: z.number(),
  demand: z.number().min(0).max(1),
  evidence: z.number().min(0).max(1).default(0),
  confidence: z.number().min(0).max(1).default(0),
  recency: z.number().min(0).max(1),
  evidence_available: z.boolean().default(false),
  computed_at: z.string().datetime(),
});

export const JustificationSchema = z.object({
  text_en: z.string(),
  evidence_bullets: z.array(z.string()).default([]),
  caveats: z.array(z.string()).default([]),
  model: z.string().optional(),
  generated_at: z.string().datetime().optional(),
});

export const LifecycleHistoryEntrySchema = z.object({
  action: z.string(),
  by: z.string(),
  at: z.string().datetime(),
});

export const ClusterLifecycleSchema = z.object({
  status: LifecycleStatusSchema,
  history: z.array(LifecycleHistoryEntrySchema).default([]),
});

export const ClusterSchema = z.object({
  cluster_id: z.string(),
  canonical_title_en: z.string(),
  category: CategorySchema,
  subcategory: z.string(),
  admin_scope: z.object({
    constituency_code: z.string(),
    mandal_code: z.string().nullable(),
  }),
  centroid_point: GeoPointSchema.nullable(),
  stats: ClusterStatsSchema,
  score: ClusterScoreSchema,
  anomaly_flags: z.array(z.string()).default([]),
  justification: JustificationSchema.nullable().optional(),
  lifecycle: ClusterLifecycleSchema,
  review_queue: z.array(z.string()).default([]),
});

export type Cluster = z.infer<typeof ClusterSchema>;
