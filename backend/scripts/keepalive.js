/**
 * Render keep-alive cron — pings /health on intake-api and enrich-worker.
 * Runs every 10 min via Render Cron Job (see render.yaml).
 * Prevents free-tier services from sleeping after 15 min idle.
 *
 * Manual: INTAKE_API_URL=https://... ENRICH_WORKER_URL=https://... node scripts/keepalive.js
 */
const TIMEOUT_MS = 10_000;

const services = [
  { name: 'intake-api', url: process.env.INTAKE_API_URL },
  { name: 'enrich-worker', url: process.env.ENRICH_WORKER_URL },
].filter((s) => s.url);

async function ping({ name, url }) {
  const target = `${url.replace(/\/$/, '')}/health`;
  const start = Date.now();
  try {
    const res = await fetch(target, { signal: AbortSignal.timeout(TIMEOUT_MS) });
    const body = await res.json();
    const ms = Date.now() - start;
    console.log(`✓ ${name} ${res.status} (${ms}ms) — ${JSON.stringify(body)}`);
  } catch (err) {
    console.error(`✗ ${name} FAILED — ${err instanceof Error ? err.message : err}`);
    process.exit(1);
  }
}

if (services.length === 0) {
  console.error('No URLs set — define INTAKE_API_URL and/or ENRICH_WORKER_URL');
  process.exit(1);
}

await Promise.all(services.map(ping));
console.log(`Keep-alive done — ${services.length} service(s) pinged`);
