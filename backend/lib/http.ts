import type { VercelRequest, VercelResponse } from '@vercel/node';

/** Returns false after writing a 405 if the method doesn't match. */
export function requireMethod(req: VercelRequest, res: VercelResponse, ...methods: string[]): boolean {
  if (methods.includes(req.method ?? '')) return true;
  res.status(405).json({ error: 'method_not_allowed' });
  return false;
}

export function badRequest(res: VercelResponse, message: string): void {
  res.status(400).json({ error: 'bad_request', message });
}

export function str(v: unknown): string | null {
  return typeof v === 'string' && v.length > 0 ? v : null;
}
