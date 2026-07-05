import { loadEnv } from '@pp/schema';
loadEnv();
import express from 'express';
import { SubmissionDraftSchema } from '@pp/schema';
import { getDb } from './firebase.js';
import { enrichSubmission } from './enrich.js';

const app = express();
const port = Number(process.env.ENRICH_PORT ?? process.env.PORT) || 8081;

app.use(express.json({ limit: '25mb' }));

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'enrich-worker', version: '0.1.0' });
});

app.post('/enrich', async (req, res) => {
  try {
    const { submission_id, draft, mediaBase64 } = req.body as {
      submission_id?: string;
      draft?: unknown;
      mediaBase64?: { audio?: string; images?: string[] };
    };

    if (!submission_id) {
      res.status(400).json({ error: 'submission_id is required' });
      return;
    }

    const parsed = SubmissionDraftSchema.safeParse(draft);
    if (!parsed.success) {
      res.status(400).json({ error: 'Invalid draft', details: parsed.error.flatten() });
      return;
    }

    const result = await enrichSubmission(getDb(), {
      submission_id,
      draft: parsed.data,
      mediaBase64,
    });

    res.json(result);
  } catch (err) {
    console.error('POST /enrich error:', err);
    res.status(500).json({
      error: 'Enrichment failed',
      message: err instanceof Error ? err.message : 'Unknown error',
    });
  }
});

app.listen(port, () => {
  console.log(`enrich-worker listening on port ${port}`);
});

export default app;
