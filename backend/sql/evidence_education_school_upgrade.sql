-- Evidence scoring: education.school_upgrade (§5.3)
-- Computes seat_gap, road_km_est, pipeline_per_school per mandal, then
-- percentile-normalizes into E = 0.5·pct(seat_gap) + 0.3·pct(road_km_est) + 0.2·pct(pipeline_per_school).
-- Params: @constituency_code

WITH pipeline AS (
  SELECT b.mandal_code,
         SUM(s.enr_g6 + s.enr_g7 + s.enr_g8) AS upper_primary_pipeline
  FROM `pp.evidence.udise_schools` s
  JOIN `pp.geo.mandal_boundaries` b ON ST_CONTAINS(b.geom, s.geopoint)
  WHERE s.highest_class <= 8 AND s.mgmt_type IN ('govt', 'aided')
    AND b.constituency_code = @constituency_code
  GROUP BY 1
),
capacity AS (
  SELECT b.mandal_code,
         SUM(s.enr_g9 + s.enr_g10) AS current_secondary_enrollment,
         COUNT(*) AS secondary_schools
  FROM `pp.evidence.udise_schools` s
  JOIN `pp.geo.mandal_boundaries` b ON ST_CONTAINS(b.geom, s.geopoint)
  WHERE s.highest_class >= 10 AND s.mgmt_type IN ('govt', 'aided')
    AND b.constituency_code = @constituency_code
  GROUP BY 1
),
access AS (
  SELECT c.cluster_id, c.mandal_code,
         MIN(ST_DISTANCE(c.centroid_geo, s.geopoint)) / 1000 * 1.4 AS road_km_est
  FROM `pp.core.clusters` c
  CROSS JOIN `pp.evidence.udise_schools` s
  WHERE s.highest_class >= 10 AND s.mgmt_type IN ('govt', 'aided')
    AND c.subcategory = 'school_upgrade'
  GROUP BY 1, 2
),
indicators AS (
  SELECT
    p.mandal_code,
    GREATEST(p.upper_primary_pipeline / 3
             - COALESCE(k.current_secondary_enrollment, 0) / 2, 0) AS seat_gap,
    COALESCE(a.road_km_est, 999) AS road_km_est,
    SAFE_DIVIDE(p.upper_primary_pipeline, NULLIF(k.secondary_schools, 0)) AS pipeline_per_school
  FROM pipeline p
  LEFT JOIN capacity k USING (mandal_code)
  LEFT JOIN access a USING (mandal_code)
)
SELECT
  mandal_code,
  seat_gap,
  road_km_est,
  pipeline_per_school,
  0.5 * PERCENT_RANK() OVER (ORDER BY seat_gap)
  + 0.3 * PERCENT_RANK() OVER (ORDER BY road_km_est)
  + 0.2 * PERCENT_RANK() OVER (ORDER BY pipeline_per_school) AS evidence_score
FROM indicators
ORDER BY evidence_score DESC;
