import type { VercelRequest, VercelResponse } from '@vercel/node';
// Tüm uçlar TEK serverless fonksiyonda toplanır:
// - Vercel Hobby'nin 12 fonksiyon sınırına takılmaz (bizde 15 uç var)
// - Tek bundle = paylaşılan sıcak başlangıç → daha düşük gecikme
import login from '../lib/handlers/login.js';
import me from '../lib/handlers/me.js';
import users from '../lib/handlers/users.js';
import friendsList from '../lib/handlers/friends-list.js';
import friendsRequest from '../lib/handlers/friends-request.js';
import friendsRespond from '../lib/handlers/friends-respond.js';
import friendsRequests from '../lib/handlers/friends-requests.js';
import callInitiate from '../lib/handlers/call-initiate.js';
import callRespond from '../lib/handlers/call-respond.js';
import callCancel from '../lib/handlers/call-cancel.js';
import callInvite from '../lib/handlers/call-invite.js';
import callPending from '../lib/handlers/call-pending.js';
import firebaseToken from '../lib/handlers/firebase-token.js';
import adminAddUser from '../lib/handlers/admin-add-user.js';
import adminUsers from '../lib/handlers/admin-users.js';
import messagesSend from '../lib/handlers/messages-send.js';
import messagesList from '../lib/handlers/messages-list.js';
import messagesSummary from '../lib/handlers/messages-summary.js';
import messagesTyping from '../lib/handlers/messages-typing.js';

type Handler = (req: VercelRequest, res: VercelResponse) => unknown;

const routes: Record<string, Handler> = {
  'login': login,
  'me': me,
  'users': users,
  'friends': friendsList,
  'friends/request': friendsRequest,
  'friends/respond': friendsRespond,
  'friends/requests': friendsRequests,
  'call/initiate': callInitiate,
  'call/respond': callRespond,
  'call/cancel': callCancel,
  'call/invite': callInvite,
  'call/pending': callPending,
  'firebase-token': firebaseToken,
  'admin/add-user': adminAddUser,
  'admin/users': adminUsers,
  'messages/send': messagesSend,
  'messages/list': messagesList,
  'messages/summary': messagesSummary,
  'messages/typing': messagesTyping,
};

export default async function handler(req: VercelRequest, res: VercelResponse) {
  // Yol önce rewrite'ın taşıdığı ?p= parametresinden, o yoksa URL'den okunur.
  const p = req.query.p;
  const fromQuery = Array.isArray(p) ? p.join('/') : p;
  const path = (fromQuery ??
    (req.url ?? '').split('?')[0].replace(/^\/api\/?/, ''))
    .replace(/\/+$/, '');
  const route = routes[path];
  if (!route) return res.status(404).json({ error: 'not_found' });
  try {
    return await route(req, res);
  } catch (e) {
    console.error(`unhandled error in /${path}:`, e);
    if (!res.headersSent) res.status(500).json({ error: 'internal' });
  }
}
