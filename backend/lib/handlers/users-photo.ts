import type { VercelRequest, VercelResponse } from '@vercel/node';
import { db } from '../firebase.js';
import { requireAuth } from '../auth.js';
import { requireMethod, badRequest, str } from '../http.js';

/** GET /api/users/photo?id=<userId>&v=<photoVersion>
 *
 * Profil fotoğrafının bayt hâli. Listeler artık base64 taşımıyor; yalnızca
 * `photoVersion` gönderiyor ve istemci fotoğrafı buradan bir kez indirip
 * kalıcı olarak saklıyor.
 *
 * `v` sunucu için anlamsızdır, yalnızca ÖNBELLEK ANAHTARIDIR: fotoğraf
 * değişince sürüm değişir, adres değişir, eski kopya kendiliğinden geçersiz
 * olur. Bu yüzden yanıt "immutable" işaretlenebiliyor.
 *
 * Yanıt `private` işaretli: aile dışına açık bir adres değil, JWT ister. */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!requireMethod(req, res, 'GET')) return;
  const userId = await requireAuth(req, res);
  if (!userId) return;

  const id = str(req.query?.id);
  if (!id) return badRequest(res, 'id required');

  const snap = await db().collection('users').doc(id).get();
  const photo = snap.get('photoBase64') as string | undefined;
  if (!snap.exists || !photo) return res.status(404).json({ error: 'not_found' });

  const bytes = Buffer.from(photo, 'base64');
  res.setHeader('Content-Type', 'image/jpeg');
  res.setHeader('Content-Length', String(bytes.length));
  res.setHeader('Cache-Control', 'private, max-age=31536000, immutable');
  return res.status(200).send(bytes);
}
