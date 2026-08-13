import type { VercelRequest, VercelResponse } from '@vercel/node';
import { db } from '../../lib/firebase.js';
import { requireAdmin } from '../../lib/auth.js';
import { credentialHash, encryptField, isValidBirthDate } from '../../lib/crypto.js';
import { requireMethod, badRequest, str } from '../../lib/http.js';
import { FieldValue } from 'firebase-admin/firestore';

/** POST /api/admin/add-user { firstName, lastName, birthDate } (X-Admin-Secret header)
 * Identity is stored hashed (login) + AES-256-GCM encrypted (display). Never plaintext. */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!requireMethod(req, res, 'POST')) return;
  if (!requireAdmin(req, res)) return;

  const firstName = str(req.body?.firstName);
  const lastName = str(req.body?.lastName);
  const birthDate = str(req.body?.birthDate);
  if (!firstName || !lastName || !birthDate || !isValidBirthDate(birthDate)) {
    return badRequest(res, 'firstName, lastName, birthDate (YYYY-MM-DD) required');
  }

  const hash = credentialHash(firstName, lastName, birthDate);
  const dup = await db().collection('users').where('credentialHash', '==', hash).limit(1).get();
  if (!dup.empty) return res.status(409).json({ error: 'already_exists', userId: dup.docs[0].id });

  const ref = await db().collection('users').add({
    credentialHash: hash,
    encFirstName: encryptField(firstName),
    encLastName: encryptField(lastName),
    encBirthDate: encryptField(birthDate),
    photoBase64: null,
    publicKey: null,
    fcmTokens: [],
    createdAt: FieldValue.serverTimestamp(),
  });

  return res.status(200).json({ userId: ref.id });
}
