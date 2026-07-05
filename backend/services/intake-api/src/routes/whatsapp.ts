import { Router } from 'express';
import { getDb } from '../firebase.js';
import { hashCitizen, getPepper } from '../crypto.js';
import { ingestDraft } from '../services/ingest.js';
import { redeemLinkCode } from './identity.js';
import type { SubmissionDraft } from '@pp/schema';

const router = Router();

/** Webhook verification handshake (Meta GET challenge). */
router.get('/', (req, res) => {
  const expected = process.env.WA_VERIFY_TOKEN?.trim();
  if (!expected) {
    res.status(503).json({ error: 'WhatsApp webhook is disabled: WA_VERIFY_TOKEN is not configured' });
    return;
  }
  const mode = req.query['hub.mode'];
  const token = req.query['hub.verify_token'];
  const challenge = req.query['hub.challenge'];
  if (mode === 'subscribe' && token === expected) {
    res.status(200).send(String(challenge));
    return;
  }
  res.sendStatus(403);
});

/**
 * Inbound WhatsApp messages (§9.2). Text/voice become Unified Submissions;
 * a "LINK <code>" message redeems an identity-link code; "status" returns
 * the citizen's cluster states. Media fetch → GCS is a Phase-2 TODO (needs
 * WA_TOKEN + a bucket); today we ingest text and note media in channel_meta.
 */
router.post('/', async (req, res) => {
  // Ack fast; Meta retries on non-200.
  res.sendStatus(200);

  try {
    const entry = req.body?.entry?.[0]?.changes?.[0]?.value;
    const message = entry?.messages?.[0];
    if (!message) return;

    const phone = message.from as string;
    const pepper = getPepper();
    const phoneHash = hashCitizen(phone, pepper);

    const text: string | undefined =
      message.text?.body ?? message.button?.text ?? message.interactive?.button_reply?.title;

    if (text) {
      const trimmed = text.trim();
      const linkMatch = trimmed.match(/^LINK\s+([A-Z0-9]{6})$/i);
      if (linkMatch) {
        await redeemLinkCode(linkMatch[1].toUpperCase(), phone);
        return;
      }
      if (/^status$/i.test(trimmed) || /స్టేటస్/.test(trimmed)) {
        // Status query — Phase 3 sends templated reply; log for now.
        console.log(`WhatsApp status query from ${phoneHash}`);
        return;
      }
    }

    const draft: SubmissionDraft = {
      source: 'whatsapp',
      is_simulated: false,
      occurred_at: new Date().toISOString(),
      citizen: {
        citizen_hash: phoneHash,
        auth_kind: 'whatsapp_phone',
        display_locale: 'te',
      },
      content: {
        modality: message.type === 'audio' ? 'voice' : 'text',
        original_text: text ?? null,
        original_language: 'te',
        media: [],
      },
      location: { raw_mentions: [] },
      consent: { basis: 'direct_submission', pii_scrubbed: true },
      channel_meta: {
        wa_message_id: message.id,
        wa_phone_hash: phoneHash,
        profile_name: entry?.contacts?.[0]?.profile?.name ?? null,
        in_service_window: true,
        ...(message.audio ? { wa_media_id: message.audio.id, media_type: 'audio' } : {}),
      },
    } as SubmissionDraft;

    await ingestDraft(getDb(), draft, { citizenHash: phoneHash });
  } catch (err) {
    console.error('WhatsApp webhook processing error:', err);
  }
});

export default router;
