import type { VercelRequest, VercelResponse } from '@vercel/node';
import { db } from '../../lib/firebase.js';
import { requireAuth } from '../../lib/auth.js';
import { toPublicProfile } from '../../lib/users.js';
import { requireMethod } from '../../lib/http.js';

/** GET /api/friends/requests → { incoming: [...], outgoing: [...] } (pending only) */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!requireMethod(req, res, 'GET')) return;
  const userId = await requireAuth(req, res);
  if (!userId) return;

  const [incomingSnap, outgoingSnap] = await Promise.all([
    db().collection('friendRequests')
      .where('toUserId', '==', userId).where('status', '==', 'pending').get(),
    db().collection('friendRequests')
      .where('fromUserId', '==', userId).where('status', '==', 'pending').get(),
  ]);

  async function withProfile(docs: FirebaseFirestore.QueryDocumentSnapshot[], key: string) {
    return Promise.all(
      docs.map(async (d) => {
        const other = await db().collection('users').doc(d.get(key)).get();
        return {
          requestId: d.id,
          user: other.exists ? toPublicProfile(other) : null,
        };
      }),
    );
  }

  const [incoming, outgoing] = await Promise.all([
    withProfile(incomingSnap.docs, 'fromUserId'),
    withProfile(outgoingSnap.docs, 'toUserId'),
  ]);

  return res.status(200).json({ incoming, outgoing });
}
