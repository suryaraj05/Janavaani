import { loadEnv } from '@pp/schema';
loadEnv();
import express from 'express';
import type { SourceConnector } from './connector.js';
import { PgrsPortalConnector, MetaSocialConnector } from './fixtureConnectors.js';
import { YouTubeConnector } from './youtubeConnector.js';

const app = express();
const port = Number(process.env.CONNECTORS_PORT ?? process.env.PORT) || 8082;

app.use(express.json());

const connectors: Record<string, SourceConnector> = {
  pgrs_portal: new PgrsPortalConnector(),
  meta_social: new MetaSocialConnector(),
  youtube: new YouTubeConnector(),
};

const cursors: Record<string, string | null> = {};

function intakeUrl(): string {
  return process.env.INTAKE_API_URL?.trim() ?? 'http://localhost:8080';
}

/**
 * Push one draft through the LIVE intake pipeline (§8.4 — replay, don't
 * preload). Requires a service token so the connector can authenticate as a
 * system principal; falls back to CONNECTOR_TOKEN for local dev.
 */
async function pushDraft(draft: unknown): Promise<boolean> {
  const token = process.env.CONNECTOR_TOKEN?.trim();
  try {
    const resp = await fetch(`${intakeUrl()}/api/v1/ingest`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { 'x-connector-token': token } : {}),
      },
      body: JSON.stringify({ draft }),
    });
    return resp.ok;
  } catch (err) {
    console.warn('pushDraft failed:', err);
    return false;
  }
}

app.get('/health', async (_req, res) => {
  const health: Record<string, unknown> = {};
  for (const [id, c] of Object.entries(connectors)) {
    health[id] = { mode: c.mode, ...(await c.health()) };
  }
  res.json({ status: 'ok', service: 'connectors', version: '0.2.0', connectors: health });
});

/** Drip a batch from one connector through the live pipeline. */
app.post('/replay/:sourceId', async (req, res) => {
  const connector = connectors[req.params.sourceId];
  if (!connector) {
    res.status(404).json({ error: `Unknown connector ${req.params.sourceId}` });
    return;
  }

  const limit = Math.min(Number(req.query.limit) || 5, 50);
  try {
    const { items, nextCursor } = await connector.fetchSince(cursors[connector.sourceId] ?? null);
    const slice = items.slice(0, limit);
    let pushed = 0;
    for (const item of slice) {
      const draft = connector.toUnifiedSubmission(item);
      if (await pushDraft(draft)) pushed++;
      await new Promise((r) => setTimeout(r, 800)); // visible drip for the demo
    }
    cursors[connector.sourceId] = nextCursor;
    res.json({ ok: true, source: connector.sourceId, fetched: items.length, pushed, nextCursor });
  } catch (err) {
    console.error('replay error:', err);
    res.status(500).json({ error: 'replay failed', message: err instanceof Error ? err.message : 'unknown' });
  }
});

app.listen(port, () => {
  console.log(`connectors listening on port ${port}`);
});

export default app;
