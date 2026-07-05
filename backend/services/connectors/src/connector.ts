import type { SubmissionDraft } from '@pp/schema';

/** Raw item pulled from a source before normalization. */
export interface RawInboundItem {
  id: string;
  [key: string]: unknown;
}

/**
 * The connector contract (§8.1). Every intake path — real or mocked —
 * implements this. `toUnifiedSubmission` is the ONLY place source-specific
 * knowledge lives; downstream of intake-api the pipeline cannot tell live
 * from fixture except via the is_simulated flag.
 */
export interface SourceConnector {
  sourceId: 'whatsapp' | 'youtube' | 'pgrs_portal' | 'meta_social';
  mode: 'live' | 'fixture';
  fetchSince(cursor: string | null): Promise<{ items: RawInboundItem[]; nextCursor: string }>;
  toUnifiedSubmission(item: RawInboundItem): SubmissionDraft;
  health(): Promise<{ ok: boolean; detail: string }>;
}
