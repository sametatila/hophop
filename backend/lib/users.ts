import { db } from './firebase.js';
import { decryptField } from './crypto.js';
import type { DocumentSnapshot } from 'firebase-admin/firestore';

export interface PublicProfile {
  id: string;
  firstName: string;
  lastName: string;
  photoVersion: number | null;
}

export interface FriendProfile extends PublicProfile {
  birthDate: string;
  publicKey: string | null;
}

/** Ad ve açık anahtar için gereken alanlar — profil fotoğrafı HARİÇ.
 * Arama kurulumu gibi gecikmeye duyarlı yollarda belge maskesi olarak
 * kullanılır: fotoğraf ~40 KB ve o yollarda hiç gerekmiyor. */
export const IDENTITY_FIELDS = [
  'encFirstName',
  'encLastName',
  'encBirthDate',
  'publicKey',
] as const;

/** Fotoğrafın sürümü: /api/users/photo adresinin önbellek anahtarı.
 * Eski kayıtlarda alan yok ama fotoğraf olabilir — o hâlde 1 döner. */
function photoVersionOf(doc: DocumentSnapshot): number | null {
  const v = doc.get('photoVersion');
  if (typeof v === 'number') return v;
  return doc.get('photoBase64') ? 1 : null;
}

/** Directory view: no birth date, no public key.
 * Fotoğrafın kendisi DEĞİL, sürümü döner: bayt akışı ayrı uçtan, sonsuza
 * kadar önbelleklenebilir biçimde servis edilir (listeler her tazelemede
 * herkesin fotoğrafını yeniden indirmesin). */
export function toPublicProfile(doc: DocumentSnapshot): PublicProfile {
  return {
    id: doc.id,
    firstName: decryptField(doc.get('encFirstName')),
    lastName: decryptField(doc.get('encLastName')),
    photoVersion: photoVersionOf(doc),
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
