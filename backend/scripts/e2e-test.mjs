#!/usr/bin/env node
// HopHop üretim E2E test paketi.
// Kullanım: backend/ dizininde: node scripts/e2e-test.mjs [API_URL]
// .env'den ADMIN_SECRET + LiveKit + Firebase kimlikleri okunur; hiçbir gizli değer yazdırılmaz.

import { readFileSync } from 'fs';

const API = process.argv[2] ?? 'https://hophop.exfe.me';
const env = Object.fromEntries(
  readFileSync(new URL('../.env', import.meta.url), 'utf8').split('\n')
    .filter((l) => l.includes('=') && !l.trim().startsWith('#'))
    .map((l) => { const [k, ...r] = l.split('='); return [k.trim(), r.join('=').trim().replace(/^["']|["']$/g, '')]; }),
);

let pass = 0, fail = 0;
const ok = (name, cond, extra = '') => {
  cond ? pass++ : fail++;
  console.log(`${cond ? '✅' : '❌'} ${name}${extra ? ' — ' + extra : ''}`);
};
const j = async (r) => ({ status: r.status, body: await r.json().catch(() => ({})) });
const post = (path, body, headers = {}) =>
  fetch(`${API}${path}`, { method: 'POST', headers: { 'Content-Type': 'application/json', ...headers }, body: JSON.stringify(body) }).then(j);
const get = (path, headers = {}) => fetch(`${API}${path}`, { headers }).then(j);
const admin = { 'X-Admin-Secret': env.ADMIN_SECRET };

console.log(`\n═══ HopHop E2E — ${API} ═══\n`);

// ── 1. Yetkisiz erişim reddi ──
console.log('── Güvenlik: yetkisiz erişim ──');
ok('adminsiz /api/admin/users → 401', (await get('/api/admin/users')).status === 401);
ok('yanlış admin secret → 401', (await get('/api/admin/users', { 'X-Admin-Secret': 'yanlis' })).status === 401);
ok('tokensiz /api/friends → 401', (await get('/api/friends')).status === 401);
ok('bozuk JWT → 401', (await get('/api/friends', { Authorization: 'Bearer sahte.jwt.token' })).status === 401);

// ── 2. Admin kullanıcı yönetimi ──
console.log('\n── Admin: kullanıcı yönetimi ──');
const A = { firstName: 'E2e', lastName: 'Baba', birthDate: '1988-04-12' };
const B = { firstName: 'E2e', lastName: 'Çocuk', birthDate: '2016-05-21' };
const rA = await post('/api/admin/add-user', A, admin);
const rB = await post('/api/admin/add-user', B, admin);
ok('kullanıcı A eklendi', [200, 409].includes(rA.status), `status ${rA.status}`);
ok('kullanıcı B eklendi (Türkçe Ç ile)', [200, 409].includes(rB.status), `status ${rB.status}`);
ok('kopya kayıt reddi → 409', (await post('/api/admin/add-user', A, admin)).status === 409);
ok('geçersiz tarih reddi → 400', (await post('/api/admin/add-user', { firstName: 'X', lastName: 'Y', birthDate: '21.05.2016' }, admin)).status === 400);

// ── 3. Giriş ──
console.log('\n── Giriş ──');
const lA = await post('/api/login', A);
const lB = await post('/api/login', { firstName: 'e2e', lastName: 'COCUK', birthDate: '2016-05-21' });
ok('A girişi', lA.status === 200);
ok('B girişi (küçük harf + Ç→C normalizasyonu)', lB.status === 200);
ok('yanlış doğum tarihi → 401', (await post('/api/login', { ...A, birthDate: '1988-04-13' })).status === 401);
if (lA.status !== 200 || lB.status !== 200) { console.log('Giriş başarısız — devam edilemiyor'); process.exit(1); }
const HA = { Authorization: `Bearer ${lA.body.token}`, 'Content-Type': 'application/json' };
const HB = { Authorization: `Bearer ${lB.body.token}`, 'Content-Type': 'application/json' };
const [idA, idB] = [lA.body.user.id, lB.body.user.id];
ok('giriş yanıtında doğum tarihi (kendi profili)', lA.body.user.birthDate === A.birthDate);

// ── 4. Profil ──
console.log('\n── Profil ──');
ok('public key kaydı', (await post('/api/me', { publicKey: 'ZTJlLXRlc3Qta2V5LUE=' }, HA)).status === 200);
await post('/api/me', { publicKey: 'ZTJlLXRlc3Qta2V5LUI=' }, HB);
ok('fcm token kaydı', (await post('/api/me', { addFcmToken: 'e2e-sahte-token' }, HA)).status === 200);
const photo = 'x'.repeat(1000);
ok('fotoğraf kaydı', (await post('/api/me', { photoBase64: photo }, HA)).status === 200);
ok('aşırı büyük fotoğraf reddi → 400', (await post('/api/me', { photoBase64: 'x'.repeat(200000) }, HA)).status === 400);
const me = await get('/api/me', HA);
ok('profil okuma (fotoğraf geldi)', me.body.user?.photoBase64 === photo);

// ── 5. Dizin ve gizlilik ──
console.log('\n── Dizin ve gizlilik ──');
const dir = await get('/api/users', HA);
const dirB = dir.body.users?.find((u) => u.id === idB);
ok('dizinde B görünür', !!dirB);
ok('dizinde doğum tarihi SIZMIYOR', dirB && dirB.birthDate === undefined);
ok('dizinde public key SIZMIYOR', dirB && dirB.publicKey === undefined);

// ── 6. Arkadaşlık ──
console.log('\n── Arkadaşlık ──');
ok('arkadaş değilken arama → 403', (await post('/api/call/initiate', { calleeId: idB, video: true }, HA)).status === 403);
ok('kendine istek reddi → 400', (await post('/api/friends/request', { toUserId: idA }, HA)).status === 400);
const req = await post('/api/friends/request', { toUserId: idB }, HA);
ok('istek gönderildi', req.status === 200);
ok('çift istek reddi → 400', (await post('/api/friends/request', { toUserId: idB }, HA)).status === 400);
const reqsB = await get('/api/friends/requests', HB);
const incoming = reqsB.body.incoming?.find((r) => r.user?.id === idA);
ok('B gelen isteği görüyor', !!incoming);
ok('istek kabulü', (await post('/api/friends/respond', { requestId: incoming?.requestId, accept: true }, HB)).status === 200);
const friendsA = await get('/api/friends', HA);
const fB = friendsA.body.friends?.find((f) => f.id === idB);
ok('A, B\'yi arkadaş listesinde görüyor', !!fB);
ok('arkadaşın doğum tarihi görünür (doğum günü özelliği)', fB?.birthDate === B.birthDate);
ok('arkadaşın public key\'i görünür (E2EE)', !!fB?.publicKey);

// ── 7. Arama + LiveKit ──
console.log('\n── Arama ve LiveKit ──');
const call = await post('/api/call/initiate', { calleeId: idB, video: true }, HA);
ok('arama başlatıldı', call.status === 200);
ok('LiveKit JWT (arayan)', call.body.livekitToken?.split('.').length === 3);
ok('LiveKit URL wss', call.body.livekitUrl?.startsWith('wss://'));
ok('karşı tarafın public key\'i geldi', !!call.body.calleePublicKey);
const resp = await post('/api/call/respond', { roomName: call.body.roomName, callerId: idA, accept: true }, HB);
ok('arama cevaplandı + LiveKit JWT (aranan)', resp.status === 200 && resp.body.livekitToken?.split('.').length === 3);
ok('arama iptali', (await post('/api/call/cancel', { roomName: call.body.roomName, calleeId: idB }, HA)).status === 200);

// ── 8. LiveKit Cloud kimlik doğrulaması (API key/secret gerçekten geçerli mi) ──
console.log('\n── LiveKit Cloud anahtar doğrulaması ──');
try {
  const { RoomServiceClient } = await import('livekit-server-sdk');
  const httpUrl = env.LIVEKIT_URL.replace('wss://', 'https://');
  const svc = new RoomServiceClient(httpUrl, env.LIVEKIT_API_KEY, env.LIVEKIT_API_SECRET);
  const rooms = await svc.listRooms();
  ok('LiveKit Cloud kimliği geçerli (listRooms)', Array.isArray(rooms), `aktif oda: ${rooms.length}`);
} catch (e) {
  ok('LiveKit Cloud kimliği geçerli (listRooms)', false, String(e).slice(0, 120));
}

// ── 9. FCM kimlik doğrulaması (service account gerçekten push atabiliyor mu) ──
console.log('\n── FCM kimlik doğrulaması ──');
try {
  const adminSdk = await import('firebase-admin/app');
  const { getMessaging } = await import('firebase-admin/messaging');
  const sa = JSON.parse(Buffer.from(env.FIREBASE_SERVICE_ACCOUNT, 'base64').toString());
  const app = adminSdk.getApps()[0] ?? adminSdk.initializeApp({ credential: adminSdk.cert(sa) });
  try {
    await getMessaging(app).send({ token: 'gecersiz-test-tokeni', data: { t: 'x' } });
    ok('FCM kimliği', false, 'geçersiz token kabul edildi?!');
  } catch (e) {
    const code = e?.errorInfo?.code ?? e?.code ?? '';
    // Kimlik GEÇERLİ ise Google "token geçersiz" der; kimlik bozuksa auth hatası gelir.
    const authOk = code.includes('invalid-argument') || code.includes('registration-token');
    ok('FCM kimliği geçerli (Google yalnızca token\'ı reddetti)', authOk, code);
  }
} catch (e) {
  ok('FCM kimliği geçerli', false, String(e).slice(0, 120));
}

// ── 10. Temizlik ──
console.log('\n── Temizlik ──');
const delH = { 'Content-Type': 'application/json', ...admin };
const dA = await fetch(`${API}/api/admin/users`, { method: 'DELETE', headers: delH, body: JSON.stringify({ userId: idA }) }).then(j);
const dB = await fetch(`${API}/api/admin/users`, { method: 'DELETE', headers: delH, body: JSON.stringify({ userId: idB }) }).then(j);
ok('test kullanıcıları silindi', dA.status === 200 && dB.status === 200);
const gone = await post('/api/login', A);
ok('silinen kullanıcı giremiyor → 401', gone.status === 401);

console.log(`\n═══ SONUÇ: ${pass} geçti, ${fail} kaldı ═══`);
process.exit(fail === 0 ? 0 : 1);
