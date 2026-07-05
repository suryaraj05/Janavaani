import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { l2normalize } from '../../services/enrich-worker/src/embedding.js';
import {
  pickClusterMatch,
  AUTO_MERGE_THRESHOLD,
  type ClusterCandidate,
} from '../../services/enrich-worker/src/clustering.js';

/** Build a unit vector peaked at `dim` for controlled similarity tests. */
function unitVector(dim: number, noiseDim?: number): number[] {
  const v = new Array(768).fill(0);
  v[dim] = 1;
  if (noiseDim != null) v[noiseDim] = 0.02;
  return l2normalize(v);
}

/**
 * Phase A acceptance test — incremental cluster assignment with controlled embeddings.
 * Four submissions for the same underlying need must converge to ONE cluster;
 * a clearly different need must form a separate cluster.
 */
describe('cluster assignment integration (Phase A)', () => {
  const schoolBase = unitVector(42);
  const itiBase = unitVector(200);

  const schoolSubmissions = [
    { id: 'sub_a_te', vector: l2normalize(schoolBase.map((v, i) => v + (i === 43 ? 0.01 : 0))) },
    { id: 'sub_a_hi', vector: l2normalize(schoolBase.map((v, i) => v + (i === 44 ? 0.01 : 0))) },
    { id: 'sub_a_en', vector: l2normalize(schoolBase.map((v, i) => v + (i === 45 ? 0.01 : 0))) },
    { id: 'sub_a_wa', vector: l2normalize(schoolBase.map((v, i) => v + (i === 46 ? 0.01 : 0))) },
  ];

  const itiSubmission = { id: 'sub_b_iti', vector: itiBase };

  function assignIncremental(
    submissions: Array<{ id: string; vector: number[] }>,
  ): Map<string, string> {
    const assignment = new Map<string, string>();
    const clusters = new Map<string, { embedding: number[]; n: number }>();

    for (const sub of submissions) {
      const candidates: ClusterCandidate[] = [];
      for (const [clusterId, c] of clusters) {
        candidates.push({ cluster_id: clusterId, mandal_code: 'TS-0417', embedding: c.embedding });
      }

      const match = pickClusterMatch(sub.vector, candidates);
      let clusterId: string;

      if (match) {
        clusterId = match.cluster_id;
        assert.ok(match.similarity >= AUTO_MERGE_THRESHOLD * 0.95);
        const c = clusters.get(clusterId)!;
        const merged = c.embedding.map((v, i) => (c.n * v + sub.vector[i]) / (c.n + 1));
        clusters.set(clusterId, { embedding: l2normalize(merged), n: c.n + 1 });
      } else {
        clusterId = `clu_${sub.id}`;
        clusters.set(clusterId, { embedding: sub.vector, n: 1 });
      }

      assignment.set(sub.id, clusterId);
    }

    return assignment;
  }

  it('merges 4 cross-channel school submissions into one cluster', () => {
    const assignments = assignIncremental(schoolSubmissions);
    const clusterIds = new Set(assignments.values());
    assert.equal(clusterIds.size, 1, `expected 1 school cluster, got ${clusterIds.size}`);
  });

  it('keeps ITI vocational demand in a separate cluster from school upgrade', () => {
    const all = [...schoolSubmissions, itiSubmission];
    const assignments = assignIncremental(all);
    const schoolCluster = assignments.get('sub_a_te')!;
    const itiCluster = assignments.get('sub_b_iti')!;
    assert.notEqual(schoolCluster, itiCluster);
    assert.ok(schoolSubmissions.every((s) => assignments.get(s.id) === schoolCluster));
  });
});
