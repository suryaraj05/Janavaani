/** Firestore cluster document shape for E2E verification scripts. */
export interface ClusterScore {
  total?: number;
  demand?: number;
  evidence?: number;
  confidence?: number;
  recency?: number;
  evidence_available?: boolean;
}

export interface ClusterStats {
  unique_citizens?: number;
  submission_count?: number;
}

export interface ClusterJustification {
  text_en?: string;
}

export interface ClusterDoc {
  id: string;
  cluster_id?: string;
  canonical_title_en?: string;
  score?: ClusterScore;
  stats?: ClusterStats;
  justification?: ClusterJustification;
}

export function mapClusterDoc(id: string, data: Record<string, unknown>): ClusterDoc {
  return {
    id,
    cluster_id: data.cluster_id as string | undefined,
    canonical_title_en: data.canonical_title_en as string | undefined,
    score: data.score as ClusterScore | undefined,
    stats: data.stats as ClusterStats | undefined,
    justification: data.justification as ClusterJustification | undefined,
  };
}
