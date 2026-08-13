import type { VercelRequest, VercelResponse } from '@vercel/node';
import { randomBytes } from 'crypto';
import { db } from '../../lib/firebase.js';
import { requireAuth } from '../../lib/auth.js';
import { areFriends, pairId, toPublicProfile } from '../../lib/users.js';
import { pushToUser } from '../../lib/fcm.js';
import { roomToken, livekitUrl } from '../../lib/livekit.js';
import { requireMethod, badRequest, str } from '../../lib/http.js';

/** POST /api/call/initiate { calleeId, video: boolean }
 * Friendship is enforced server-side: non-friends cannot call each other. */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!requireMethod(req, res, 'POST')) return;
  const userId = await requireAuth(req, res);
  if (!userId) return;

  const calleeId = str(req.body?.calleeId);
  const video = req.body?.video === true;
  if (!calleeId) return badRequest(res, 'calleeId required');
  if (!(await areFriends(userId, calleeId))) {
    return res.status(403).json({ error: 'not_friends' });
  }

  const [meSnap, calleeSnap] = await Promise.all([
    db().collection('users').doc(userId).get(),
    db().collection('users').doc(calleeId).get(),
  ]);
  if (!calleeSnap.exists) return res.status(404).json({ error: 'not_found' });

  const me = toPublicProfile(meSnap);
  const callerName = `${me.firstName} ${me.lastName}`;
  const roomName = `${pairId(userId, calleeId)}_${randomBytes(6).toString('hex')}`;
  const token = await roomToken(roomName, userId, callerName);

  await pushToUser(calleeId, {
    type: 'incoming_call',
    roomName,
    callerId: userId,
    callerName,
    video: video ? '1' : '0',
    callerPublicKey: meSnap.get('publicKey') ?? '',
  });

  return res.status(200).json({
    roomName,
    livekitToken: token,
    livekitUrl: livekitUrl(),
    calleePublicKey: calleeSnap.get('publicKey') ?? null,
  });
}
