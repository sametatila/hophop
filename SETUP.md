# HopHop — Kurulum: Senin Yapacakların

Kod hazır: `backend/` (Vercel API + yönetici betikleri) ve `app/` (Flutter uygulaması).
Aşağıdaki adımlar bir kez yapılır; sonrası sadece kullanıcı eklemek ve APK dağıtmak.

## 0) Araçlar (bir kez kur)

- [ ] **Flutter SDK** + **Android Studio** (Android SDK için) — `flutter doctor` temiz olsun
- [ ] **Node.js 18+** (sende var) ve **Vercel CLI**: `npm i -g vercel`

## 1) Hesaplar

- [x] **Firebase** → proje `hophop-59a59` ✅ TAMAMLANDI (2026-08-13)
  - ✅ Firestore (default, europe-west3) mevcut, güvenlik kuralları API ile dağıtıldı
  - ✅ Android uygulaması (`com.hophop.hophop`) API ile oluşturuldu,
    `google-services.json` indirildi → `app/android/app/` içinde
  - Yeni klonda tekrar indirmek için: `cd backend && node scripts/fetch-google-services.mjs`
  - [x] **Authentication** etkin ✅ (gerçek-zamanlı zil dinleyicisi bunu kullanır)
- [x] **LiveKit Cloud** ✅ anahtarlar `.env`'de, canlıda doğrulandı
- [x] **Vercel** ✅ GitHub bağlı, otomatik deploy; özel alan adı: **hophop.exfe.me**

## 2) Gizli anahtarları üret

```bash
openssl rand -hex 32   # 4 kez çalıştır: PEPPER, PROFILE_KEY, JWT_SECRET, ADMIN_SECRET
base64 -w0 indirdigin-service-account.json   # → FIREBASE_SERVICE_ACCOUNT değeri
```

Değerleri bir yere (şifre yöneticisi) kaydet. `backend/.env.example` hangi değişkenin ne olduğunu açıklıyor.

## 3) Backend deploy ✅ TAMAMLANDI

- Vercel, GitHub `main` dalından otomatik deploy alıyor (Root Directory: `backend`,
  bölge: fra1). Üretim adresi: **https://hophop.exfe.me** (eski
  `hophop-kappa.vercel.app` da çalışır). Tüm uçlar tek fonksiyonda
  (`api/router.ts` + rewrite) — Hobby 12-fonksiyon sınırına takılmaz.
- Uçtan uca doğrulama: `cd backend && node scripts/e2e-test.mjs` (39 test) ve
  `node scripts/photo-test.mjs` (16 test — profil fotoğrafı akışı)

## 3.5) Tanıtım sayfası (hophop.exfe.me)

Aynı Vercel projesi hem API'yi hem tanıtım sayfasını sunar — ayrı proje gerekmez.
Sayfa `backend/public/` içinde, tek dosya (`index.html`), derleme adımı yok.

- [x] **Alan adı bağlı** ✅ — https://hophop.exfe.me yayında (sayfa + API aynı proje).
- **İndirme butonu** artık `version.json`'daki adresi okuyor — yeni sürüm
  çıktıkça sayfayı elle güncellemek gerekmez; buton doğru sürüme bakar ve
  altında "Sürüm x.y.z · NN MB" yazar. Dosya henüz yoksa "APK'yı sana aileden
  gönderiyorlar" uyarısına düşer.
- [ ] **Bir kez kur:** `sudo pacman -S github-cli && gh auth login`
  APK **GitHub Releases**'e yükleniyor (§6.5): ücretsiz, bant genişliği
  sınırsız, git geçmişini şişirmez. Depoya commit'lemek her sürümde geçmişe
  kalıcı 83 MB eklerdi — beş sürümde repo 1.4 MB'tan ~415 MB'a çıkardı.
- Sosyal medya önizleme görseli `public/og.jpg`; kaynağı `backend/assets/og-source.svg`.
  Değiştirirsen yeniden üret:
  `google-chrome-stable --headless --window-size=1200,630 --screenshot=og.png assets/og-source.svg`
- Tasarım, uygulamanın `app/lib/theme/hop_theme.dart` belirteçlerine bağlı
  (indigo→mor→camgöbeği degradesi, tavşan markası, Manrope, 18 px köşe). Temayı
  değiştirirsen sayfadaki `:root` değişkenlerini de güncelle.

## 4) Aile üyelerini kaydet

```bash
cd backend
API_URL=https://hophop.exfe.me ADMIN_SECRET=<secret> \
  node scripts/add-user.mjs "Ali" "Yılmaz" 2016-05-21
```

- Herkes için bir kez. Listele: `node scripts/list-users.mjs` (aynı env ile)
- Ad/soyad yazımı esnek (büyük-küçük harf, Türkçe karakter farkı sorun değil)
  ama **doğum tarihi birebir doğru olmalı** — giriş anahtarı bu.
- Doğum tarihi 13 yaş altını gösteriyorsa uygulama **çocuk modunda** açılır
  (büyük butonlar, canlı renkler); üstü yetişkin temasında.
- Silme: `curl -X DELETE -H "X-Admin-Secret: ..." -H "Content-Type: application/json" -d '{"userId":"<id>"}' https://hophop.exfe.me/api/admin/users`
- Ayrıntılı liste (doğum tarihleriyle, yalnızca yerelde): proje kökündeki
  `KULLANICILAR.md` — gitignore'da, public repoya gitmez.

## 4.5) ⚠️ Yayın imzası — derlemeden ve dağıtımdan ÖNCE, bir kez

**Bunu yapmadan APK dağıtma.** Şu an release derlemesi Android'in *debug*
anahtarıyla imzalanıyor. Debug anahtarı bu bilgisayara özel ve silinirse geri
gelmez; farklı anahtarla imzalanmış yeni sürüm kurulu uygulamanın **üstüne
kurulamaz** (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`). O noktada tek çare herkesin
uygulamayı silip yeniden kurması — yani herkesin oturumu ve E2EE anahtarı gider.

- [ ] **Anahtarı üret** (parolayı sen belirlersin, betik sorar):
  ```bash
  cd app
  ./make-release-key.sh
  ```
  → `android/hophop-release.jks` + `android/key.properties` (ikisi de .gitignore'da)
- [ ] **Bu iki dosyayı şifre yöneticine yedekle.** Kaybedersen yukarıdaki senaryo.
- [ ] Sonra `flutter build apk --release` — gradle anahtarı otomatik bulur.
  `key.properties` yoksa derleme yine çalışır ama uyarı basar ve debug'a düşer;
  o APK'yı dağıtma. `publish-release.mjs` de böyle bir APK'yı fark edip durdurur.

## 5) APK'yı derle

```bash
cd app
flutter pub get
flutter build apk --release --target-platform android-arm64
# çıktı: build/app/outputs/flutter-apk/app-release.apk
```

- `android/` klasörü artık repoda hazır (setup_android.py yalnızca sıfırdan
  kurulumda gerekir). Varsayılan API adresi **https://hophop.exfe.me** koda
  gömülü — `--dart-define` gerekmez; farklı ortam için
  `--dart-define=HOPHOP_API=...` ile ezilir.
- Taze klonda `google-services.json` eksikse:
  `cd backend && node scripts/fetch-google-services.mjs`
- Sürüm uyuşmazlığı hatası çıkarsa: `flutter pub upgrade` deneyip tekrar derle.
- **Neden `--target-platform android-arm64`:** ML Kit + WebRTC + Firebase yerel
  kütüphaneleri her işlemci mimarisi için ayrı ayrı pakete giriyor. Bayraksız
  **126 MB**, arm64 ile **87 MB** (ölçüldü). Ailedeki cihazların hepsi 2018
  sonrası, yani 64-bit ARM — tek mimari yeterli. Kalan boyutun büyük kısmı ML
  Kit'in gömülü yüz modeli ve WebRTC; onlar mimariden bağımsız.
  (İleride çok eski bir tablet çıkarsa bayrağı kaldırıp yeniden derlemek yeter;
  kurulu uygulamalar etkilenmez.)

## 6) Dağıt ve test et

- [ ] APK'yı aile üyelerine gönder (dağıtım kararı §3.5'teki üç seçenekten biri)
- [ ] Her cihazda: kur → ad-soyad-doğum tarihiyle gir → izin sihirbazını tamamla
  (Xiaomi/Oppo/Vivo'da pil kartı otomatik görünür; ayrıca Ayarlar'da
  "Otomatik başlatma" rehberi var) → bir daha giriş istemez
- [ ] İki cihazla uçtan uca kontrol listesi:
  - Arkadaşlık: istek gönder → İstekler rozetinde sayı → kabul → kart ana ekranda
  - Arama: ekran KAPALIYKEN ara → arama ekranı doğrudan açılmalı (tam ekran);
    uygulama açıkken ara → üstten şerit çıkmadan ekran + uygulama zili
  - Görüşmede: hoparlör düğmesi, kendi görüntüne dokununca kamera değişimi,
    efekt seçici (4 kategori / 45 efekt): hayvan (ağız açınca köpek dili,
    kurbağa dili), şapka (pervane dönmeli), yüz, sihir (kar/konfeti yüz
    görünmese de akmalı; "Renkli ağız" ağız açınca) — karşı cihazda da görünmeli
  - Meşgul testi: biri görüşmedeyken üçüncü kişi arasın → "Meşgul" anında dönmeli
  - İptal testi: A arar, B cevaplamadan A kapatır → B'de zil ANINDA susmalı,
    gelen arama ekranı kapanmalı, cevapsız rozeti düşmeli; B tam o anda
    cevaplarsa "Arama sona ermiş" görmeli (boş odaya bağlanmamalı)
  - Mesaj: gönder (saat→✓), karşı cihaza düşünce ✓✓, sohbet açınca rozet sıfır;
    "yazıyor…" göstergesi; bildirime dokununca sohbet açılmalı
  - Sohbette arama kayıtları: süreli "Görüntülü arama · 2 dk", kırmızı cevapsızlar
  - Kesinti: görüşmede WiFi'ı 10 sn kapat → "Yeniden bağlanıyor…" → toparlanma;
    30 sn+ kopunca "Bağlantı koptu — Yeniden ara" teklifi
- [ ] Doğum günü şeridi: doğum günü yaklaşan biri ana ekranda görünmeli

## 6.5) Yeni sürüm yayınlama (uygulama içi güncelleme)

Uygulama mağazada olmadığı için Play'in güncelleme akışı yok; onun yerine
sunucudaki `version.json` okunuyor. Akış tek komut:

```bash
# 1. Sürüm numarasını artır — app/pubspec.yaml
#    version: 1.0.0+1  →  version: 1.1.0+2      (Android yalnızca +N'ye bakar)

# 2. Derle (imza anahtarı §4.5'te hazır olmalı)
cd app && flutter build apk --release --target-platform android-arm64

# 3. Yayınla: APK'yı GitHub Releases'e yükler + version.json'ı günceller
cd ../backend
node scripts/publish-release.mjs --notes "Efekt şeridi hızlandı"

# 4. Deploy
git add backend/public && git commit -m "Sürüm 1.1.0" && git push
```

Betik, APK debug anahtarıyla imzalanmışsa ya da sürüm kodu artmamışsa **durur** —
en sık yapılan iki hata bunlar.

Kullanıcı tarafında ne oluyor:

- Ana ekranda ve Ayarlar'da "Yeni sürüm hazır" kartı çıkar (`--notes` metni burada
  görünür). Elle bakmak isteyen: **Ayarlar → Uygulama sürümü → Denetle**.
- "Şimdi güncelle" → APK iner → sistem kurulum ekranı açılır → kullanıcı onaylar.
  Sessiz kurulum yok; veriler ve oturum korunur.
- Android 8+ ilk seferde "bu kaynaktan kuruluma izin ver" ister; uygulama bu izni
  açıklayan bir diyalog gösterip doğrudan ilgili ayar ekranına götürür.
- Otomatik denetim 6 saatte bir; ağ yoksa sessizce geçer, kullanıcıyı rahatsız etmez.

APK nerede duruyor: **GitHub Releases** — `v1.1.0` etiketi altında
`hophop-1.1.0.apk`. Betik sürümü kendisi oluşturur; aynı sürüm ikinci kez
yayınlanırsa varlığı değiştirir. Diğer seçenekler:
- `--url https://.../hophop.apk` → APK'yı kendin başka yere koyduysan
- `--local` → eski davranış: `public/hophop.apk`'ya kopyalar (repoyu şişirir)

⚠️ Release varlıkları herkese açıktır (repo zaten public). Giriş yine de
ad + soyad + doğum tarihi kaydı ister — APK'ya sahip olmak yetmez.

## 7) İşletme (düzenli)

- Ayda bir **LiveKit dashboard** → dakika kullanımı (ücretsiz: 5.000 katılımcı-dk/ay;
  grup aramada her katılımcı ayrı sayılır). Aşarsa: ücretli katman ya da self-host
- Her backend değişikliğinden sonra: `node scripts/e2e-test.mjs` (39 test) +
  `node scripts/photo-test.mjs` (16 test)
- Yeni aile üyesi = adım 4 + APK gönder
- Yeni sürüm = adım 6.5 (tek komut); kimseye APK göndermene gerek kalmaz
- Sorun yaşayan cihaz = uygulamada **Ayarlar → İzin durumu → Düzelt**
- **Emülatörde** bildirim/zil kesilirse: WiFi kapat-aç (bayat GCM bağlantısı) ya da
  cold boot — gerçek cihazlarda bu sorun yoktur

## Bilinmesi iyi olan sınırlar

- **Gizlilik:** Aramalar LiveKit E2EE ile uçtan uca şifreli; oda anahtarı cihazlarda
  ECDH ile türetilir, hiçbir sunucuya gitmez. Sen dahil kimse içeriği göremez.
  Veritabanında kimlik bilgileri hash + AES-256-GCM şifreli durur.
- **Efektler** ML Kit tabanlı overlay'dir (ücretsiz, sınırsız kullanıcı): 4 kategori,
  45 efekt — Hayvanlar (14), Şapkalar (12), Yüz (10), Sihir (9, animasyonlu parçacık).
  Tümü vektörel çizim: asset/paket yok, APK büyümez. Gerçek yüz *deformasyonu*
  (balık yüzü gibi) overlay ile yapılamaz — istersen ileride DeepAR ücretli
  katmanına geçilir (plan §5.4).
- Düşük donanımlı tablette efekt takılırsa `face_tracker.dart` içindeki 125 ms
  aralığını büyüt (ör. 200).
- Cihaz kaybı/sıfırlama: aynı bilgilerle tekrar girilir; yeni E2EE anahtarı otomatik üretilir.
