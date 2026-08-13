import type { VercelRequest, VercelResponse } from '@vercel/node';
import { db } from '../firebase.js';
import { requireAuth } from '../auth.js';
import { areFriends, pairId, toPublicProfile } from '../users.js';
import { pushToUser } from '../fcm.js';
import { roomToken, livekitUrl } from '../livekit.js';
import { requireMethod, badRequest, str } from '../http.js';

/** Arama olayını sohbet akışına yazar (WhatsApp'taki arama kayıtları gibi).
 * roomName'den türeyen kimlikle idempotent — aynı arama iki kez kaydolmaz. */
export async function logCallEvent(opts: {
  callerId: string;
  calleeId: string;
  video: boolean;
  outcome: 'answered' | 'missed';
  roomName?: string;
}): Promise<void> {
  const { callerId, calleeId, video, outcome, roomName } = opts;
  try {
    await db()
      .collection('messages')
      .doc(pairId(callerId, calleeId))
      .collection('msgs')
      .add({
        kind: 'call',
        fromUserId: callerId,
        toUserId: calleeId,
        callType: video ? 'video' : 'audio',
        outcome,
        roomName: roomName ?? null, // görüşme süresi sonradan bu kimlikle işlenir
        ciphertext: '',
        sentAtMs: Date.now(),
      });
  } catch (e) {
    console.error('call event log failed:', e);
  }
}

/** POST /api/call/respond { roomName, callerId, accept: boolean } */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!requireMethod(req, res, 'POST')) return;
  const userId = await requireAuth(req, res);
  if (!userId) return;

  const roomName = str(req.body?.roomName);
  const callerId = str(req.body?.callerId);
  const accept = req.body?.accept === true;
  const video = req.body?.video === true;
  if (!roomName || !callerId) return badRequest(res, 'roomName and callerId required');

  // Gecikme: arkadaşlık denetimi ve profil okumaları paralel yürür.
  const [friends, meSnap, callerSnap] = await Promise.all([
    areFriends(userId, callerId),
    db().collection('users').doc(userId).get(),
    db().collection('users').doc(callerId).get(),
  ]);
  if (!friends) return res.status(403).json({ error: 'not_friends' });

  // Arama sonuçlandı — yedek zil kaydı temizlenir.
  const clearRing = db().collection('rings').doc(userId).delete().catch(() => {});

  if (!accept) {
    await Promise.all([
      pushToUser(callerId, { type: 'call_rejected', roomName }),
      logCallEvent({ callerId, calleeId: userId, video, outcome: 'missed', roomName }),
      clearRing,
    ]);
    return res.status(200).json({ ok: true });
  }

  await Promise.all([
    logCallEvent({ callerId, calleeId: userId, video, outcome: 'answered', roomName }),
    clearRing,
  ]);
  const me = toPublicProfile(meSnap);
  const token = await roomToken(roomName, userId, `${me.firstName} ${me.lastName}`);

  await pushToUser(callerId, { type: 'call_accepted', roomName });

  return res.status(200).json({
    livekitToken: token,
    livekitUrl: livekitUrl(),
    callerPublicKey: callerSnap.get('publicKey') ?? null,
  });
}
