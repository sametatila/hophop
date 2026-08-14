#!/usr/bin/env node
/**
 * HopHop — yeni sürüm yayınlar.
 *
 *   cd backend
 *   node scripts/publish-release.mjs --notes "Efekt şeridi hızlandı"
 *
 * Yaptıkları:
 *   1. app/pubspec.yaml'daki sürümü okur (1.2.0+3 → sürüm 1.2.0, kod 3)
 *   2. Derlenmiş APK'yı bulur, DEBUG anahtarıyla imzalanmışsa uyarır ve durur
 *   3. APK'yı GitHub Releases'e yükler (bkz. aşağıda)
 *   4. public/version.json'ı günceller (uygulama bunu okuyup güncelleme önerir)
 *
 * Sonrası: git add/commit/push → Vercel otomatik deploy eder.
 *
 * APK NEREDE DURUR: varsayılan olarak GitHub Releases'e yüklenir.
 * Neden: 83 MB'lık dosya git geçmişine girmez (repo 1.4 MB kalır), bant
 * genişliği sınırsız ve ücretsiz, adres kalıcı. Depoya commit'lemek her
 * sürümde geçmişe kalıcı 83 MB eklerdi.
 *
 * Seçenekler:
 *   --notes "<metin>"   uygulamada güncelleme kartında görünecek kısa açıklama
 *   --apk <yol>         varsayılan: ../app/build/app/outputs/flutter-apk/app-release.apk
 *   --url <adres>       APK'yı başka yerde barındırıyorsan (Drive/S3) tam adres;
 *                       yükleme de kopyalama da yapılmaz
 *   --local             GitHub yerine public/hophop.apk'ya kopyala (repoyu şişirir)
 *   --dry-run           hiçbir şey yüklemeden/yazmadan ne olacağını gösterir
 */
import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, copyFileSync, writeFileSync, statSync, readdirSync, unlinkSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const BACKEND = resolve(HERE, '..');
const ROOT = resolve(BACKEND, '..');
const PUBSPEC = join(ROOT, 'app/pubspec.yaml');
const PUBLIC = join(BACKEND, 'public');

function arg(name, fallback = null) {
  const i = process.argv.indexOf(`--${name}`);
  return i !== -1 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}
const dryRun = process.argv.includes('--dry-run');
const useLocal = process.argv.includes('--local');
const die = (msg) => { console.error(`✗ ${msg}`); process.exit(1); };

// ---- 1) Sürüm ----
if (!existsSync(PUBSPEC)) die(`pubspec.yaml bulunamadı: ${PUBSPEC}`);
const m = readFileSync(PUBSPEC, 'utf8').match(/^version:\s*([0-9.]+)\+(\d+)\s*$/m);
if (!m) die('pubspec.yaml içindeki "version: x.y.z+N" satırı okunamadı');
const [, version, codeStr] = m;
const versionCode = Number(codeStr);

// ---- 2) APK ----
const externalUrl = arg('url');
const APK_DIR = join(ROOT, 'app/build/app/outputs/flutter-apk');
// --target-platform android-arm64 tek app-release.apk üretir; --split-per-abi
// kullanılırsa dosya adı mimariyi taşır. İkisini de bul.
const apkPath = resolve(arg('apk',
  [join(APK_DIR, 'app-release.apk'), join(APK_DIR, 'app-arm64-v8a-release.apk')]
    .find(existsSync) ?? join(APK_DIR, 'app-release.apk')));
let size;

if (!externalUrl) {
  if (!existsSync(apkPath)) {
    die(`APK yok: ${apkPath}\n` +
        '  Önce: cd app && flutter build apk --release --target-platform android-arm64');
  }
  size = statSync(apkPath).size;

  // Debug anahtarıyla imzalanmış APK dağıtılırsa bir daha güncelleme kurulamaz.
  const signer = findApksigner();
  if (signer) {
    try {
      const out = execFileSync(signer, ['verify', '--print-certs', apkPath], {
        encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'],
        // apksigner betiği doğrudan "java" çağırır (JAVA_HOME'a bakmaz), bu yüzden
        // PATH'in başına Android Studio'nun JDK'sı eklenir.
        env: javaHome()
          ? { ...process.env, JAVA_HOME: javaHome(), PATH: `${javaHome()}/bin:${process.env.PATH}` }
          : process.env,
      });
      if (/CN=Android Debug/i.test(out)) {
        die('Bu APK DEBUG anahtarıyla imzalanmış — dağıtma!\n' +
            '  Önce: cd app && ./make-release-key.sh, sonra yeniden derle.\n' +
            '  (Ayrıntı: SETUP.md §4.5)');
      }
      console.log('✓ İmza kontrolü: yayın anahtarı kullanılmış');
    } catch (e) {
      if (e.status !== undefined && !e.stdout) console.warn(`⚠ apksigner çalıştırılamadı: ${e.message}`);
    }
  } else {
    console.warn('⚠ apksigner bulunamadı — imza kontrolü atlandı.');
  }
}

// ---- 3) version.json ----
const versionFile = join(PUBLIC, 'version.json');
const previous = existsSync(versionFile)
  ? JSON.parse(readFileSync(versionFile, 'utf8'))
  : { versionCode: 0 };

// İlk yayın istisnası: version.json başlangıç değerini taşıyorsa (henüz hiç
// sürüm çıkılmamış) aynı sürüm kodu kabul edilir. Aksi hâlde kullanıcı ilk
// yayında sebepsiz yere sürüm artırmak ya da --force geçmek zorunda kalıyordu.
const neverPublished = !previous.url || previous.url === '/hophop.apk';
if (versionCode <= previous.versionCode && !neverPublished &&
    !process.argv.includes('--force')) {
  die(`pubspec sürüm kodu (${versionCode}) yayındakinden (${previous.versionCode}) büyük değil.\n` +
      '  app/pubspec.yaml içindeki "version: x.y.z+N" satırında N\'yi artır.\n' +
      '  (Android yalnızca bu sayıya bakar; artmazsa güncelleme görünmez.)');
}

const manifest = {
  versionCode,
  version,
  url: externalUrl ?? '/hophop.apk',
  ...(size ? { size } : {}),
  notes: arg('notes', previous.notes ?? '') ?? '',
};

console.log(`\nSürüm ${version} (kod ${versionCode})`);
if (!externalUrl) {
  const hedef = useLocal ? 'public/hophop.apk' : 'GitHub Releases';
  console.log(`APK   ${apkPath}\n      ${(size / 1024 / 1024).toFixed(1)} MB → ${hedef}`);
} else {
  console.log(`URL   ${externalUrl} (yükleme yok)`);
}
if (manifest.notes) console.log(`Not   ${manifest.notes}`);

if (dryRun) {
  console.log('\n(--dry-run: hiçbir dosya yazılmadı)');
  console.log(JSON.stringify(manifest, null, 2));
  process.exit(0);
}

if (!externalUrl) {
  if (useLocal) {
    copyFileSync(apkPath, join(PUBLIC, 'hophop.apk'));
    console.log('\n✓ public/hophop.apk kopyalandı (--local)');
  } else {
    manifest.url = uploadToGithub(apkPath, version, manifest.notes);
  }
}
writeFileSync(versionFile, `${JSON.stringify(manifest, null, 2)}\n`);

console.log('\n✓ public/version.json güncellendi → ' + manifest.url);
console.log('\nSıradaki adım:');
console.log('  git add backend/public && git commit -m "Sürüm ' + version + '" && git push');
console.log('  → Vercel deploy eder, uygulamalar 6 saat içinde güncellemeyi görür');
console.log('    (Ayarlar → Uygulama sürümü → Denetle ile hemen de bakılabilir)');

/** APK'yı GitHub Releases'e yükler, indirilebilir adresi döndürür.
 * Aynı sürüm ikinci kez yayınlanırsa varlık üzerine yazılır (--clobber). */
function uploadToGithub(apk, version, notes) {
  const tag = `v${version}`;
  const asset = `hophop-${version}.apk`;
  const slug = repoSlug();
  const run = (args) =>
    execFileSync('gh', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });

  try {
    execFileSync('gh', ['--version'], { stdio: 'ignore' });
  } catch {
    die('gh (GitHub CLI) bulunamadı.\n' +
        '  Kur: sudo pacman -S github-cli   (sonra: gh auth login)\n' +
        '  Ya da APK\'yı elle yükleyip: node scripts/publish-release.mjs --url <adres>');
  }

  const tmp = join(dirname(apk), asset);
  copyFileSync(apk, tmp); // varlık adı sürümü taşısın
  try {
    let exists = true;
    try {
      run(['release', 'view', tag]);
    } catch {
      exists = false;
    }
    if (exists) {
      console.log(`\n↑ ${tag} sürümü var — varlık güncelleniyor…`);
      run(['release', 'upload', tag, tmp, '--clobber']);
    } else {
      console.log(`\n↑ ${tag} sürümü oluşturuluyor…`);
      run(['release', 'create', tag, tmp,
           '--title', `HopHop ${version}`,
           '--notes', notes || `HopHop ${version}`]);
    }
  } catch (e) {
    die(`GitHub'a yükleme başarısız: ${e.stderr?.toString?.() ?? e.message}`);
  } finally {
    try { unlinkSync(tmp); } catch {}
  }
  console.log('✓ GitHub Releases\'e yüklendi');
  return `https://github.com/${slug}/releases/download/${tag}/${asset}`;
}

/** origin uzak adresinden "kullanıcı/repo" çıkarır. */
function repoSlug() {
  const url = execFileSync('git', ['remote', 'get-url', 'origin'], { encoding: 'utf8' }).trim();
  const m = url.match(/github\.com[:/](.+?)(?:\.git)?$/);
  if (!m) die(`origin GitHub deposu değil: ${url}`);
  return m[1];
}

/** java PATH'te yoksa Android Studio'nun paketlediği JDK'yı bulur. */
function javaHome() {
  if (process.env.JAVA_HOME) return process.env.JAVA_HOME;
  for (const p of ['/opt/android-studio/jbr', join(process.env.HOME ?? '', 'android-studio/jbr'),
                   '/usr/lib/jvm/default', '/Applications/Android Studio.app/Contents/jbr/Contents/Home']) {
    if (existsSync(join(p, 'bin/java'))) return p;
  }
  return null;
}

/** Android SDK build-tools içindeki en yeni apksigner'ı bulur. */
function findApksigner() {
  const sdk = process.env.ANDROID_HOME || process.env.ANDROID_SDK_ROOT ||
    join(process.env.HOME ?? '', 'Android/Sdk');
  const dir = join(sdk, 'build-tools');
  if (!existsSync(dir)) return null;
  const versions = readdirSync(dir).sort();
  for (const v of versions.reverse()) {
    const p = join(dir, v, 'apksigner');
    if (existsSync(p)) return p;
  }
  return null;
}
