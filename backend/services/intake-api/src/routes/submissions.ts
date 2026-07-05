import { Router } from 'express';
import { SubmissionDraftSchema } from '@pp/schema';
import { getDb } from '../firebase.js';
import { hashCitizen, getPepper } from '../crypto.js';
import { requireAuth } from '../middleware/auth.js';
import { ingestDraft } from '../services/ingest.js';
import { retryPendingEnrichments } from '../services/retryEnrich.js';
import { canReadSubmission, isStaffRole } from '../lib/submissionAccess.js';
import {
  filterRealSubmissions,
  fetchRecentFeedSubmissions,
  isDemoSubmission,
} from '../lib/submissionFilters.js';

const router = Router();

router.post('/', requireAuth, async (req, res) => {
  try {
    const body = req.body as {
      draft?: unknown;
      mediaBase64?: { audio?: string; images?: string[] };
    };

    const parsed = SubmissionDraftSchema.safeParse(body.draft ?? body);
    if (!parsed.success) {
      res.status(400).json({ error: 'Invalid submission', details: parsed.error.flatten() });
      return;
    }

    const draft = parsed.data;
    const pepper = getPepper();
    const citizenHash =
      draft.citizen.citizen_hash ?? (req.user ? hashCitizen(req.user.uid, pepper) : null);

    const meta = draft.channel_meta as Record<string, unknown>;
    const title = String(meta.title ?? '').trim();
    if (title && req.user) {
      const fiveMinAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString();
      const recent = await getDb()
        .collection('submissions')
        .where('citizen.citizen_hash', '==', citizenHash)
        .orderBy('created_at', 'desc')
        .limit(20)
        .get()
        .catch(async () =>
          getDb()
            .collection('submissions')
            .where('citizen.citizen_hash', '==', citizenHash)
            .limit(20)
            .get(),
        );

      const duplicate = recent.docs.some((doc) => {
        const d = doc.data();
        const m = d.channel_meta as Record<string, unknown> | undefined;
        const existingTitle = String(m?.title ?? d.ai?.canonical_summary_en ?? '').trim();
        const created = String(d.created_at ?? '');
        return (
          existingTitle.toLowerCase() === title.toLowerCase() &&
          created >= fiveMinAgo
        );
      });

      if (duplicate) {
        res.status(409).json({
          success: false,
          error: 'duplicate',
          message:
            'You recently submitted a report with the same title. Please wait a few minutes or change the title.',
        });
        return;
      }
    }

    const result = await ingestDraft(getDb(), draft, {
      citizenHash,
      mediaBase64: body.mediaBase64,
    });

    res.status(201).json({ success: true, ...result });
  } catch (err) {
    console.error('POST /submissions error:', err);
    res.status(500).json({
      error: 'Failed to process submission',
      message: err instanceof Error ? err.message : 'Unknown error',
    });
  }
});

router.post('/retry-enrich', requireAuth, async (req, res) => {
  try {
    const user = req.user!;
    const pepper = getPepper();
    const userCitizenHash = hashCitizen(user.uid, pepper);
    const db = getDb();

    const snapshot = await db
      .collection('submissions')
      .where('citizen.citizen_hash', '==', userCitizenHash)
      .orderBy('created_at', 'desc')
      .limit(30)
      .get()
      .catch(() =>
        db.collection('submissions').where('citizen.citizen_hash', '==', userCitizenHash).limit(30).get(),
      );

    const pendingIds = snapshot.docs
      .filter((d) => {
        const data = d.data();
        return data.cluster_id == null && data.ai == null && !isDemoSubmission(data as Record<string, unknown>);
      })
      .map((d) => d.id);

    const { queued } = await retryPendingEnrichments(db, pendingIds);
    res.json({ success: true, queued: queued.length, submission_ids: queued });
  } catch (err) {
    console.error('POST /submissions/retry-enrich error:', err);
    res.status(500).json({ error: 'Failed to retry enrichment' });
  }
});

router.get('/feed', requireAuth, async (req, res) => {
  try {
    const limit = Math.min(Number(req.query.limit) || 30, 50);
    const submissions = await fetchRecentFeedSubmissions(getDb(), limit);
    res.json({ submissions });
  } catch (err) {
    console.error('GET /submissions/feed error:', err);
    res.status(500).json({ error: 'Failed to fetch feed' });
  }
});

router.get('/', requireAuth, async (req, res) => {
  try {
    const limit = Math.min(Number(req.query.limit) || 50, 100);
    const scope = String(req.query.scope ?? 'mine');
    const user = req.user!;
    const pepper = getPepper();
    const userCitizenHash = hashCitizen(user.uid, pepper);

    let snapshot;
    if (scope === 'feed' || (isStaffRole(user.role) && scope === 'all')) {
      const submissions = await fetchRecentFeedSubmissions(getDb(), limit);
      res.json({ submissions });
      return;
    }

    if (!isStaffRole(user.role)) {
      try {
        snapshot = await getDb()
          .collection('submissions')
          .where('citizen.citizen_hash', '==', userCitizenHash)
          .orderBy('created_at', 'desc')
          .limit(limit)
          .get();
      } catch {
        snapshot = await getDb()
          .collection('submissions')
          .where('citizen.citizen_hash', '==', userCitizenHash)
          .limit(limit)
          .get();
      }
    } else {
      snapshot = await getDb()
        .collection('submissions')
        .orderBy('created_at', 'desc')
        .limit(limit)
        .get();
    }
    const raw = snapshot.docs.map((doc) => doc.data() as Record<string, unknown>);
    const submissions = filterRealSubmissions(raw);

    if (scope === 'mine' && !isStaffRole(user.role)) {
      const pendingIds = snapshot.docs
        .filter((d) => {
          const data = d.data();
          return data.cluster_id == null && data.ai == null;
        })
        .slice(0, 5)
        .map((d) => d.id);
      if (pendingIds.length > 0) {
        void retryPendingEnrichments(getDb(), pendingIds);
      }
    }

    res.json({ submissions });
  } catch (err) {
    console.error('GET /submissions error:', err);
    res.status(500).json({ error: 'Failed to fetch submissions' });
  }
});

/** Toggle upvote on a submission — one vote per Firebase UID. Client re-sorts feed. */
router.post('/:id/upvote', requireAuth, async (req, res) => {
  try {
    const submissionId = String(req.params.id);
    const uid = req.user!.uid;
    const ref = getDb().collection('submissions').doc(submissionId);
    const doc = await ref.get();
    if (!doc.exists) {
      res.status(404).json({ error: 'Submission not found' });
      return;
    }

    const data = doc.data()!;
    if (isDemoSubmission(data as Record<string, unknown>)) {
      res.status(404).json({ error: 'Submission not found' });
      return;
    }

    const meta = (data.channel_meta as Record<string, unknown>) ?? {};
    const upvotedBy = [...((meta.upvoted_by as string[]) ?? [])];
    const already = upvotedBy.includes(uid);

    if (already) {
      upvotedBy.splice(upvotedBy.indexOf(uid), 1);
    } else {
      upvotedBy.push(uid);
    }

    const upvotes = upvotedBy.length;
    await ref.update({
      'channel_meta.upvotes': upvotes,
      'channel_meta.upvoted_by': upvotedBy,
    });

    res.json({ success: true, upvotes, upvoted: !already, upvoted_by: upvotedBy });
  } catch (err) {
    console.error('POST /submissions/:id/upvote error:', err);
    res.status(500).json({ error: 'Failed to toggle upvote' });
  }
});

router.get('/:id', requireAuth, async (req, res) => {
  const id = String(req.params.id);
  const doc = await getDb().collection('submissions').doc(id).get();
  if (!doc.exists) {
    res.status(404).json({ error: 'Submission not found' });
    return;
  }

  const data = doc.data()!;
  if (isDemoSubmission(data as Record<string, unknown>)) {
    res.status(404).json({ error: 'Submission not found' });
    return;
  }
  const user = req.user!;
  const userCitizenHash = hashCitizen(user.uid, getPepper());
  const submissionHash = (data.citizen as { citizen_hash?: string })?.citizen_hash;

  if (!canReadSubmission(user, submissionHash, userCitizenHash)) {
    res.status(403).json({ error: 'Forbidden' });
    return;
  }

  res.json({ submission: data });
});

export default router;
