#!/usr/bin/env node
// HopHop yönetici betiği — aile üyesi ekler.
// Kullanım: API_URL=https://... ADMIN_SECRET=... node scripts/add-user.mjs "Ad" "Soyad" 2016-05-21

const [firstName, lastName, birthDate] = process.argv.slice(2);
const apiUrl = process.env.API_URL;
const adminSecret = process.env.ADMIN_SECRET;

if (!firstName || !lastName || !birthDate || !apiUrl || !adminSecret) {
  console.error('Kullanım: API_URL=https://hophop.vercel.app ADMIN_SECRET=... \\');
  console.error('          node scripts/add-user.mjs "Ad" "Soyad" YYYY-AA-GG');
  process.exit(1);
}

const res = await fetch(`${apiUrl}/api/admin/add-user`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', 'X-Admin-Secret': adminSecret },
  body: JSON.stringify({ firstName, lastName, birthDate }),
});
const body = await res.json();

if (res.ok) {
  console.log(`✅ Eklendi: ${firstName} ${lastName} (${birthDate}) → id: ${body.userId}`);
  console.log('   Bu kişi artık uygulamada bu bilgilerle giriş yapabilir.');
} else {
  console.error(`❌ Hata (${res.status}):`, body);
  process.exit(1);
}
