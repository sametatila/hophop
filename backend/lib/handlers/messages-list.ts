import type { VercelRequest, VercelResponse } from '@vercel/node';
import { db } from '../firebase.js';
import { requireAuth } from '../auth.js';
import { areFriends, pairId } from '../users.js';
import { requireMethod, badRequest, str } from '../http.js';

/** GET /api/messages/list?withUserId=&afterMs=0&limit=100
 * İki arkadaş arasındaki şifreli mesajları döner (yalnızca taraflara). */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!requireMethod(req, res, 'GET')) return;
  const userId = await requireAuth(req, res);
  if (!userId) return;

  const withUserId = str(req.query?.withUserId);
  const afterMs = Number(req.query?.afterMs ?? 0);
  const limit = Math.min(Number(req.query?.limit ?? 100), 200);
  if (!withUserId) return badRequest(res, 'withUserId required');
  if (!(await areFriends(userId, withUserId))) {
    return res.status(403).json({ error: 'not_friends' });
  }

  const snap = await db()
    .collection('messages')
    .doc(pairId(userId, withUserId))
    .collection('msgs')
    .where('sentAtMs', '>', afterMs)
    .orderBy('sentAtMs', 'asc')
    .limit(limit)
    .get();

  const messages = snap.docs.map((d) => ({
    id: d.id,
    fromUserId: d.get('fromUserId'),
    ciphertext: d.get('ciphertext'),
    sentAtMs: d.get('sentAtMs'),
  }));

  return res.status(200).json({ messages });
}
