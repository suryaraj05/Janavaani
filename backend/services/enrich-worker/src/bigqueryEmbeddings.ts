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
    // Optional dependency: resolved at runtime only when BigQuery is configured.
    // The indirection keeps `@google-cloud/bigquery` out of the build-time type graph
    // so the service compiles and deploys without the package installed.
    const moduleName = '@google-cloud/bigquery';
    const mod = (await import(/* @vite-ignore */ moduleName as string)) as {
      BigQuery: new (opts: { projectId: string }) => {
        dataset: (id: string) => {
          table: (id: string) => { insert: (rows: unknown[]) => Promise<unknown> };
        };
      };
    };
    const bq = new mod.BigQuery({ projectId: project });
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
