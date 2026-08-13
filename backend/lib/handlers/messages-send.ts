import type { VercelRequest, VercelResponse } from '@vercel/node';
import { db } from '../firebase.js';
import { requireAuth } from '../auth.js';
import { areFriends, pairId, toPublicProfile } from '../users.js';
import { pushToUser } from '../fcm.js';
import { requireMethod, badRequest, str } from '../http.js';
import { FieldValue } from 'firebase-admin/firestore';

/** POST /api/messages/send { toUserId, ciphertext }
 * ciphertext: istemcide çift-anahtarla (ECDH) şifrelenmiş mesaj.
 * Sunucu ve yönetici içeriği OKUYAMAZ — yalnızca şifreli blob saklanır. */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!requireMethod(req, res, 'POST')) return;
  const userId = await requireAuth(req, res);
  if (!userId) return;

  const toUserId = str(req.body?.toUserId);
  const ciphertext = str(req.body?.ciphertext);
  if (!toUserId || !ciphertext) return badRequest(res, 'toUserId and ciphertext required');
  if (ciphertext.length > 8000) return badRequest(res, 'message too long');
  if (!(await areFriends(userId, toUserId))) {
    return res.status(403).json({ error: 'not_friends' });
  }

  const ref = await db()
    .collection('messages')
    .doc(pairId(userId, toUserId))
    .collection('msgs')
    .add({
      fromUserId: userId,
      toUserId,
      ciphertext,
      sentAt: FieldValue.serverTimestamp(),
      sentAtMs: Date.now(), // istemci sıralaması/artımlı çekme için
    });

  const meSnap = await db().collection('users').doc(userId).get();
  const me = toPublicProfile(meSnap);
  await pushToUser(toUserId, {
    type: 'new_message',
    fromUserId: userId,
    fromName: `${me.firstName} ${me.lastName}`,
    // İçerik şifreli gönderilir; alıcı cihaz çözer. FCM 4KB sınırına takılmasın:
    ...(ciphertext.length <= 3000 ? { ciphertext } : {}),
    messageId: ref.id,
  });

  return res.status(200).json({ messageId: ref.id });
}
