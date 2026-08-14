import type { VercelRequest, VercelResponse } from '@vercel/node';
import { db } from '../firebase.js';
import { requireAuth } from '../auth.js';
import { areFriends, toPublicProfile } from '../users.js';
import { pushToUser } from '../fcm.js';
import { participantCount, participantNames } from '../livekit.js';
import { requireMethod, badRequest, str } from '../http.js';

const MAX_PARTICIPANTS = 6;

/** POST /api/call/invite { roomName, calleeId, video, roomKeyEnc }
 * Süren bir aramaya yeni kişi davet eder (grup arama, en fazla 6 kişi).
 * Davet eden ile davet edilen arkadaş olmalı; oda anahtarı davet edene özel
 * sarılmış (roomKeyEnc) gelir — sunucu içeriğini çözemez. */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!requireMethod(req, res, 'POST')) return;
  const userId = await requireAuth(req, res);
  if (!userId) return;

  const roomName = str(req.body?.roomName);
  const calleeId = str(req.body?.calleeId);
  const video = req.body?.video === true;
  const roomKeyEnc = str(req.body?.roomKeyEnc) ?? '';
  if (!roomName || !calleeId) return badRequest(res, 'roomName and calleeId required');
  if (!(await areFriends(userId, calleeId))) {
    return res.status(403).json({ error: 'not_friends' });
  }

  const names = await participantNames(roomName);
  const count = names.length;
  if (count >= MAX_PARTICIPANTS) {
    return res.status(409).json({ error: 'room_full', max: MAX_PARTICIPANTS });
  }

  const meSnap = await db().collection('users').doc(userId).get();
  const me = toPublicProfile(meSnap);

  const ringPayload = {
    type: 'incoming_call',
    roomName,
    callerId: userId,
    callerName: `${me.firstName} ${me.lastName}`,
    video: video ? '1' : '0',
    callerPublicKey: meSnap.get('publicKey') ?? '',
    roomKeyEnc,
    group: '1',
    // Davet edilen "kim var?" diye merak etmesin: odadakilerin adları.
    // FCM data değerleri düz metin olmalı, bu yüzden virgülle birleştirilir.
    participants: names.join(','),
  };

  // Davet de üçlü teslimattan yararlanır: push kaybolsa bile gerçek-zamanlı
  // zil dinleyicisi yakalar; respond'daki zil-belgesi denetimi de bunu bekler.
  await Promise.all([
    pushToUser(calleeId, ringPayload),
    db().collection('rings').doc(calleeId).set({ ...ringPayload, atMs: Date.now() }),
  ]);

  return res.status(200).json({ ok: true, participants: count });
}
