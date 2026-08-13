import type { VercelRequest, VercelResponse } from '@vercel/node';
import { requireAuth } from '../auth.js';
import { areFriends } from '../users.js';
import { pushToUser } from '../fcm.js';
import { requireMethod, badRequest, str } from '../http.js';
import { logCallEvent } from './call-respond.js';

/** POST /api/call/cancel { roomName, calleeId } — caller gave up; stop ringing. */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!requireMethod(req, res, 'POST')) return;
  const userId = await requireAuth(req, res);
  if (!userId) return;

  const roomName = str(req.body?.roomName);
  const calleeId = str(req.body?.calleeId);
  const video = req.body?.video === true;
  if (!roomName || !calleeId) return badRequest(res, 'roomName and calleeId required');
  if (!(await areFriends(userId, calleeId))) {
    return res.status(403).json({ error: 'not_friends' });
  }

  // Cevapsız arama: hem karşı cihaza sinyal hem sohbet akışına kayıt.
  await Promise.all([
    pushToUser(calleeId, {
      type: 'call_cancelled',
      roomName,
      callerId: userId,
    }),
    logCallEvent({ callerId: userId, calleeId, video, outcome: 'missed' }),
  ]);
  return res.status(200).json({ ok: true });
}
