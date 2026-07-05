/**
 * replay.ts — drip fixture connectors through the LIVE intake pipeline (§8.4).
 * Calls the connectors service /replay endpoint so judges watch simulated
 * records arrive, cluster, and move scores in real time (nothing pre-computed).
 *
 * Usage: tsx scripts/replay.ts [pgrs_portal|meta_social] [limit]
 */
const source = process.argv[2] ?? 'pgrs_portal';
const limit = Number(process.argv[3] ?? 5);
const connectorsUrl = process.env.CONNECTORS_URL?.trim() ?? 'http://localhost:8082';

async function main(): Promise<void> {
  const resp = await fetch(`${connectorsUrl}/replay/${source}?limit=${limit}`, {
    method: 'POST',
  });
  const body = await resp.json();
  console.log(JSON.stringify(body, null, 2));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
