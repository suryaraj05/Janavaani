import { readFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import type { SubmissionDraft } from '@pp/schema';
import type { RawInboundItem, SourceConnector } from './connector.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const FIXTURES_DIR = process.env.FIXTURES_DIR ?? join(__dirname, '../../../fixtures');

interface PgrsRecord {
  registration_no: string;
  received_date: string;
  district: string;
  mandal: string;
  grievance_text: string;
  category_as_filed: string;
  status_in_portal: string;
  original_language?: string;
}

/**
 * pgrs_portal (mock, §8.2). Fixture shape mirrors a CPGRAMS-style export so a
 * future MoU-based integration drops in by swapping fetchSince + OAuth only.
 */
export class PgrsPortalConnector implements SourceConnector {
  sourceId = 'pgrs_portal' as const;
  mode = 'fixture' as const;

  async fetchSince(cursor: string | null): Promise<{ items: RawInboundItem[]; nextCursor: string }> {
    const batchFile = join(FIXTURES_DIR, 'pgrs_batch_01.json');
    if (!existsSync(batchFile)) return { items: [], nextCursor: cursor ?? '0' };

    const records = JSON.parse(readFileSync(batchFile, 'utf-8')) as PgrsRecord[];
    const startIndex = cursor ? Number(cursor) : 0;
    const items = records
      .slice(startIndex)
      .map((r) => ({ id: r.registration_no, ...r }) as RawInboundItem);
    return { items, nextCursor: String(records.length) };
  }

  toUnifiedSubmission(item: RawInboundItem): SubmissionDraft {
    const r = item as unknown as PgrsRecord;
    return {
      source: 'portal_mock',
      is_simulated: true,
      occurred_at: new Date(r.received_date).toISOString(),
      citizen: {
        citizen_hash: null,
        auth_kind: 'anonymous',
        display_locale: (r.original_language as 'te' | 'hi' | 'en') ?? 'te',
      },
      content: {
        modality: 'text',
        original_text: r.grievance_text,
        original_language: r.original_language ?? 'te',
        media: [],
      },
      location: {
        raw_mentions: [r.mandal, r.district],
      },
      consent: { basis: 'public_platform', pii_scrubbed: true },
      channel_meta: {
        fixture_file: 'pgrs_batch_01.json',
        mock_registration_no: r.registration_no,
        portal_department: r.category_as_filed,
      },
    } as SubmissionDraft;
  }

  async health(): Promise<{ ok: boolean; detail: string }> {
    const exists = existsSync(join(FIXTURES_DIR, 'pgrs_batch_01.json'));
    return { ok: exists, detail: exists ? 'fixture loaded' : 'pgrs_batch_01.json missing' };
  }
}

interface MetaRecord {
  post_id: string;
  comment_id: string;
  message: string;
  created_time: string;
  lang?: string;
}

/** meta_social (mock, §8.3). Shaped like Graph API comment objects. */
export class MetaSocialConnector implements SourceConnector {
  sourceId = 'meta_social' as const;
  mode = 'fixture' as const;

  async fetchSince(cursor: string | null): Promise<{ items: RawInboundItem[]; nextCursor: string }> {
    const batchFile = join(FIXTURES_DIR, 'meta_batch_01.json');
    if (!existsSync(batchFile)) return { items: [], nextCursor: cursor ?? '0' };
    const records = JSON.parse(readFileSync(batchFile, 'utf-8')) as MetaRecord[];
    const startIndex = cursor ? Number(cursor) : 0;
    const items = records.slice(startIndex).map((r) => ({ id: r.comment_id, ...r }) as RawInboundItem);
    return { items, nextCursor: String(records.length) };
  }

  toUnifiedSubmission(item: RawInboundItem): SubmissionDraft {
    const r = item as unknown as MetaRecord;
    return {
      source: 'meta_mock',
      is_simulated: true,
      occurred_at: new Date(r.created_time).toISOString(),
      citizen: {
        citizen_hash: null,
        auth_kind: 'anonymous',
        display_locale: (r.lang as 'te' | 'hi' | 'en') ?? 'en',
      },
      content: {
        modality: 'video_comment',
        original_text: r.message,
        original_language: r.lang ?? 'en',
        media: [],
      },
      location: { raw_mentions: [] },
      consent: { basis: 'public_platform', pii_scrubbed: true },
      channel_meta: { fixture_file: 'meta_batch_01.json', post_id: r.post_id, comment_id: r.comment_id },
    } as SubmissionDraft;
  }

  async health(): Promise<{ ok: boolean; detail: string }> {
    const exists = existsSync(join(FIXTURES_DIR, 'meta_batch_01.json'));
    return { ok: exists, detail: exists ? 'fixture loaded' : 'meta_batch_01.json missing' };
  }
}
