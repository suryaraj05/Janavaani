import { ulid } from 'ulid';
import type { Firestore } from 'firebase-admin/firestore';
import type { SubmissionDraft } from '@pp/schema';
import { getConstituencyCode } from '../config.js';
import { enrichSubmission } from './enrichClient.js';

export interface IngestResult {
  submission_id: string;
  cluster_id: string;
  submission: Record<string, unknown>;
}

/**
 * Normalize a draft into a Unified Submission, write it to Firestore, and run
 * enrichment. Shared by the app route (POST /submissions), the connector
 * ingest route (POST /ingest), and the WhatsApp webhook.
 */
export async function ingestDraft(
  db: Firestore,
  draft: SubmissionDraft,
  opts: {
    citizenHash: string | null;
    mediaBase64?: { audio?: string; images?: string[] };
  },
): Promise<IngestResult> {
  const now = new Date().toISOString();
  const submissionId = `sub_${ulid()}`;

  const rawSubmission = {
    submission_id: submissionId,
    schema_version: 1 as const,
    source: draft.source,
    is_simulated: draft.is_simulated,
    created_at: now,
    occurred_at: draft.occurred_at ?? now,
    citizen: {
      ...draft.citizen,
      citizen_hash: opts.citizenHash ?? draft.citizen.citizen_hash ?? null,
      auth_kind: draft.citizen.auth_kind ?? 'anonymous',
    },
    content: draft.content,
    ai: null,
    location: {
      raw_mentions: draft.location.raw_mentions ?? [],
      point: draft.location.point ?? null,
      method: draft.location.method ?? (draft.location.point ? 'device_gps' : 'none'),
      geocode_confidence:
        draft.location.geocode_confidence ?? (draft.location.point ? 'high' : 'none'),
      admin: {
        constituency_code: draft.location.admin?.constituency_code ?? getConstituencyCode(),
        mandal_code: draft.location.admin?.mandal_code ?? null,
        lgd_village_code: draft.location.admin?.lgd_village_code ?? null,
        ulb_ward_code: draft.location.admin?.ulb_ward_code ?? null,
      },
    },
    cluster_id: null,
    cluster_assignment: null,
    consent: draft.consent ?? { basis: 'direct_submission', pii_scrubbed: true },
    channel_meta: draft.channel_meta ?? {},
  };

  await db.collection('submissions').doc(submissionId).set(rawSubmission);
  const enriched = await enrichSubmission(submissionId, draft, opts.mediaBase64);

  return {
    submission_id: submissionId,
    cluster_id: enriched.cluster_id,
    submission: enriched.submission,
  };
}
