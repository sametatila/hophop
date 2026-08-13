import type { VercelRequest, VercelResponse } from '@vercel/node';
import { db } from '../firebase.js';
import { requireAuth } from '../auth.js';
import { requireMethod } from '../http.js';

const RING_WINDOW_MS = 45_000;

/** GET /api/call/pending — beni şu anda arayan var mı?
 * FCM'den bağımsız yedek zil yolu: cihaz yoklar, taze bir çağrı varsa döner. */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!requireMethod(req, res, 'GET')) return;
  const userId = await requireAuth(req, res);
  if (!userId) return;

  const ref = db().collection('rings').doc(userId);
  const snap = await ref.get();
  if (!snap.exists) return res.status(200).json({ ring: null });

  const atMs = (snap.get('atMs') as number) ?? 0;
  if (Date.now() - atMs > RING_WINDOW_MS) {
    ref.delete().catch(() => {});
    return res.status(200).json({ ring: null });
  }

  const data = snap.data()!;
  delete data.atMs;
  return res.status(200).json({ ring: data });
}
