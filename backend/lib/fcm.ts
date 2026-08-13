import { db, messaging } from './firebase.js';
import { FieldValue } from 'firebase-admin/firestore';

/** Sends a high-priority data-only message to every device of a user.
 * Invalid/expired tokens are pruned from the user document. */
export async function pushToUser(userId: string, data: Record<string, string>): Promise<void> {
  const snap = await db().collection('users').doc(userId).get();
  const tokens: string[] = snap.get('fcmTokens') ?? [];
  if (tokens.length === 0) return;

  const results = await Promise.allSettled(
    tokens.map((token) =>
      messaging().send({
        token,
        data,
        android: { priority: 'high', ttl: 45_000 },
      }),
    ),
  );

  const dead = tokens.filter((_, i) => {
    const r = results[i];
    if (r.status === 'fulfilled') return false;
    const code = (r.reason?.errorInfo?.code ?? r.reason?.code ?? '') as string;
    return (
      code.includes('registration-token-not-registered') ||
      code.includes('invalid-argument') ||
      code.includes('invalid-registration-token')
    );
  });
  if (dead.length > 0) {
    await snap.ref.update({ fcmTokens: FieldValue.arrayRemove(...dead) });
  }
}
