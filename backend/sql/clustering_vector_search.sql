-- Incremental cluster assignment via VECTOR_SEARCH (§4.2)
-- Hard pre-filter (category + mandal/adjacent-mandal) runs before vector math.
-- Params: @category, @candidate_mandals (ARRAY<STRING>), @submission_id, @embedding (ARRAY<FLOAT64>)

SELECT query.submission_id, base.cluster_id, 1 - distance AS similarity
FROM VECTOR_SEARCH(
  (SELECT cluster_id, centroid_embedding
   FROM `pp.core.cluster_centroids`
   WHERE category = @category
     AND mandal_code IN UNNEST(@candidate_mandals)),
  'centroid_embedding',
  (SELECT @submission_id AS submission_id, @embedding AS embedding),
  'embedding', top_k => 5, distance_type => 'COSINE'
);
