-- Anomaly / burst detection (§3.3) — runs in score-runner's BigQuery pass.
-- Params: @cluster_id
-- burst: last-24h count vs trailing 14-day daily mean.

WITH daily AS (
  SELECT DATE(created_at) AS day, COUNT(*) AS n
  FROM `pp.core.submissions_enriched`
  WHERE cluster_id = @cluster_id
    AND created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 14 DAY)
  GROUP BY 1
),
baseline AS (
  SELECT AVG(n) AS mean_daily FROM daily WHERE day < CURRENT_DATE()
),
today AS (
  SELECT COUNT(*) AS n_last_24h
  FROM `pp.core.submissions_enriched`
  WHERE cluster_id = @cluster_id
    AND created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
)
SELECT
  today.n_last_24h,
  baseline.mean_daily,
  today.n_last_24h > GREATEST(5, 7 * COALESCE(baseline.mean_daily, 0)) AS is_burst
FROM today, baseline;
