import { Router } from 'express';
import { getDb } from '../firebase.js';
import { hashCitizen, getPepper } from '../crypto.js';
import { requireAuth } from '../middleware/auth.js';
import { recomputeClusterCitizenCounts } from '../lib/clusterStats.js';

const router = Router();

function randomCode(): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = '';
  for (let i = 0; i < 6; i++) code += alphabet[Math.floor(Math.random() * alphabet.length)];
  return code;
}

/**
 * Identity linking via WhatsApp possession proof (§3.2). The app requests a
 * one-time code, the citizen sends it to the WhatsApp number (inbound = free),
 * and the webhook redeems it — unifying citizen_hash on the phone HMAC.
 */
router.post('/whatsapp/start', requireAuth, async (req, res) => {
  const code = randomCode();
  const expiresAt = Date.now() + 10 * 60 * 1000;
  await getDb()
    .collection('link_codes')
    .doc(code)
    .set({ uid: req.user!.uid, code, expiresAt, redeemed: false });

  const waNumber = process.env.WA_BOT_NUMBER?.trim() ?? '';
  const deepLink = waNumber
    ? `https://wa.me/${waNumber}?text=${encodeURIComponent(`LINK ${code}`)}`
    : null;

  res.json({ code, deepLink, expiresIn: 600 });
});

/**
 * Redeem a LINK code (called by the WhatsApp webhook). Rewrites citizen_hash on
 * the citizen's prior submissions from firebase_uid HMAC to phone HMAC, then
 * adjusts affected clusters' unique_citizens so cross-channel users count once.
 */
export async function redeemLinkCode(code: string, phone: string): Promise<boolean> {
  const db = getDb();
  const ref = db.collection('link_codes').doc(code);
  const doc = await ref.get();
  if (!doc.exists) return false;

  const data = doc.data()!;
  if (data.redeemed || Date.now() > (data.expiresAt as number)) return false;

  const pepper = getPepper();
  const uidHash = hashCitizen(data.uid as string, pepper);
  const phoneHash = hashCitizen(phone, pepper);

  const prior = await db
    .collection('submissions')
    .where('citizen.citizen_hash', '==', uidHash)
    .get();

  const affectedClusters = new Set<string>();
  const batch = db.batch();
  for (const s of prior.docs) {
    const clusterId = s.data().cluster_id as string | undefined;
    if (clusterId) affectedClusters.add(clusterId);
    batch.update(s.ref, { 'citizen.citizen_hash': phoneHash });
  }
  batch.update(ref, { redeemed: true, redeemedAt: new Date().toISOString(), phoneHash });
  await batch.commit();

  for (const clusterId of affectedClusters) {
    await recomputeClusterCitizenCounts(db, clusterId);
  }

  return true;
}

export default router;
