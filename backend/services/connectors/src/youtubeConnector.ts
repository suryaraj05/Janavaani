import type { SubmissionDraft } from '@pp/schema';
import type { RawInboundItem, SourceConnector } from './connector.js';

interface YtComment {
  comment_id: string;
  thread_id: string;
  video_id: string;
  text: string;
  like_count: number;
  author_channel_id: string;
  published_at: string;
}

/**
 * YouTube poller (LIVE, §1.3). Uses commentThreads.list (1 unit/call). When
 * YOUTUBE_API_KEY + YOUTUBE_VIDEO_IDS are absent it reports unconfigured and
 * fetches nothing — no fixtures, because this channel is meant to be real.
 */
export class YouTubeConnector implements SourceConnector {
  sourceId = 'youtube' as const;
  mode = 'live' as const;

  private get apiKey(): string | undefined {
    return process.env.YOUTUBE_API_KEY?.trim();
  }

  private get videoIds(): string[] {
    return (process.env.YOUTUBE_VIDEO_IDS?.trim() ?? '')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
  }

  async fetchSince(cursor: string | null): Promise<{ items: RawInboundItem[]; nextCursor: string }> {
    if (!this.apiKey || this.videoIds.length === 0) {
      return { items: [], nextCursor: cursor ?? '' };
    }

    const items: RawInboundItem[] = [];
    for (const videoId of this.videoIds) {
      const url =
        `https://www.googleapis.com/youtube/v3/commentThreads?` +
        new URLSearchParams({
          part: 'snippet',
          videoId,
          maxResults: '50',
          order: 'time',
          key: this.apiKey,
        });
      try {
        const resp = await fetch(url);
        if (!resp.ok) continue;
        const data = (await resp.json()) as {
          items?: Array<{
            id: string;
            snippet: {
              topLevelComment: {
                id: string;
                snippet: {
                  textOriginal: string;
                  likeCount: number;
                  authorChannelId?: { value: string };
                  publishedAt: string;
                };
              };
            };
          }>;
        };
        for (const t of data.items ?? []) {
          const c = t.snippet.topLevelComment.snippet;
          items.push({
            id: t.snippet.topLevelComment.id,
            comment_id: t.snippet.topLevelComment.id,
            thread_id: t.id,
            video_id: videoId,
            text: c.textOriginal,
            like_count: c.likeCount,
            author_channel_id: c.authorChannelId?.value ?? 'unknown',
            published_at: c.publishedAt,
          } as RawInboundItem);
        }
      } catch (err) {
        console.warn(`YouTube fetch failed for ${videoId}:`, err);
      }
    }
    return { items, nextCursor: new Date().toISOString() };
  }

  toUnifiedSubmission(item: RawInboundItem): SubmissionDraft {
    const c = item as unknown as YtComment;
    return {
      source: 'youtube',
      is_simulated: false,
      occurred_at: new Date(c.published_at).toISOString(),
      citizen: {
        citizen_hash: null,
        auth_kind: 'youtube_channel',
        display_locale: 'en',
      },
      content: {
        modality: 'video_comment',
        original_text: c.text,
        original_language: 'en',
        media: [],
      },
      location: { raw_mentions: [] },
      consent: { basis: 'public_platform', pii_scrubbed: true },
      channel_meta: {
        video_id: c.video_id,
        comment_id: c.comment_id,
        thread_id: c.thread_id,
        like_count: c.like_count,
      },
    } as SubmissionDraft;
  }

  async health(): Promise<{ ok: boolean; detail: string }> {
    if (!this.apiKey) return { ok: false, detail: 'YOUTUBE_API_KEY not set' };
    if (this.videoIds.length === 0) return { ok: false, detail: 'YOUTUBE_VIDEO_IDS not set' };
    return { ok: true, detail: `polling ${this.videoIds.length} video(s)` };
  }
}
