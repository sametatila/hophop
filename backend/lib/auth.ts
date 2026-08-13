import { SignJWT, jwtVerify } from 'jose';
import type { VercelRequest, VercelResponse } from '@vercel/node';

function secret(): Uint8Array {
  const s = process.env.JWT_SECRET;
  if (!s) throw new Error('JWT_SECRET env var missing');
  return new TextEncoder().encode(s);
}

export async function signSession(userId: string): Promise<string> {
  return new SignJWT({})
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(userId)
    .setIssuedAt()
    .setExpirationTime('365d')
    .sign(secret());
}

/** Returns userId, or null after writing a 401 response. */
export async function requireAuth(req: VercelRequest, res: VercelResponse): Promise<string | null> {
  const header = req.headers.authorization ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    res.status(401).json({ error: 'unauthorized' });
    return null;
  }
  try {
    const { payload } = await jwtVerify(token, secret());
    if (!payload.sub) throw new Error('no sub');
    return payload.sub;
  } catch {
    res.status(401).json({ error: 'unauthorized' });
    return null;
  }
}

/** Admin auth via X-Admin-Secret header. */
export function requireAdmin(req: VercelRequest, res: VercelResponse): boolean {
  const expected = process.env.ADMIN_SECRET;
  const got = req.headers['x-admin-secret'];
  if (!expected || got !== expected) {
    res.status(401).json({ error: 'unauthorized' });
    return false;
  }
  return true;
}
