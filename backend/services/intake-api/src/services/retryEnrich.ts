import type { Firestore } from 'firebase-admin/firestore';
import type { SubmissionDraft } from '@pp/schema';
import { enrichSubmission } from './enrichClient.js';

function docToDraft(data: Record<string, unknown>): SubmissionDraft {
  const citizen = (data.citizen as Record<string, unknown>) ?? {};
  const content = (data.content as Record<string, unknown>) ?? {};
  const location = (data.location as Record<string, unknown>) ?? {};
  const admin = (location.admin as Record<string, unknown>) ?? {};

  return {
    source: (data.source as SubmissionDraft['source']) ?? 'app',
    is_simulated: (data.is_simulated as boolean) ?? false,
    occurred_at: (data.occurred_at as string) ?? (data.created_at as string),
    citizen: {
      citizen_hash: (citizen.citizen_hash as string | null) ?? null,
      auth_kind: (citizen.auth_kind as SubmissionDraft['citizen']['auth_kind']) ?? 'firebase_uid',
      display_locale: (citizen.display_locale as SubmissionDraft['citizen']['display_locale']) ?? 'en',
    },
    content: content as SubmissionDraft['content'],
    location: {
      raw_mentions: (location.raw_mentions as string[]) ?? [],
      point: (location.point as { lat: number; lng: number } | null) ?? null,
      method: (location.method as SubmissionDraft['location']['method']) ?? 'none',
      geocode_confidence:
        (location.geocode_confidence as SubmissionDraft['location']['geocode_confidence']) ??
        'none',
      admin: {
        constituency_code: (admin.constituency_code as string) ?? 'PC-MALKAJGIRI',
        mandal_code: (admin.mandal_code as string | null) ?? null,
        lgd_village_code: (admin.lgd_village_code as string | null) ?? null,
        ulb_ward_code: (admin.ulb_ward_code as string | null) ?? null,
      },
    },
    channel_meta: (data.channel_meta as Record<string, unknown>) ?? {},
    consent: (data.consent as SubmissionDraft['consent']) ?? {
      basis: 'direct_submission',
      pii_scrubbed: true,
    },
  };
}

/** Re-queue enrich for submissions stuck without a cluster (e.g. after URL misconfig). */
export async function retryPendingEnrichments(
  db: Firestore,
  submissionIds: string[],
): Promise<{ queued: string[] }> {
  const queued: string[] = [];

  for (const id of submissionIds) {
    const doc = await db.collection('submissions').doc(id).get();
    if (!doc.exists) continue;

    const data = doc.data()!;
    if (data.cluster_id != null) continue;
    if (data.ai != null) continue;

    const draft = docToDraft(data as Record<string, unknown>);
    void enrichSubmission(id, draft).catch((err) => {
      console.error(`Retry enrich failed for ${id}:`, err);
    });
    queued.push(id);
  }

  return { queued };
}
