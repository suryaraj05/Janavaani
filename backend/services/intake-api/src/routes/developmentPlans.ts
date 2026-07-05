import { Router } from 'express';
import { getDb } from '../firebase.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

/** List development plans — linked and unlinked (Phase D). */
router.get('/', requireAuth, async (_req, res) => {
  try {
    const snap = await getDb().collection('development_plans').get();
    const plans = snap.docs.map((d) => d.data());
    res.json({ plans });
  } catch (err) {
    console.error('GET /development-plans error:', err);
    res.status(500).json({ error: 'Failed to fetch development plans' });
  }
});

export default router;
