import type { VercelRequest, VercelResponse } from '@vercel/node';
import { db } from '../../lib/firebase.js';
import { requireAdmin } from '../../lib/auth.js';
import { toPublicProfile } from '../../lib/users.js';
import { requireMethod, str } from '../../lib/http.js';

/**
 * GET    /api/admin/users                      → list all users (name + id only)
 * DELETE /api/admin/users { userId }           → remove a user and their relations
 * (X-Admin-Secret header)
 */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!requireMethod(req, res, 'GET', 'DELETE')) return;
  if (!requireAdmin(req, res)) return;

  if (req.method === 'GET') {
    const snap = await db().collection('users').get();
    const users = snap.docs.map((d) => ({
      ...toPublicProfile(d),
      photoBase64: undefined,
      hasPublicKey: !!d.get('publicKey'),
      devices: (d.get('fcmTokens') ?? []).length,
    }));
    return res.status(200).json({ users });
  }

  const userId = str(req.body?.userId);
  if (!userId) return res.status(400).json({ error: 'bad_request', message: 'userId required' });

  const batch = db().batch();
  batch.delete(db().collection('users').doc(userId));
  const [friendships, sent, received] = await Promise.all([
    db().collection('friendships').where('userIds', 'array-contains', userId).get(),
    db().collection('friendRequests').where('fromUserId', '==', userId).get(),
    db().collection('friendRequests').where('toUserId', '==', userId).get(),
  ]);
  [...friendships.docs, ...sent.docs, ...received.docs].forEach((d) => batch.delete(d.ref));
  await batch.commit();

  return res.status(200).json({ ok: true });
}
