import type { VercelRequest, VercelResponse } from '@vercel/node';
import { requireAuth } from '../auth.js';
import { areFriends } from '../users.js';
import { pushToUser } from '../fcm.js';
import { requireMethod, badRequest, str } from '../http.js';

/** POST /api/messages/typing { toUserId }
 * "Yazıyor…" sinyali — içeriksiz, kısa ömürlü data push (istemci ~4 sn'de bir
 * kısar; alıcı 5 sn göstermezse söndürür). */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!requireMethod(req, res, 'POST')) return;
  const userId = await requireAuth(req, res);
  if (!userId) return;

  const toUserId = str(req.body?.toUserId);
  if (!toUserId) return badRequest(res, 'toUserId required');
  if (!(await areFriends(userId, toUserId))) {
    return res.status(403).json({ error: 'not_friends' });
  }

  await pushToUser(toUserId, { type: 'typing', fromUserId: userId });
  return res.status(200).json({ ok: true });
}
