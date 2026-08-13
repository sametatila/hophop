import type { VercelRequest, VercelResponse } from '@vercel/node';
import { requireAuth } from '../auth.js';
import { firebaseCustomToken } from '../firebase.js';
import { requireMethod } from '../http.js';

/** GET /api/firebase-token — gerçek-zamanlı zil dinleyicisi için kısa ömürlü
 * Firebase özel token'ı. Cihaz bununla oturum açıp yalnızca KENDİ rings
 * belgesini dinler (kurallar başka her şeyi kapalı tutar). */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!requireMethod(req, res, 'GET')) return;
  const userId = await requireAuth(req, res);
  if (!userId) return;
  const token = await firebaseCustomToken(userId);
  return res.status(200).json({ token });
}
