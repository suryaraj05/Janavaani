/**
 * load_boundaries.ts — load mandal/village boundary GeoJSON into BigQuery
 * pp.geo.* and precompute mandal_adjacency via ST_TOUCHES. Phase 2.
 *
 * Usage: tsx scripts/load_boundaries.ts <mandal.geojson> <village.geojson>
 *
 * Boundary sources: DataMeet / state open-data shapefiles (mandal + constituency)
 * and the Local Government Directory (LGD) for village codes.
 */
async function main(): Promise<void> {
  if (!process.env.GCP_PROJECT) {
    console.log('GCP_PROJECT not set — skipping BigQuery boundary load.');
    console.log('Local dev uses mandal_code assignment stubs in enrich-worker.');
    return;
  }
  // TODO(phase2): read GeoJSON -> BigQuery GEOGRAPHY load -> build mandal_adjacency.
  console.log('Would load boundaries + build mandal_adjacency (see sql/ddl.sql).');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
