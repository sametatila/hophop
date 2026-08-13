import type { VercelRequest, VercelResponse } from '@vercel/node';
import { db } from '../../lib/firebase.js';
import { requireAuth } from '../../lib/auth.js';
import { pairId, toPublicProfile } from '../../lib/users.js';
import { pushToUser } from '../../lib/fcm.js';
import { requireMethod, badRequest, str } from '../../lib/http.js';
import { FieldValue } from 'firebase-admin/firestore';

/** POST /api/friends/respond { requestId, accept: boolean } */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!requireMethod(req, res, 'POST')) return;
  const userId = await requireAuth(req, res);
  if (!userId) return;

  const requestId = str(req.body?.requestId);
  const accept = req.body?.accept === true;
  if (!requestId) return badRequest(res, 'requestId required');

  const ref = db().collection('friendRequests').doc(requestId);
  const snap = await ref.get();
  if (!snap.exists || snap.get('toUserId') !== userId || snap.get('status') !== 'pending') {
    return res.status(404).json({ error: 'not_found' });
  }
  const fromUserId = snap.get('fromUserId') as string;

  if (!accept) {
    await ref.update({ status: 'rejected' });
    return res.status(200).json({ ok: true });
  }

  await db().collection('friendships').doc(pairId(userId, fromUserId)).set({
    userIds: [userId, fromUserId].sort(),
    since: FieldValue.serverTimestamp(),
  });
  await ref.update({ status: 'accepted' });

  const me = await db().collection('users').doc(userId).get();
  const myProfile = toPublicProfile(me);
  await pushToUser(fromUserId, {
    type: 'request_accepted',
    byUserId: userId,
    byName: `${myProfile.firstName} ${myProfile.lastName}`,
  });

  return res.status(200).json({ ok: true });
}
