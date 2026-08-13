import type { VercelRequest, VercelResponse } from '@vercel/node';
import { db } from '../firebase.js';
import { requireAuth } from '../auth.js';
import { pairId } from '../users.js';
import { requireMethod } from '../http.js';

/** POST /api/messages/summary { lastRead?: { [withUserId]: ms } }
 * Her arkadaş için: son mesaj zamanı/yönü + istemcinin son okuma zamanından
 * sonraki okunmamış mesaj sayısı. Ana ekran rozetleri ve sıralama bunun üstünde. */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!requireMethod(req, res, 'POST')) return;
  const userId = await requireAuth(req, res);
  if (!userId) return;

  const lastRead: Record<string, number> =
    (req.body?.lastRead as Record<string, number>) ?? {};

  const friendships = await db()
    .collection('friendships')
    .where('userIds', 'array-contains', userId)
    .get();
  const friendIds = friendships.docs
    .map((d) => (d.get('userIds') as string[]).find((id) => id !== userId))
    .filter((id): id is string => !!id);

  const summaries = await Promise.all(
    friendIds.map(async (withUserId) => {
      const msgs = db()
        .collection('messages')
        .doc(pairId(userId, withUserId))
        .collection('msgs');
      const after = Number(lastRead[withUserId] ?? 0);
      const [lastSnap, unreadSnap] = await Promise.all([
        msgs.orderBy('sentAtMs', 'desc').limit(1).get(),
        msgs
          .where('toUserId', '==', userId)
          .where('sentAtMs', '>', after)
          .count()
          .get(),
      ]);
      const last = lastSnap.docs[0];
      return {
        withUserId,
        lastMs: last ? (last.get('sentAtMs') as number) : 0,
        lastFromMe: last ? last.get('fromUserId') === userId : false,
        unread: unreadSnap.data().count,
      };
    }),
  );

  return res.status(200).json({ summaries });
}
