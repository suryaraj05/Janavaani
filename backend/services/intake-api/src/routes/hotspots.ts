import { Router } from 'express';
import { getDb } from '../firebase.js';
import { requireAuth } from '../middleware/auth.js';
import { aggregateMandalHotspots } from '../lib/hotspotAggregation.js';

const router = Router();

/** Mandal-level demand aggregation for hotspot choropleth (Phase B). */
router.get('/mandals', requireAuth, async (_req, res) => {
  try {
    const mandals = await aggregateMandalHotspots(getDb());
    res.json({ mandals });
  } catch (err) {
    console.error('GET /hotspots/mandals error:', err);
    res.status(500).json({ error: 'Failed to aggregate mandal hotspots' });
  }
});

export default router;
