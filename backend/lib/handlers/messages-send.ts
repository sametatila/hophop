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
  const clientId = str(req.body?.clientId);
  if (!toUserId || !ciphertext) return badRequest(res, 'toUserId and ciphertext required');
  if (ciphertext.length > 8000) return badRequest(res, 'message too long');
  if (clientId && !/^[A-Za-z0-9_-]{8,64}$/.test(clientId)) {
    return badRequest(res, 'invalid clientId');
  }
  if (!(await areFriends(userId, toUserId))) {
    return res.status(403).json({ error: 'not_friends' });
  }

  const msgs = db()
    .collection('messages')
    .doc(pairId(userId, toUserId))
    .collection('msgs');

  // İdempotent gönderim: istemci kimliği belge kimliği olur; aynı mesajın
  // tekrar denemesi İKİNCİ KAYIT OLUŞTURMAZ (yavaş ağda çift mesajı önler).
  const ref = clientId ? msgs.doc(`c_${userId}_${clientId}`) : msgs.doc();
  try {
    await ref.create({
      fromUserId: userId,
      toUserId,
      ciphertext,
      sentAt: FieldValue.serverTimestamp(),
      sentAtMs: Date.now(), // istemci sıralaması/artımlı çekme için
    });
  } catch (e: unknown) {
    const code = (e as { code?: number }).code;
    if (code === 6 /* ALREADY_EXISTS */) {
      return res.status(200).json({ messageId: ref.id, duplicate: true });
    }
    throw e;
  }

  // Push hatası mesajı 'başarısız' göstermesin: kayıt tamam, push en-iyi-çaba.
  try {
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
  } catch (e) {
    console.error('new_message push failed:', e);
  }

  return res.status(200).json({ messageId: ref.id });
}
