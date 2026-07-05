import { z } from 'zod';
import { CategorySchema } from './taxonomy.js';

export const DevelopmentPlanStatusSchema = z.enum([
  'proposed',
  'approved',
  'in_progress',
  'completed',
]);

export const DevelopmentPlanSchema = z.object({
  plan_id: z.string(),
  title: z.string(),
  description: z.string(),
  category: CategorySchema,
  subcategory: z.string(),
  admin_scope: z.object({
    constituency_code: z.string(),
    mandal_code: z.string().nullable(),
  }),
  status: DevelopmentPlanStatusSchema,
  estimated_cost: z.number().nullable().optional(),
  estimated_beneficiaries: z.number().nullable().optional(),
  source: z.string(),
  linked_cluster_id: z.string().nullable(),
  is_simulated: z.boolean().default(false),
});

export const LinkedPlanSummarySchema = z.object({
  plan_id: z.string(),
  title: z.string(),
  status: DevelopmentPlanStatusSchema,
  source: z.string(),
});

export type DevelopmentPlan = z.infer<typeof DevelopmentPlanSchema>;
export type LinkedPlanSummary = z.infer<typeof LinkedPlanSummarySchema>;

/** Similarity threshold for linking a development plan to a citizen-demand cluster (Phase D). */
export const PLAN_CLUSTER_LINK_THRESHOLD = 0.65;
