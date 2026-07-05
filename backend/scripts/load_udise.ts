/**
 * load_udise.ts — load UDISE+ school CSVs into BigQuery pp.evidence.udise_schools.
 * Phase 2. Requires GCP_PROJECT + a service account with BigQuery access.
 *
 * Usage: tsx scripts/load_udise.ts <path-to-udise-csv-dir>
 *
 * Until BigQuery is wired, score-runner reads fixtures/udise_schools.json for
 * the flagship mandal, which is enough to demonstrate evidence-grounded ranking.
 */
import { readFileSync, existsSync } from 'node:fs';

const csvDir = process.argv[2];

async function main(): Promise<void> {
  if (!process.env.GCP_PROJECT) {
    console.log('GCP_PROJECT not set — skipping BigQuery load.');
    console.log('For local dev, score-runner reads fixtures/udise_schools.json instead.');
    return;
  }
  if (!csvDir || !existsSync(csvDir)) {
    console.error('Provide a directory of UDISE+ school CSVs: tsx scripts/load_udise.ts <dir>');
    process.exit(1);
  }
  // TODO(phase2): parse CSV rows -> normalize to udise_schools schema (see sql/ddl.sql)
  // -> BigQuery load job. Kept as a documented stub so the pipeline shape is clear.
  console.log(`Would load UDISE+ CSVs from ${csvDir} into ${process.env.GCP_PROJECT}.pp.evidence.udise_schools`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
