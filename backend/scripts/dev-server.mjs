#!/usr/bin/env node
// HopHop GELİŞTİRME sunucusu — emülatör testi için bellek içi sahte API.
// Gerçek API sözleşmesinin birebir kopyası; Firebase/LiveKit/Vercel GEREKTİRMEZ.
// Üretimde KULLANILMAZ. Kullanım: node scripts/dev-server.mjs  (port: 8787)
//
// Emülatörden erişim: http://10.0.2.2:8787  (debug APK --dart-define ile ayarlı)
// LiveKit env verilirse (LIVEKIT_URL/KEY/SECRET) gerçek oda token'ı da üretir.

import { createHash, randomBytes, randomUUID } from 'crypto';
import http from 'http';

const PORT = process.env.PORT ?? 8787;
const PEPPER = 'dev-pepper';

const TR = { ç: 'c', ğ: 'g', ı: 'i', ö: 'o', ş: 's', ü: 'u' };
const norm = (s) =>
  s.toLocaleLowerCase('tr-TR').split('').map((c) => TR[c] ?? c).join('')
    .normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9 ]/g, '')
    .replace(/\s+/g, ' ').trim();
const hash = (f, l, b) =>
  createHash('sha256').update(`${PEPPER}|${norm(f)}|${norm(l)}|${b}`).digest('hex');

// Yakında doğum günü olan bir kuzen — doğum günü şeridi test edilebilsin
const soon = new Date(Date.now() + 3 * 864e5);
const soonMd = `${String(soon.getMonth() + 1).padStart(2, '0')}-${String(soon.getDate()).padStart(2, '0')}`;

const mkUser = (first, last, birth) => ({
  id: randomUUID().slice(0, 8),
  firstName: first,
  lastName: last,
  birthDate: birth,
  credentialHash: hash(first, last, birth),
  photoBase64: null,
  publicKey: null,
  fcmTokens: [],
});

const users = [
  mkUser('Mehmet', 'Yılmaz', '1988-04-12'),
  mkUser('Ali', 'Yılmaz', '2016-05-21'),
  mkUser('Zeynep', 'Kaya', `2015-${soonMd}`),
  mkUser('Elif', 'Kaya', '1990-09-02'),
];
const sessions = new Map(); // token → userId
const requests = []; // {id, fromUserId, toUserId, status}
const friendships = new Set(); // "a_b" (sorted)

const pairId = (a, b) => [a, b].sort().join('_');
const areFriends = (a, b) => friendships.has(pairId(a, b));
const pub = (u) => ({ id: u.id, firstName: u.firstName, lastName: u.lastName, photoBase64: u.photoBase64 });
const friend = (u) => ({ ...pub(u), birthDate: u.birthDate, publicKey: u.publicKey });

function authUser(req) {
  const t = (req.headers.authorization ?? '').replace('Bearer ', '');
  const id = sessions.get(t);
  return users.find((u) => u.id === id) ?? null;
}

async function livekitToken(room, identity, name) {
  if (!process.env.LIVEKIT_API_KEY) return 'dev-token-livekit-yok';
  const { AccessToken } = await import('livekit-server-sdk');
  const at = new AccessToken(process.env.LIVEKIT_API_KEY, process.env.LIVEKIT_API_SECRET, { identity, name, ttl: '2h' });
  at.addGrant({ roomJoin: true, room, canPublish: true, canSubscribe: true, canPublishData: true });
  return at.toJwt();
}

const routes = {
  'POST /api/login': async (body) => {
    const { firstName, lastName, birthDate } = body;
    const h = hash(firstName ?? '', lastName ?? '', birthDate ?? '');
    const u = users.find((x) => x.credentialHash === h);
    if (!u) return [401, { error: 'not_found' }];
    const token = randomBytes(24).toString('hex');
    sessions.set(token, u.id);
    return [200, { token, user: friend(u) }];
  },
  'GET /api/me': async (_b, me) => [200, { user: friend(me) }],
  'POST /api/me': async (body, me) => {
    if (body.photoBase64) me.photoBase64 = body.photoBase64;
    if (body.publicKey) me.publicKey = body.publicKey;
    if (body.addFcmToken && !me.fcmTokens.includes(body.addFcmToken)) me.fcmTokens.push(body.addFcmToken);
    return [200, { ok: true }];
  },
  'GET /api/users': async (_b, me) => [200, {
    users: users.filter((u) => u.id !== me.id).map((u) => ({
      ...pub(u),
      friendStatus: areFriends(me.id, u.id) ? 'friend'
        : requests.some((r) => r.status === 'pending' && r.fromUserId === me.id && r.toUserId === u.id) ? 'requested'
        : requests.some((r) => r.status === 'pending' && r.fromUserId === u.id && r.toUserId === me.id) ? 'incoming'
        : 'none',
    })),
  }],
  'GET /api/friends': async (_b, me) => [200, {
    friends: users.filter((u) => u.id !== me.id && areFriends(me.id, u.id)).map(friend),
  }],
  'POST /api/friends/request': async (body, me) => {
    if (body.cancelRequestId) {
      const i = requests.findIndex((r) => r.id === body.cancelRequestId && r.fromUserId === me.id);
      if (i < 0) return [404, { error: 'not_found' }];
      requests.splice(i, 1);
      return [200, { ok: true }];
    }
    const to = users.find((u) => u.id === body.toUserId);
    if (!to) return [404, { error: 'not_found' }];
    if (areFriends(me.id, to.id)) return [400, { error: 'bad_request', message: 'already friends' }];
    if (requests.some((r) => r.status === 'pending' &&
        [r.fromUserId, r.toUserId].sort().join() === [me.id, to.id].sort().join())) {
      return [400, { error: 'bad_request', message: 'request already pending' }];
    }
    const r = { id: randomUUID().slice(0, 8), fromUserId: me.id, toUserId: to.id, status: 'pending' };
    requests.push(r);
    return [200, { requestId: r.id }];
  },
  'POST /api/friends/respond': async (body, me) => {
    const r = requests.find((x) => x.id === body.requestId && x.toUserId === me.id && x.status === 'pending');
    if (!r) return [404, { error: 'not_found' }];
    r.status = body.accept === true ? 'accepted' : 'rejected';
    if (r.status === 'accepted') friendships.add(pairId(r.fromUserId, r.toUserId));
    return [200, { ok: true }];
  },
  'GET /api/friends/requests': async (_b, me) => [200, {
    incoming: requests.filter((r) => r.status === 'pending' && r.toUserId === me.id)
      .map((r) => ({ requestId: r.id, user: pub(users.find((u) => u.id === r.fromUserId)) })),
    outgoing: requests.filter((r) => r.status === 'pending' && r.fromUserId === me.id)
      .map((r) => ({ requestId: r.id, user: pub(users.find((u) => u.id === r.toUserId)) })),
  }],
  'POST /api/call/initiate': async (body, me) => {
    if (!areFriends(me.id, body.calleeId)) return [403, { error: 'not_friends' }];
    const callee = users.find((u) => u.id === body.calleeId);
    const roomName = `${pairId(me.id, body.calleeId)}_${randomBytes(6).toString('hex')}`;
    console.log(`📞 ${me.firstName} → ${callee.firstName} (video: ${body.video}) — dev sunucuda FCM push YOK`);
    return [200, {
      roomName,
      livekitToken: await livekitToken(roomName, me.id, me.firstName),
      livekitUrl: process.env.LIVEKIT_URL ?? 'wss://dev.invalid',
      calleePublicKey: callee.publicKey,
    }];
  },
  'POST /api/call/respond': async (body, me) => {
    const caller = users.find((u) => u.id === body.callerId);
    if (!caller || !areFriends(me.id, caller.id)) return [403, { error: 'not_friends' }];
    if (body.accept !== true) return [200, { ok: true }];
    return [200, {
      livekitToken: await livekitToken(body.roomName, me.id, me.firstName),
      livekitUrl: process.env.LIVEKIT_URL ?? 'wss://dev.invalid',
      callerPublicKey: caller.publicKey,
    }];
  },
  'POST /api/call/cancel': async () => [200, { ok: true }],
};

http.createServer(async (req, res) => {
  let body = {};
  try {
    const chunks = [];
    for await (const c of req) chunks.push(c);
    if (chunks.length) body = JSON.parse(Buffer.concat(chunks).toString());
  } catch {}
  const key = `${req.method} ${req.url}`;
  const route = routes[key];
  let status = 404, out = { error: 'not_found' };
  if (route) {
    const needsAuth = key !== 'POST /api/login';
    const me = needsAuth ? authUser(req) : null;
    if (needsAuth && !me) {
      status = 401; out = { error: 'unauthorized' };
    } else {
      [status, out] = await route(body, me);
    }
  }
  console.log(`${status} ${key}`);
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(out));
}).listen(PORT, '0.0.0.0', () => {
  console.log(`HopHop dev API → http://0.0.0.0:${PORT} (emülatörden: http://10.0.2.2:${PORT})`);
  console.log('Test kullanıcıları (ad soyad doğum-tarihi):');
  for (const u of users) console.log(`  ${u.firstName} ${u.lastName}  ${u.birthDate}`);
});
