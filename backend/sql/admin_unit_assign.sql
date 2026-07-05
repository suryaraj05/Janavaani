-- Admin-unit assignment via GIS join (§5.1)
-- Mandal is the guaranteed floor; village/ward are bonus precision.
-- Params: @id

UPDATE `pp.core.submissions_enriched` s
SET s.mandal_code = b.mandal_code,
    s.lgd_village_code = v.lgd_code,
    s.constituency_code = b.constituency_code
FROM `pp.geo.mandal_boundaries` b
LEFT JOIN `pp.geo.village_boundaries` v
  ON ST_CONTAINS(v.geom, ST_GEOGPOINT(s.lng, s.lat))
WHERE ST_CONTAINS(b.geom, ST_GEOGPOINT(s.lng, s.lat))
  AND s.submission_id = @id;
