import { Router } from 'express';
import { SubmissionDraftSchema } from '@pp/schema';
import { getDb } from '../firebase.js';
import { hashCitizen, getPepper } from '../crypto.js';
import { ingestDraft } from '../services/ingest.js';
import { assertConnectorToken } from '../lib/connectorAuth.js';

const router = Router();

/**
 * Connector ingest (§8). Authenticated by a shared connector token rather than
 * a citizen JWT. Every draft here carries its own source + is_simulated flag.
 */
router.post('/', async (req, res) => {
  const auth = assertConnectorToken(process.env.CONNECTOR_TOKEN, req.headers['x-connector-token']);
  if (!auth.ok) {
    res.status(auth.status).json({ error: auth.error });
    return;
  }

  try {
    const body = req.body as {
      draft?: unknown;
      mediaBase64?: { audio?: string; images?: string[] };
    };
    const parsed = SubmissionDraftSchema.safeParse(body.draft ?? body);
    if (!parsed.success) {
      res.status(400).json({ error: 'Invalid draft', details: parsed.error.flatten() });
      return;
    }

    const draft = parsed.data;
    let citizenHash = draft.citizen.citizen_hash;
    const pseudo =
      (draft.channel_meta?.author_channel_id as string | undefined) ??
      (draft.channel_meta?.wa_phone as string | undefined);
    if (!citizenHash && pseudo) {
      citizenHash = hashCitizen(pseudo, getPepper());
    }

    const result = await ingestDraft(getDb(), draft, { citizenHash: citizenHash ?? null });
    res.status(201).json(result);
  } catch (err) {
    console.error('POST /ingest error:', err);
    res.status(500).json({
      error: 'Ingest failed',
      message: err instanceof Error ? err.message : 'Unknown error',
    });
  }
});

export default router;
