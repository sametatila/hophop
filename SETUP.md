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
- [ ] **LiveKit Cloud** → proje aç → **API Key + Secret + wss URL** not al
- [ ] **Vercel** hesabı (varsa geç)

## 2) Gizli anahtarları üret

```bash
openssl rand -hex 32   # 4 kez çalıştır: PEPPER, PROFILE_KEY, JWT_SECRET, ADMIN_SECRET
base64 -w0 indirdigin-service-account.json   # → FIREBASE_SERVICE_ACCOUNT değeri
```

Değerleri bir yere (şifre yöneticisi) kaydet. `backend/.env.example` hangi değişkenin ne olduğunu açıklıyor.

## 3) Backend'i deploy et

GitHub üzerinden (önerilen — monorepo):

1. Repoyu GitHub'a pushla (repo kökü `hophop/`, gizli değerler `.gitignore`'da)
2. Vercel → **Add New Project** → GitHub reposunu seç
3. **Root Directory: `backend`** olarak ayarla (monorepo için şart)
4. Environment Variables → `backend/.env` içindeki 8 değişkeni gir → Deploy

Ya da CLI ile: `cd backend && npm install && vercel --prod`

Test: `curl -H "X-Admin-Secret: <ADMIN_SECRET>" https://<proje>.vercel.app/api/admin/users`
→ `{"users":[]}` dönerse hazır.

## 4) Aile üyelerini kaydet

```bash
cd backend
API_URL=https://<proje>.vercel.app ADMIN_SECRET=<secret> \
  node scripts/add-user.mjs "Ali" "Yılmaz" 2016-05-21
```

- Herkes için bir kez. Listele: `node scripts/list-users.mjs` (aynı env ile)
- Ad/soyad yazımı esnek (büyük-küçük harf, Türkçe karakter farkı sorun değil)
  ama **doğum tarihi birebir doğru olmalı** — giriş anahtarı bu.
- Silme: `curl -X DELETE -H "X-Admin-Secret: ..." -H "Content-Type: application/json" -d '{"userId":"<id>"}' .../api/admin/users`

## 5) APK'yı derle

```bash
cd app
python3 setup_android.py    # android/ iskeletini üretir + izinleri/gradle'ı yamalar
# → google-services.json'u app/android/app/ içine koy (adım 1'den)
flutter pub get
flutter build apk --release --dart-define=HOPHOP_API=https://<proje>.vercel.app
# çıktı: build/app/outputs/flutter-apk/app-release.apk
```

Sürüm uyuşmazlığı hatası çıkarsa: `flutter pub upgrade` deneyip tekrar derle.

## 6) Dağıt ve test et

- [ ] APK'yı aile üyelerine **doğrudan** gönder (herkese açık linke koyma — plan §3.3)
- [ ] Her cihazda: kur → ad-soyad-doğum tarihiyle gir → izin sihirbazını tamamla
  (Xiaomi/Oppo/Vivo'da pil kartı otomatik görünür) → bir daha giriş istemez
- [ ] İki cihazla uçtan uca test: arkadaşlık isteği → kabul → kilitli ekranda arama →
  Cevapla → görüntü → efekt şeridinden 🐶 seç, ağız açınca dil çıkmalı
- [ ] Doğum günü şeridi: doğum günü yaklaşan biri ana ekranda görünmeli

## 7) İşletme (düzenli)

- Ayda bir **LiveKit dashboard** → dakika kullanımı (ücretsiz: 5.000 katılımcı-dk/ay,
  ~41 saat ikili görüşme). Aşarsa: ücretli katman ya da self-host (plan §6)
- Yeni aile üyesi = adım 4 + APK gönder
- Sorun yaşayan cihaz = uygulamada **Ayarlar → İzin durumu → Düzelt**

## Bilinmesi iyi olan sınırlar

- **Gizlilik:** Aramalar LiveKit E2EE ile uçtan uca şifreli; oda anahtarı cihazlarda
  ECDH ile türetilir, hiçbir sunucuya gitmez. Sen dahil kimse içeriği göremez.
  Veritabanında kimlik bilgileri hash + AES-256-GCM şifreli durur.
- **Efektler** ML Kit tabanlı overlay'dir (ücretsiz, sınırsız kullanıcı): tavşan, köpek
  (ağız açınca dil), taç, gözlük, bıyık. Gerçek yüz *deformasyonu* (balık yüzü gibi)
  overlay ile yapılamaz — istersen ileride DeepAR ücretli katmanına geçilir (plan §5.4).
- Düşük donanımlı tablette efekt takılırsa `face_tracker.dart` içindeki 125 ms
  aralığını büyüt (ör. 200).
- Cihaz kaybı/sıfırlama: aynı bilgilerle tekrar girilir; yeni E2EE anahtarı otomatik üretilir.
