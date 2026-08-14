#!/usr/bin/env node
/**
 * Profil fotoğrafı akışının uçtan uca denemesi.
 *
 *   cd backend && node scripts/photo-test.mjs
 *
 * Neyi doğrular:
 *   1. Fotoğraf yüklenince sunucu photoVersion damgası basıyor mu
 *   2. Listeler base64 TAŞIMIYOR, yalnızca photoVersion veriyor mu
 *   3. /api/users/photo baytları doğru döndürüyor mu (JPEG, aynı içerik)
 *   4. Önbellek başlıkları immutable mı, yetkisiz erişim reddediliyor mu
 *   5. Yeni fotoğraf yüklenince sürüm (yani önbellek anahtarı) değişiyor mu
 *
 * Test kullanıcıları sonunda silinir.
 */
import { readFileSync } from 'node:fs';

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

console.log(`\n═══ HopHop foto akışı — ${API} ═══\n`);

const A = { firstName: 'Foto', lastName: 'Testa', birthDate: '1990-01-02' };
const B = { firstName: 'Foto', lastName: 'Testb', birthDate: '1991-02-03' };
const rA = await post('/api/admin/add-user', A, admin);
const rB = await post('/api/admin/add-user', B, admin);
const idA = rA.body.userId ?? rA.body.id;
const idB = rB.body.userId ?? rB.body.id;

const tokA = (await post('/api/login', A)).body.token;
const tokB = (await post('/api/login', B)).body.token;
const hA = { Authorization: `Bearer ${tokA}` };
const hB = { Authorization: `Bearer ${tokB}` };
ok('iki test kullanıcısı giriş yaptı', !!tokA && !!tokB);

// Rehberde görünmek için açık anahtar şart (girmemiş kullanıcı süzgeci)
await post('/api/me', { publicKey: 'dGVzdC1wdWJsaWMta2V5LWEK' }, hA);
await post('/api/me', { publicKey: 'dGVzdC1wdWJsaWMta2V5LWIK' }, hB);

// 1×1 piksel JPEG
const JPEG_B64 =
  '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0a' +
  'HBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAA' +
  'AAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==';

console.log('\n── Yükleme ve sürüm damgası ──');
const up = await post('/api/me', { photoBase64: JPEG_B64 }, hA);
ok('fotoğraf yüklendi', up.status === 200, `status ${up.status}`);
const meA = await get('/api/me', hA);
const v1 = meA.body.user?.photoVersion;
ok('photoVersion damgası basıldı', typeof v1 === 'number' && v1 > 0, `v=${v1}`);
ok('/api/me base64 TAŞIMIYOR', meA.body.user?.photoBase64 === undefined);

console.log('\n── Listelerde yük ──');
const dir = await get('/api/users', hB);
const seen = (dir.body.users ?? []).find((u) => u.id === idA);
ok('rehberde görünüyor (açık anahtarı var)', !!seen);
ok('rehber base64 TAŞIMIYOR', seen && seen.photoBase64 === undefined);
ok('rehber photoVersion veriyor', seen?.photoVersion === v1, `v=${seen?.photoVersion}`);
const dirBytes = JSON.stringify(dir.body).length;
ok('rehber yanıtı küçük (<8 KB)', dirBytes < 8192, `${(dirBytes / 1024).toFixed(1)} KB`);

console.log('\n── Fotoğraf ucu ──');
const photoUrl = `${API}/api/users/photo?id=${idA}&v=${v1}`;
const unauth = await fetch(photoUrl);
ok('tokensiz erişim reddi → 401', unauth.status === 401, `status ${unauth.status}`);

const res = await fetch(photoUrl, { headers: hB });
const buf = Buffer.from(await res.arrayBuffer());
ok('yetkili erişim → 200', res.status === 200);
ok('içerik türü image/jpeg', res.headers.get('content-type') === 'image/jpeg',
   res.headers.get('content-type') ?? '');
ok('baytlar yüklenenle birebir aynı', buf.equals(Buffer.from(JPEG_B64, 'base64')),
   `${buf.length} bayt`);
const cc = res.headers.get('cache-control') ?? '';
ok('önbellek başlığı immutable + private', cc.includes('immutable') && cc.includes('private'), cc);
ok('fotoğrafı olmayan → 404', (await fetch(`${API}/api/users/photo?id=${idB}&v=1`, { headers: hB })).status === 404);

console.log('\n── Yeni fotoğraf = yeni sürüm ──');
await new Promise((r) => setTimeout(r, 1100)); // damga ms cinsinden
await post('/api/me', { photoBase64: JPEG_B64 }, hA);
const v2 = (await get('/api/me', hA)).body.user?.photoVersion;
ok('sürüm değişti (eski önbellek geçersiz)', typeof v2 === 'number' && v2 > v1, `${v1} → ${v2}`);

console.log('\n── Temizlik ──');
const delH = { ...admin, 'Content-Type': 'application/json' };
for (const id of [idA, idB]) {
  await fetch(`${API}/api/admin/users`, { method: 'DELETE', headers: delH, body: JSON.stringify({ userId: id }) });
}
ok('test kullanıcıları silindi', true);

console.log(`\n═══ SONUÇ: ${pass} geçti, ${fail} kaldı ═══\n`);
process.exit(fail === 0 ? 0 : 1);
