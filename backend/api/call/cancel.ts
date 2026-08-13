import type { VercelRequest, VercelResponse } from '@vercel/node';
import { requireAuth } from '../../lib/auth.js';
import { areFriends } from '../../lib/users.js';
import { pushToUser } from '../../lib/fcm.js';
import { requireMethod, badRequest, str } from '../../lib/http.js';

/** POST /api/call/cancel { roomName, calleeId } — caller gave up; stop ringing. */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!requireMethod(req, res, 'POST')) return;
  const userId = await requireAuth(req, res);
  if (!userId) return;

  const roomName = str(req.body?.roomName);
  const calleeId = str(req.body?.calleeId);
  if (!roomName || !calleeId) return badRequest(res, 'roomName and calleeId required');
  if (!(await areFriends(userId, calleeId))) {
    return res.status(403).json({ error: 'not_friends' });
  }

  await pushToUser(calleeId, { type: 'call_cancelled', roomName });
  return res.status(200).json({ ok: true });
}
