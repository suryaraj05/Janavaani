import { Router, type Request, type Response } from 'express';

import { getDb } from '../firebase.js';
import { admin } from '../firebase.js';
import { requireAuth, requireRole } from '../middleware/auth.js';

const router = Router();

function ok(res: Response, data: Record<string, unknown>): void {
  res.json({ success: true, data });
}

/** Registration always creates/updates a citizen profile — never trusts client role. */
export function roleForRegistration(): 'citizen' {
  return 'citizen';
}

const ELEVATED_ROLES = new Set(['mp', 'mp_staff']);

router.post('/register', async (req, res) => {
  try {
    const { idToken, displayName, displayLocale, phoneNumber, department } = req.body as {
      idToken?: string;
      displayName?: string;
      displayLocale?: string;
      phoneNumber?: string;
      department?: string;
    };

    if (!idToken) {
      res.status(400).json({ success: false, message: 'idToken is required' });
      return;
    }

    const decoded = await admin.auth().verifyIdToken(idToken);
    const userRef = getDb().collection('users').doc(decoded.uid);
    const existing = await userRef.get();
    const existingRole = existing.data()?.role as string | undefined;

    const userData = {
      uid: decoded.uid,
      email: decoded.email ?? null,
      displayName: displayName ?? decoded.name ?? 'Citizen',
      role: existing.exists && existingRole ? existingRole : roleForRegistration(),
      displayLocale: displayLocale ?? 'en',
      phoneNumber: phoneNumber?.trim() || null,
      department: department?.trim() || null,
      createdAt: existing.exists
        ? (existing.data()?.createdAt as string)
        : new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    await userRef.set(userData, { merge: true });
    ok(res, userData);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Registration failed';
    console.error('POST /auth/register error:', message);
    const code = (err as { code?: string })?.code;
    const status = code?.startsWith('auth/') ? 401 : 500;
    res.status(status).json({ success: false, message });
  }
});

/** Login — auto-provisions a citizen profile if Firebase user exists but Firestore doc does not. */
router.post('/login', async (req, res) => {
  try {
    const { idToken } = req.body as { idToken?: string };
    if (!idToken) {
      res.status(400).json({ success: false, message: 'idToken is required' });
      return;
    }

    const decoded = await admin.auth().verifyIdToken(idToken);
    const userRef = getDb().collection('users').doc(decoded.uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      const userData = {
        uid: decoded.uid,
        email: decoded.email ?? null,
        displayName: decoded.name ?? 'Citizen',
        role: 'citizen',
        displayLocale: 'en',
        phoneNumber: null,
        department: null,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };
      await userRef.set(userData);
      ok(res, userData);
      return;
    }

    ok(res, userDoc.data() as Record<string, unknown>);
  } catch (err) {
    console.error('POST /auth/login error:', err);
    res.status(401).json({
      success: false,
      message: err instanceof Error ? err.message : 'Login failed',
    });
  }
});

router.get('/me', requireAuth, async (req: Request, res: Response) => {
  try {
    const uid = req.user!.uid;
    const userRef = getDb().collection('users').doc(uid);
    const userDoc = await userRef.get();
    if (!userDoc.exists) {
      const userData = {
        uid,
        email: req.user!.email ?? null,
        displayName: req.user!.displayName ?? 'Citizen',
        role: 'citizen',
        displayLocale: 'en',
        phoneNumber: null,
        department: null,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };
      await userRef.set(userData);
      ok(res, userData);
      return;
    }
    ok(res, userDoc.data() as Record<string, unknown>);
  } catch (err) {
    console.error('GET /auth/me error:', err);
    res.status(500).json({ success: false, message: 'Failed to load profile' });
  }
});

router.put('/me', requireAuth, async (req, res) => {
  try {
    const updates = req.body as Record<string, unknown>;
    const allowed = ['displayName', 'phoneNumber', 'displayLocale', 'department'];
    const patch: Record<string, unknown> = { updatedAt: new Date().toISOString() };
    for (const key of allowed) {
      if (updates[key] !== undefined) patch[key] = updates[key];
    }
    const ref = getDb().collection('users').doc(req.user!.uid);
    await ref.set(patch, { merge: true });
    const doc = await ref.get();
    ok(res, doc.data() as Record<string, unknown>);
  } catch (err) {
    console.error('PUT /auth/me error:', err);
    res.status(500).json({ success: false, message: 'Update failed' });
  }
});

/** MP-only role elevation — citizens cannot self-promote via register. */
router.put('/users/:uid/role', requireAuth, requireRole('mp'), async (req, res) => {
  try {
    const uid = String(req.params.uid);
    const { role } = req.body as { role?: string };
    if (!role || !ELEVATED_ROLES.has(role)) {
      res.status(400).json({
        success: false,
        message: 'role must be mp or mp_staff',
      });
      return;
    }

    const ref = getDb().collection('users').doc(uid);
    const existing = await ref.get();
    if (!existing.exists) {
      res.status(404).json({ success: false, message: 'User not found' });
      return;
    }

    const patch = {
      role,
      updatedAt: new Date().toISOString(),
    };
    await ref.set(patch, { merge: true });
    const doc = await ref.get();
    ok(res, doc.data() as Record<string, unknown>);
  } catch (err) {
    console.error('PUT /auth/users/:uid/role error:', err);
    res.status(500).json({ success: false, message: 'Role update failed' });
  }
});

export default router;
