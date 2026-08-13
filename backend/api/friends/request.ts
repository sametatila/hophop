import type { VercelRequest, VercelResponse } from '@vercel/node';
import { db } from '../../lib/firebase.js';
import { requireAuth } from '../../lib/auth.js';
import { areFriends, toPublicProfile } from '../../lib/users.js';
import { pushToUser } from '../../lib/fcm.js';
import { requireMethod, badRequest, str } from '../../lib/http.js';
import { FieldValue } from 'firebase-admin/firestore';

/**
 * POST /api/friends/request { toUserId }            → send request
 * POST /api/friends/request { cancelRequestId }     → cancel own pending request
 */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!requireMethod(req, res, 'POST')) return;
  const userId = await requireAuth(req, res);
  if (!userId) return;

  const cancelId = str(req.body?.cancelRequestId);
  if (cancelId) {
    const ref = db().collection('friendRequests').doc(cancelId);
    const snap = await ref.get();
    if (!snap.exists || snap.get('fromUserId') !== userId) {
      return res.status(404).json({ error: 'not_found' });
    }
    await ref.delete();
    return res.status(200).json({ ok: true });
  }

  const toUserId = str(req.body?.toUserId);
  if (!toUserId) return badRequest(res, 'toUserId required');
  if (toUserId === userId) return badRequest(res, 'cannot befriend yourself');

  const target = await db().collection('users').doc(toUserId).get();
  if (!target.exists) return res.status(404).json({ error: 'not_found' });
  if (await areFriends(userId, toUserId)) return badRequest(res, 'already friends');

  const dup = await db()
    .collection('friendRequests')
    .where('fromUserId', 'in', [userId, toUserId])
    .where('status', '==', 'pending')
    .get();
  const exists = dup.docs.some(
    (d) =>
      (d.get('fromUserId') === userId && d.get('toUserId') === toUserId) ||
      (d.get('fromUserId') === toUserId && d.get('toUserId') === userId),
  );
  if (exists) return badRequest(res, 'request already pending');

  const me = await db().collection('users').doc(userId).get();
  const myProfile = toPublicProfile(me);

  const ref = await db().collection('friendRequests').add({
    fromUserId: userId,
    toUserId,
    status: 'pending',
    createdAt: FieldValue.serverTimestamp(),
  });

  await pushToUser(toUserId, {
    type: 'friend_request',
    requestId: ref.id,
    fromUserId: userId,
    fromName: `${myProfile.firstName} ${myProfile.lastName}`,
  });

  return res.status(200).json({ requestId: ref.id });
}
