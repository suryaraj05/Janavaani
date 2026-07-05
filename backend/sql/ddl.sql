-- BigQuery DDL for People's Priorities analytics plane (§2, §5)
-- Datasets: pp.core (operational mirror + vectors), pp.evidence (UDISE+),
-- pp.geo (boundaries). Firestore is the operational source of truth; a
-- one-way sync copies enriched submissions here for clustering + scoring.

CREATE SCHEMA IF NOT EXISTS pp;

-- ─── pp.core ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `pp.core.submissions_enriched` (
  submission_id STRING NOT NULL,
  source STRING,
  is_simulated BOOL,
  created_at TIMESTAMP,
  occurred_at TIMESTAMP,
  citizen_hash STRING,
  original_language STRING,
  text_en STRING,
  canonical_summary_en STRING,
  category STRING,
  subcategory STRING,
  kind STRING,
  urgency STRING,
  triage_confidence FLOAT64,
  lat FLOAT64,
  lng FLOAT64,
  geocode_confidence STRING,
  constituency_code STRING,
  mandal_code STRING,
  lgd_village_code STRING,
  ulb_ward_code STRING,
  cluster_id STRING,
  embedding ARRAY<FLOAT64>          -- 768-dim; NEVER stored in Firestore
);

CREATE TABLE IF NOT EXISTS `pp.core.cluster_centroids` (
  cluster_id STRING NOT NULL,
  category STRING,
  mandal_code STRING,
  centroid_embedding ARRAY<FLOAT64>,
  n INT64
);

CREATE TABLE IF NOT EXISTS `pp.core.clusters` (
  cluster_id STRING NOT NULL,
  canonical_title_en STRING,
  category STRING,
  subcategory STRING,
  mandal_code STRING,
  centroid_geo GEOGRAPHY
);

-- ─── pp.evidence ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `pp.evidence.udise_schools` (
  udise_code STRING,
  school_name STRING,
  mgmt_type STRING,                 -- govt / aided / private
  school_category INT64,
  highest_class INT64,
  lat FLOAT64,
  lng FLOAT64,
  geopoint GEOGRAPHY,
  lgd_village_code STRING,
  block_code STRING,
  enr_g1 INT64, enr_g2 INT64, enr_g3 INT64, enr_g4 INT64, enr_g5 INT64, enr_g6 INT64,
  enr_g7 INT64, enr_g8 INT64, enr_g9 INT64, enr_g10 INT64, enr_g11 INT64, enr_g12 INT64,
  classrooms_good INT64,
  has_electricity BOOL,
  has_drinking_water BOOL,
  toilets_girls INT64,
  teachers_total INT64,
  ref_year STRING                   -- "2024-25"
);

-- ─── pp.geo ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `pp.geo.mandal_boundaries` (
  mandal_code STRING,
  constituency_code STRING,
  name STRING,
  geom GEOGRAPHY
);

CREATE TABLE IF NOT EXISTS `pp.geo.village_boundaries` (
  lgd_code STRING,
  mandal_code STRING,
  geom GEOGRAPHY
);

CREATE TABLE IF NOT EXISTS `pp.geo.mandal_adjacency` (
  mandal_code STRING,
  adjacent_mandal_code STRING
);
