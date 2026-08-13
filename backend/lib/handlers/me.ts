import type { VercelRequest, VercelResponse } from '@vercel/node';
import { db } from '../firebase.js';
import { requireAuth } from '../auth.js';
import { toFriendProfile } from '../users.js';
import { requireMethod, badRequest, str } from '../http.js';
import { FieldValue } from 'firebase-admin/firestore';

/**
 * GET  /api/me                → own profile
 * POST /api/me                → update own mutable fields:
 *   { photoBase64? }            profile photo (compressed jpeg, ≤ 100 KB)
 *   { publicKey? }              X25519 public key (base64)
 *   { addFcmToken? }            register a device push token
 *   { removeFcmToken? }         unregister a device push token
 */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!requireMethod(req, res, 'GET', 'POST')) return;
  const userId = await requireAuth(req, res);
  if (!userId) return;

  const ref = db().collection('users').doc(userId);

  if (req.method === 'GET') {
    const snap = await ref.get();
    if (!snap.exists) return res.status(404).json({ error: 'not_found' });
    return res.status(200).json({ user: toFriendProfile(snap) });
  }

  const update: Record<string, unknown> = {};
  const photo = str(req.body?.photoBase64);
  if (photo) {
    if (photo.length > 140_000) return badRequest(res, 'photo too large');
    update.photoBase64 = photo;
  }
  const publicKey = str(req.body?.publicKey);
  if (publicKey) update.publicKey = publicKey;
  const addToken = str(req.body?.addFcmToken);
  if (addToken) update.fcmTokens = FieldValue.arrayUnion(addToken);
  const removeToken = str(req.body?.removeFcmToken);
  if (removeToken) update.fcmTokens = FieldValue.arrayRemove(removeToken);

  if (Object.keys(update).length === 0) return badRequest(res, 'nothing to update');
  await ref.update(update);
  return res.status(200).json({ ok: true });
}
