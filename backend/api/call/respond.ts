import type { VercelRequest, VercelResponse } from '@vercel/node';
import { db } from '../../lib/firebase.js';
import { requireAuth } from '../../lib/auth.js';
import { areFriends, toPublicProfile } from '../../lib/users.js';
import { pushToUser } from '../../lib/fcm.js';
import { roomToken, livekitUrl } from '../../lib/livekit.js';
import { requireMethod, badRequest, str } from '../../lib/http.js';

/** POST /api/call/respond { roomName, callerId, accept: boolean } */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!requireMethod(req, res, 'POST')) return;
  const userId = await requireAuth(req, res);
  if (!userId) return;

  const roomName = str(req.body?.roomName);
  const callerId = str(req.body?.callerId);
  const accept = req.body?.accept === true;
  if (!roomName || !callerId) return badRequest(res, 'roomName and callerId required');

  // Gecikme: arkadaşlık denetimi ve profil okumaları paralel yürür.
  const [friends, meSnap, callerSnap] = await Promise.all([
    areFriends(userId, callerId),
    db().collection('users').doc(userId).get(),
    db().collection('users').doc(callerId).get(),
  ]);
  if (!friends) return res.status(403).json({ error: 'not_friends' });

  if (!accept) {
    await pushToUser(callerId, { type: 'call_rejected', roomName });
    return res.status(200).json({ ok: true });
  }
  const me = toPublicProfile(meSnap);
  const token = await roomToken(roomName, userId, `${me.firstName} ${me.lastName}`);

  await pushToUser(callerId, { type: 'call_accepted', roomName });

  return res.status(200).json({
    livekitToken: token,
    livekitUrl: livekitUrl(),
    callerPublicKey: callerSnap.get('publicKey') ?? null,
  });
}
