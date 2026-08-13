import type { VercelRequest, VercelResponse } from '@vercel/node';
import { randomBytes } from 'crypto';
import { db } from '../../lib/firebase.js';
import { requireAuth } from '../../lib/auth.js';
import { areFriends, pairId, toPublicProfile } from '../../lib/users.js';
import { pushToUser } from '../../lib/fcm.js';
import { roomToken, livekitUrl } from '../../lib/livekit.js';
import { requireMethod, badRequest, str } from '../../lib/http.js';

/** POST /api/call/initiate { calleeId, video: boolean, roomKeyEnc }
 * roomKeyEnc: arayanın ürettiği oda anahtarının, aranana özel sarılmış hali.
 * Sunucu için opak bir dizedir — E2EE anahtarı sunucuda asla açık durmaz.
 * Friendship is enforced server-side: non-friends cannot call each other. */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!requireMethod(req, res, 'POST')) return;
  const userId = await requireAuth(req, res);
  if (!userId) return;

  const calleeId = str(req.body?.calleeId);
  const video = req.body?.video === true;
  const roomKeyEnc = str(req.body?.roomKeyEnc) ?? '';
  if (!calleeId) return badRequest(res, 'calleeId required');

  // Gecikme: arkadaşlık denetimi ve profil okumaları paralel yürür.
  const [friends, meSnap, calleeSnap] = await Promise.all([
    areFriends(userId, calleeId),
    db().collection('users').doc(userId).get(),
    db().collection('users').doc(calleeId).get(),
  ]);
  if (!friends) return res.status(403).json({ error: 'not_friends' });
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
    roomKeyEnc,
  });

  return res.status(200).json({
    roomName,
    livekitToken: token,
    livekitUrl: livekitUrl(),
    calleePublicKey: calleeSnap.get('publicKey') ?? null,
  });
}
