import { loadEnv } from '@pp/schema';
loadEnv();
import express from 'express';
import { getDb } from './firebase.js';
import { runScoring } from './scoring.js';

const app = express();
const port = Number(process.env.SCORE_PORT ?? process.env.PORT) || 8083;

app.use(express.json());

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'score-runner', version: '0.2.0' });
});

/** Triggered by Cloud Scheduler (every 30 min) or manually for the demo. */
app.post('/run', async (_req, res) => {
  try {
    const result = await runScoring(getDb());
    res.json({ ok: true, ...result });
  } catch (err) {
    console.error('score-runner /run error:', err);
    res.status(500).json({
      error: 'Scoring failed',
      message: err instanceof Error ? err.message : 'Unknown error',
    });
  }
});

app.listen(port, () => {
  console.log(`score-runner listening on port ${port}`);
});

export default app;
