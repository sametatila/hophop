import { db } from './firebase.js';
import { decryptField } from './crypto.js';
import type { DocumentSnapshot } from 'firebase-admin/firestore';

export interface PublicProfile {
  id: string;
  firstName: string;
  lastName: string;
  photoBase64: string | null;
}

export interface FriendProfile extends PublicProfile {
  birthDate: string;
  publicKey: string | null;
}

/** Directory view: no birth date, no public key. */
export function toPublicProfile(doc: DocumentSnapshot): PublicProfile {
  return {
    id: doc.id,
    firstName: decryptField(doc.get('encFirstName')),
    lastName: decryptField(doc.get('encLastName')),
    photoBase64: doc.get('photoBase64') ?? null,
  };
}

/** Friend view: includes birth date (for birthdays) and E2EE public key. */
export function toFriendProfile(doc: DocumentSnapshot): FriendProfile {
  return {
    ...toPublicProfile(doc),
    birthDate: decryptField(doc.get('encBirthDate')),
    publicKey: doc.get('publicKey') ?? null,
  };
}

export function pairId(a: string, b: string): string {
  return [a, b].sort().join('_');
}

export async function areFriends(a: string, b: string): Promise<boolean> {
  const snap = await db().collection('friendships').doc(pairId(a, b)).get();
  return snap.exists;
}
