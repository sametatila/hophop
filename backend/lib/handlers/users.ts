import type { VercelRequest, VercelResponse } from '@vercel/node';
import { db } from '../firebase.js';
import { requireAuth } from '../auth.js';
import { toPublicProfile, pairId } from '../users.js';
import { requireMethod } from '../http.js';

/** GET /api/users — directory of all profiles with friendship status.
 * Non-friends only expose name + photo (no birth date). */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!requireMethod(req, res, 'GET')) return;
  const userId = await requireAuth(req, res);
  if (!userId) return;

  const [usersSnap, friendsSnap, outgoingSnap, incomingSnap] = await Promise.all([
    db().collection('users').get(),
    db().collection('friendships').where('userIds', 'array-contains', userId).get(),
    db().collection('friendRequests')
      .where('fromUserId', '==', userId).where('status', '==', 'pending').get(),
    db().collection('friendRequests')
      .where('toUserId', '==', userId).where('status', '==', 'pending').get(),
  ]);

  const friendPairs = new Set(friendsSnap.docs.map((d) => d.id));
  const outgoing = new Set(outgoingSnap.docs.map((d) => d.get('toUserId') as string));
  const incoming = new Set(incomingSnap.docs.map((d) => d.get('fromUserId') as string));

  const users = usersSnap.docs
    .filter((d) => d.id !== userId)
    .map((d) => ({
      ...toPublicProfile(d),
      friendStatus: friendPairs.has(pairId(userId, d.id))
        ? 'friend'
        : outgoing.has(d.id)
          ? 'requested'
          : incoming.has(d.id)
            ? 'incoming'
            : 'none',
    }));

  return res.status(200).json({ users });
}
