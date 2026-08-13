import type { VercelRequest, VercelResponse } from '@vercel/node';
import { db } from '../firebase.js';
import { requireAuth } from '../auth.js';
import { toFriendProfile } from '../users.js';
import { requireMethod } from '../http.js';

/** GET /api/friends — full profiles (with birth date + public key) of friends. */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!requireMethod(req, res, 'GET')) return;
  const userId = await requireAuth(req, res);
  if (!userId) return;

  const friendships = await db()
    .collection('friendships')
    .where('userIds', 'array-contains', userId)
    .get();

  const friendIds = friendships.docs
    .map((d) => (d.get('userIds') as string[]).find((id) => id !== userId))
    .filter((id): id is string => !!id);

  const docs = await Promise.all(
    friendIds.map((id) => db().collection('users').doc(id).get()),
  );
  const friends = docs.filter((d) => d.exists).map(toFriendProfile);
  return res.status(200).json({ friends });
}
