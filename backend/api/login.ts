import type { VercelRequest, VercelResponse } from '@vercel/node';
import { db } from '../lib/firebase.js';
import { credentialHash, isValidBirthDate } from '../lib/crypto.js';
import { signSession } from '../lib/auth.js';
import { toFriendProfile } from '../lib/users.js';
import { requireMethod, badRequest, str } from '../lib/http.js';
import { FieldValue } from 'firebase-admin/firestore';

// Basic per-instance rate limiting: family app, not a bank. Serverless instances
// are ephemeral, so this is best-effort throttling of brute-force attempts.
const attempts = new Map<string, { count: number; resetAt: number }>();

function throttled(ip: string): boolean {
  const now = Date.now();
  const entry = attempts.get(ip);
  if (!entry || now > entry.resetAt) {
    attempts.set(ip, { count: 1, resetAt: now + 15 * 60_000 });
    return false;
  }
  entry.count += 1;
  return entry.count > 20;
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!requireMethod(req, res, 'POST')) return;

  const ip = (req.headers['x-forwarded-for'] as string | undefined)?.split(',')[0] ?? 'unknown';
  if (throttled(ip)) return res.status(429).json({ error: 'too_many_attempts' });

  const firstName = str(req.body?.firstName);
  const lastName = str(req.body?.lastName);
  const birthDate = str(req.body?.birthDate);
  if (!firstName || !lastName || !birthDate || !isValidBirthDate(birthDate)) {
    return badRequest(res, 'firstName, lastName, birthDate (YYYY-MM-DD) required');
  }

  const hash = credentialHash(firstName, lastName, birthDate);
  const match = await db().collection('users').where('credentialHash', '==', hash).limit(1).get();
  if (match.empty) return res.status(401).json({ error: 'not_found' });

  const doc = match.docs[0];
  await doc.ref.update({ lastLoginAt: FieldValue.serverTimestamp() });
  const token = await signSession(doc.id);
  return res.status(200).json({ token, user: toFriendProfile(doc) });
}
