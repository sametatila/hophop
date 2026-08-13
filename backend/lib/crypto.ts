import { createHash, createCipheriv, createDecipheriv, randomBytes } from 'crypto';

const TR_MAP: Record<string, string> = {
  ç: 'c', ğ: 'g', ı: 'i', i̇: 'i', ö: 'o', ş: 's', ü: 'u',
};

/** Lowercase, fold Turkish characters, collapse whitespace.
 * "Ayşe  ÖZTÜRK" and "ayse ozturk" normalize identically. */
export function normalizeName(s: string): string {
  return s
    .toLocaleLowerCase('tr-TR')
    .split('')
    .map((ch) => TR_MAP[ch] ?? ch)
    .join('')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9 ]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

/** birthDate must be YYYY-MM-DD */
export function credentialHash(firstName: string, lastName: string, birthDate: string): string {
  const pepper = process.env.PEPPER;
  if (!pepper) throw new Error('PEPPER env var missing');
  const material = `${pepper}|${normalizeName(firstName)}|${normalizeName(lastName)}|${birthDate}`;
  return createHash('sha256').update(material, 'utf8').digest('hex');
}

function profileKey(): Buffer {
  const hex = process.env.PROFILE_KEY;
  if (!hex || hex.length !== 64) throw new Error('PROFILE_KEY must be 32 bytes hex (64 chars)');
  return Buffer.from(hex, 'hex');
}

/** AES-256-GCM. Output: base64(iv[12] | tag[16] | ciphertext) */
export function encryptField(plaintext: string): string {
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', profileKey(), iv);
  const enc = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  return Buffer.concat([iv, cipher.getAuthTag(), enc]).toString('base64');
}

export function decryptField(payload: string): string {
  const buf = Buffer.from(payload, 'base64');
  const iv = buf.subarray(0, 12);
  const tag = buf.subarray(12, 28);
  const data = buf.subarray(28);
  const decipher = createDecipheriv('aes-256-gcm', profileKey(), iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(data), decipher.final()]).toString('utf8');
}

export function isValidBirthDate(s: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) return false;
  const d = new Date(s + 'T00:00:00Z');
  return !isNaN(d.getTime()) && s === d.toISOString().slice(0, 10);
}
