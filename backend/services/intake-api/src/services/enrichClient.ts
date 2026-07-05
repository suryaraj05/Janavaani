import type { SubmissionDraft } from '@pp/schema';
import { getEnrichWorkerUrl } from '../config.js';

export interface EnrichResult {
  submission: Record<string, unknown>;
  cluster_id: string;
}

export async function enrichSubmission(
  submissionId: string,
  draft: SubmissionDraft,
  mediaBase64?: { audio?: string; images?: string[] },
): Promise<EnrichResult> {
  const url = `${getEnrichWorkerUrl()}/enrich`;
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ submission_id: submissionId, draft, mediaBase64 }),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Enrich worker failed (${response.status}): ${text}`);
  }

  return (await response.json()) as EnrichResult;
}
