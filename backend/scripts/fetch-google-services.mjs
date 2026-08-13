#!/usr/bin/env node
// Firebase'den google-services.json indirir (Android uygulaması yoksa oluşturur).
// Kullanım: backend/ dizininde, .env dosyası doluyken: node scripts/fetch-google-services.mjs

import { readFileSync, writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';

const here = dirname(fileURLToPath(import.meta.url));
const envFile = resolve(here, '../.env');
const target = resolve(here, '../../app/android/app/google-services.json');
const PACKAGE = 'com.hophop.hophop';

const env = Object.fromEntries(
  readFileSync(envFile, 'utf8').split('\n')
    .filter((l) => l.includes('=') && !l.trim().startsWith('#'))
    .map((l) => { const [k, ...r] = l.split('='); return [k.trim(), r.join('=').trim().replace(/^["']|["']$/g, '')]; }),
);
const sa = JSON.parse(Buffer.from(env.FIREBASE_SERVICE_ACCOUNT, 'base64').toString());
const { GoogleAuth } = await import('google-auth-library');
const auth = new GoogleAuth({
  credentials: sa,
  scopes: ['https://www.googleapis.com/auth/cloud-platform', 'https://www.googleapis.com/auth/firebase'],
});
const { token } = await (await auth.getClient()).getAccessToken();
const H = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };
const base = `https://firebase.googleapis.com/v1beta1/projects/${sa.project_id}`;

let body = await (await fetch(`${base}/androidApps`, { headers: H })).json();
let app = (body.apps ?? []).find((a) => a.packageName === PACKAGE);
if (!app) {
  const res = await fetch(`${base}/androidApps`, {
    method: 'POST', headers: H,
    body: JSON.stringify({ packageName: PACKAGE, displayName: 'HopHop' }),
  });
  const op = await res.json();
  if (!res.ok) throw new Error(`create failed: ${JSON.stringify(op)}`);
  for (let i = 0; i < 20 && !app; i++) {
    await new Promise((r) => setTimeout(r, 1500));
    const o = await (await fetch(`https://firebase.googleapis.com/v1beta1/${op.name}`, { headers: H })).json();
    if (o.done) app = o.response;
  }
  if (!app) {
    const list = await (await fetch(`${base}/androidApps`, { headers: H })).json();
    app = (list.apps ?? []).find((a) => a.packageName === PACKAGE);
  }
}
if (!app) throw new Error('Android app not found/created');

body = await (await fetch(`https://firebase.googleapis.com/v1beta1/${app.name}/config`, { headers: H })).json();
writeFileSync(target, Buffer.from(body.configFileContents, 'base64').toString());
console.log(`✓ google-services.json → ${target} (proje: ${sa.project_id})`);
