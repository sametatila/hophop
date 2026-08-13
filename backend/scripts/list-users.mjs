#!/usr/bin/env node
// HopHop yönetici betiği — kayıtlı kullanıcıları listeler.
// Kullanım: API_URL=https://... ADMIN_SECRET=... node scripts/list-users.mjs

const apiUrl = process.env.API_URL;
const adminSecret = process.env.ADMIN_SECRET;

if (!apiUrl || !adminSecret) {
  console.error('Kullanım: API_URL=https://hophop.vercel.app ADMIN_SECRET=... node scripts/list-users.mjs');
  process.exit(1);
}

const res = await fetch(`${apiUrl}/api/admin/users`, {
  headers: { 'X-Admin-Secret': adminSecret },
});
const body = await res.json();

if (!res.ok) {
  console.error(`❌ Hata (${res.status}):`, body);
  process.exit(1);
}

for (const u of body.users) {
  console.log(`${u.firstName} ${u.lastName}  [${u.id}]  cihaz: ${u.devices}  anahtar: ${u.hasPublicKey ? '✓' : '—'}`);
}
console.log(`\nToplam: ${body.users.length} kullanıcı`);
