/**
 * BigQuery embedding sink (§4.1) — embeddings live in the analytics plane only.
 * Firestore keeps a dev fallback in cluster_centroids; production writes here too.
 */
export async function writeSubmissionEmbedding(params: {
  submissionId: string;
  clusterId: string;
  category: string;
  mandalCode: string | null;
  embedding: number[];
  canonicalSummary: string;
}): Promise<void> {
  const project = process.env.GCP_PROJECT?.trim();
  const dataset = process.env.BQ_DATASET ?? 'pp.core';
  if (!project) return;

  try {
    const { BigQuery } = await import('@google-cloud/bigquery');
    const bq = new BigQuery({ projectId: project });
    await bq.dataset(dataset.split('.')[0]).table('submissions_enriched').insert([
      {
        submission_id: params.submissionId,
        cluster_id: params.clusterId,
        category: params.category,
        mandal_code: params.mandalCode,
        canonical_summary_en: params.canonicalSummary,
        embedding: params.embedding,
        embedded_at: new Date().toISOString(),
      },
    ]);
  } catch (err) {
    console.warn('BigQuery embedding write skipped:', err instanceof Error ? err.message : err);
  }
}
