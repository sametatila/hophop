import { initializeApp, cert, getApps, App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Firestore } from 'firebase-admin/firestore';
import { getMessaging, Messaging } from 'firebase-admin/messaging';

function loadServiceAccount(): Record<string, unknown> {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!raw) throw new Error('FIREBASE_SERVICE_ACCOUNT env var missing');
  // Accepts raw JSON or base64-encoded JSON.
  const json = raw.trim().startsWith('{')
    ? raw
    : Buffer.from(raw, 'base64').toString('utf8');
  return JSON.parse(json);
}

function app(): App {
  const apps = getApps();
  if (apps.length > 0) return apps[0];
  return initializeApp({ credential: cert(loadServiceAccount() as any) });
}

export function db(): Firestore {
  return getFirestore(app());
}

export function messaging(): Messaging {
  return getMessaging(app());
}

/** İstemcinin rings/{uid} belgesini GERÇEK ZAMANLI dinleyebilmesi için
 * kullanıcıya özel Firebase özel token'ı (uid = bizim kullanıcı kimliğimiz). */
export function firebaseCustomToken(userId: string): Promise<string> {
  return getAuth(app()).createCustomToken(userId);
}
