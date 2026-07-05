import type { Firestore } from 'firebase-admin/firestore';
import type { SubmissionDraft } from '@pp/schema';
import { TRIAGE_MODEL } from '@pp/schema';
import { runTriage } from './triage.js';
import {
  geocodeMentions,
  getConstituencyBbox,
  getConstituencyCode,
} from './geocode.js';
import {
  findMatchingCluster,
  createCluster,
  updateClusterStats,
  updateCentroid,
  rescoreAllClusters,
} from './clustering.js';
import { embedText } from './embedding.js';

export interface EnrichRequest {
  submission_id: string;
  draft: SubmissionDraft;
  mediaBase64?: { audio?: string; images?: string[] };
}

export async function enrichSubmission(
  db: Firestore,
  request: EnrichRequest,
): Promise<{ submission: Record<string, unknown>; cluster_id: string }> {
  const { submission_id, draft, mediaBase64 } = request;
  const now = new Date().toISOString();
  const ref = db.collection('submissions').doc(submission_id);
  const existing = await ref.get();
  const raw = existing.data()!;

  const triage = await runTriage({
    text: draft.content.original_text ?? undefined,
    audioBase64: mediaBase64?.audio,
    audioMime: draft.content.media[0]?.mime,
    imagesBase64: mediaBase64?.images,
  });

  const geo = await geocodeMentions(
    triage.location_mentions,
    getConstituencyBbox(),
    draft.location.point ?? null,
  );

  const point =
    geo.geocode_confidence !== 'none'
      ? { lat: geo.lat, lng: geo.lng }
      : (draft.location.point ?? null);

  const ai = {
    canonical_summary_en: triage.canonical_summary_en,
    category: triage.category,
    subcategory: triage.subcategory,
    kind: triage.kind,
    urgency: triage.urgency,
    entities: triage.entities ?? [],
    triage_confidence: triage.triage_confidence,
    model_versions: {
      triage: TRIAGE_MODEL,
      embedding: 'gemini-embedding-001@768',
    },
  };

  const location = {
    raw_mentions: triage.location_mentions.map((m) => m.latin || m.original),
    point,
    method: point && draft.location.point ? 'device_gps' : geo.method,
    geocode_confidence:
      point && draft.location.point ? 'high' : geo.geocode_confidence,
    admin: {
      constituency_code: getConstituencyCode(),
      mandal_code: raw.location?.admin?.mandal_code ?? 'TS-0417',
      lgd_village_code: raw.location?.admin?.lgd_village_code ?? null,
      ulb_ward_code: raw.location?.admin?.ulb_ward_code ?? null,
    },
  };

  const content = {
    ...raw.content,
    original_language: triage.original_language,
    transcript_original: triage.transcript_original ?? null,
    text_en: triage.text_en,
  };

  let clusterId: string;
  let clusterAssignment: Record<string, unknown> | null = null;

  const embedding = await embedText(triage.canonical_summary_en);

  const match = await findMatchingCluster(db, triage.category, embedding, {
    mandalCode: location.admin.mandal_code,
    geocodeConfidence: location.geocode_confidence as 'high' | 'medium' | 'low' | 'none',
  });

  const citizenHash = (raw.citizen as { citizen_hash: string | null }).citizen_hash;
  const source = raw.source as string;

  if (match) {
    clusterId = match.cluster_id;
    clusterAssignment = {
      similarity: match.similarity,
      decided_by: match.decided_by,
      pinned: false,
      at: now,
    };
    await updateClusterStats(db, clusterId, {
      source,
      language: triage.original_language,
      citizenHash,
      now,
      provisional: match.decided_by === 'staff_review',
    });
    await updateCentroid(db, clusterId, triage.category, location.admin.mandal_code, embedding);
    if (match.decided_by === 'staff_review') {
      await db
        .collection('clusters')
        .doc(clusterId)
        .update({
          review_queue: [
            ...(((await db.collection('clusters').doc(clusterId).get()).data()
              ?.review_queue as string[]) ?? []),
            submission_id,
          ],
        });
    }
  } else {
    clusterId = await createCluster(db, {
      category: triage.category,
      subcategory: triage.subcategory,
      canonicalTitle: triage.canonical_summary_en,
      constituencyCode: getConstituencyCode(),
      mandalCode: location.admin.mandal_code,
      point,
      source,
      language: triage.original_language,
      citizenHash,
      now,
    });
    await updateCentroid(db, clusterId, triage.category, location.admin.mandal_code, embedding);
    clusterAssignment = {
      similarity: 1,
      decided_by: 'auto',
      pinned: false,
      at: now,
    };
  }

  const enriched = {
    ...raw,
    content,
    ai,
    location,
    cluster_id: clusterId,
    cluster_assignment: clusterAssignment,
  };

  await ref.set(enriched);
  await rescoreAllClusters(db);

  return { submission: enriched, cluster_id: clusterId };
}
