import type { VercelRequest, VercelResponse } from '@vercel/node';
import { requireAuth } from '../auth.js';
import { areFriends } from '../users.js';
import { pushToUser } from '../fcm.js';
import { requireMethod, badRequest, str } from '../http.js';

/** POST /api/call/ringing { roomName, callerId }
 *
 * Aranan cihaz "telefonum ÇALIYOR" der; arayana bildirilir.
 *
 * Neden gerekli: FCM'in gönderimi kabul etmesi telefonun çaldığı anlamına
 * gelmez — cihaz kapalı ya da çevrimdışıysa mesaj sırada bekler. Bu onay
 * olmadan arayan taraf, karşısındakinin telefonu hiç çalmamışken de
 * "aranıyor…" görüp boşuna bekliyordu. */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!requireMethod(req, res, 'POST')) return;
  const userId = await requireAuth(req, res);
  if (!userId) return;

  const roomName = str(req.body?.roomName);
  const callerId = str(req.body?.callerId);
  if (!roomName || !callerId) return badRequest(res, 'roomName and callerId required');
  if (!(await areFriends(userId, callerId))) {
    return res.status(403).json({ error: 'not_friends' });
  }

  await pushToUser(callerId, {
    type: 'call_ringing',
    roomName,
    calleeId: userId,
  });
  return res.status(200).json({ ok: true });
}
