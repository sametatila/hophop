import type { VercelRequest, VercelResponse } from '@vercel/node';
import { db } from '../firebase.js';
import { requireAuth } from '../auth.js';
import { requireMethod, badRequest, str } from '../http.js';

/** POST /api/call/ended { roomName, durationSec }
 * Görüşme bitince taraflardan biri süreyi bildirir; sohbet akışındaki arama
 * kaydına işlenir (iki taraf da bildirirse büyük olan kalır). */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!requireMethod(req, res, 'POST')) return;
  const userId = await requireAuth(req, res);
  if (!userId) return;

  const roomName = str(req.body?.roomName);
  const durationSec = Number(req.body?.durationSec);
  if (!roomName || !Number.isFinite(durationSec) || durationSec < 0) {
    return badRequest(res, 'roomName and durationSec required');
  }

  // roomName = <idA>_<idB>_<rastgele>; çağıran taraflardan biri olmalı.
  const parts = roomName.split('_');
  if (parts.length < 3 || !parts.slice(0, 2).includes(userId)) {
    return res.status(403).json({ error: 'not_participant' });
  }
  const pair = `${parts[0]}_${parts[1]}`;

  const snap = await db()
    .collection('messages')
    .doc(pair)
    .collection('msgs')
    .where('roomName', '==', roomName)
    .limit(1)
    .get();
  if (snap.empty) return res.status(404).json({ error: 'not_found' });

  const doc = snap.docs[0];
  const existing = (doc.get('durationSec') as number) ?? 0;
  const capped = Math.min(Math.round(durationSec), 6 * 3600);
  if (capped > existing) {
    await doc.ref.update({ durationSec: capped });
  }
  return res.status(200).json({ ok: true });
}
