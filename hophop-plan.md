# HopHop — Aile İçi Görüntülü Görüşme Uygulaması — Plan

**Amaç:** Geniş ailenin (çocuklar, kuzenler, anne-babalar, amcalar, teyzeler…) kendi
aralarında **sesli ve görüntülü** görüşebildiği, kurulumu ve kullanımı çocuk kadar
büyükanne için de kolay, **gizliliğe saygılı** bir Android uygulaması. Tüm altyapı
ücretsiz katmanlarda başlar.

**Kullanıcı modeli:** Uygulamaya erişim = APK'ya sahip olmak + yönetici (sen)
tarafından veritabanına önceden işlenmiş **ad + soyad + doğum tarihi** bilgisini
bilmek. Uygulama mağazasında yayınlanmaz, davetle dağıtılır.

---

## 1. Neden PWA değil, neden native (özet)

Android'de kurulu bir PWA'ya FCM üzerinden gönderilen push bildirimleri, payload
yüksek öncelikli olsa bile yalnızca durum çubuğunda görünüyor; heads-up bildirim
çıkmıyor. Bir çocuğun ya da yaşlı bir aile üyesinin bunu fark etmesi beklenemez.
Native uygulamada `IMPORTANCE_HIGH` bildirim kanalı ile çalan, ekranın üstünde
beliren gelen-arama bildirimi kutudan çıktığı gibi çalışır. **Native Flutter uygulaması.**

---

## 2. Mimari

```
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ Aile üyesi A │   │ Aile üyesi B │   │ Aile üyesi … │     (hepsi aynı HopHop APK)
└──────┬───────┘   └──────┬───────┘   └──────┬───────┘
       │                  │                  │
       │  giriş / profil / arkadaşlık / arama tetikleme (HTTPS)
       ▼                  ▼                  ▼
   ┌────────────────────────────────────────────────┐
   │  Vercel (Hobby) — API katmanı                  │
   │  /api/login   → kimlik doğrulama, oturum JWT   │
   │  /api/call    → karşı tarafa FCM push          │
   │  /api/token   → LiveKit erişim token'ı         │
   └──────┬─────────────────────────┬───────────────┘
          │                         │
          ▼                         ▼
   ┌──────────────┐         ┌─────────────────────────┐
   │  Firestore   │         │  FCM (push bildirimleri)│
   │  profiller,  │         └─────────────────────────┘
   │  arkadaşlık, │
   │  istekler    │         ┌─────────────────────────┐
   └──────────────┘         │  LiveKit Cloud (SFU)    │
                            │  ses + görüntü, E2EE ile│
                            │  ŞİFRELİ geçer — sunucu │
                            │  içeriği ÇÖZEMEZ        │
                            └─────────────────────────┘
```

Kritik noktalar:
- **LiveKit SFU** kullanıldığı için CGNAT, NAT traversal, TURN — hiçbiri bizim
  problemimiz değil. Medya LiveKit sunucularından geçer ama **uçtan uca şifreli**
  (aşağıda §3.4).
- **Vercel tarafı sadece HTTP.** WebSocket yok; serverless süre limitleri devreye girmez.
- Tek uygulama, tek rol. `parent`/`kid` ayrımı yok — herkes aynı APK'yı kullanır.
  Yönetim (kullanıcı ekleme) uygulamanın dışında, senin çalıştırdığın bir betikle yapılır.

---

## 3. Kimlik, güvenlik ve gizlilik modeli

### 3.1 Kayıt (yönetici tarafında)

Sen, her aile üyesini bir **yönetici betiği** ile (Node.js CLI, `ADMIN_SECRET` ile
Vercel'deki `/api/admin/add-user`a istek atar) veritabanına işlersin:

- Girdi: ad, soyad, doğum tarihi (`YYYY-AA-GG`)
- Betik iki şey üretir:
  1. **Kimlik hash'i** (giriş doğrulaması için):
     `SHA-256(PEPPER + normalize(ad) + "|" + normalize(soyad) + "|" + doğumTarihi)`
     - `normalize`: küçük harf, Türkçe karakter sadeleştirme (ç→c, ğ→g…), boşluk temizliği —
       "Ayşe Öztürk" ile "ayse ozturk" aynı kişiye çözülsün.
     - `PEPPER`: sadece Vercel ortam değişkeninde duran gizli değer. Veritabanı sızsa
       bile hash'lerden kimlik bilgisi türetilemez, sözlük saldırısı yapılamaz.
  2. **Şifrelenmiş profil alanları** (görüntüleme için): ad, soyad, doğum tarihi
     AES-256-GCM ile şifrelenir; anahtar (`PROFILE_KEY`) yine yalnızca Vercel ortam
     değişkeninde. Firestore'da hiçbir kimlik bilgisi düz metin durmaz.

> Neden iki biçim? Hash geri döndürülemez — girişte doğrulamak için ideal ama
> "yaklaşan doğum günleri" gibi özellikler için işe yaramaz. Şifreli kopya, API
> katmanında çözülüp **yalnızca oturum açmış ve arkadaş olan** kullanıcılara servis edilir.

### 3.2 Giriş (kullanıcı tarafında)

- İlk açılışta üç alan: **Ad, Soyad, Doğum tarihi** (doğum tarihi için çocukların da
  kullanabileceği büyük, görsel bir gün/ay/yıl seçici).
- Uygulama bilgileri `/api/login`a gönderir → sunucu hash'i hesaplar, eşleşme varsa
  **uzun ömürlü oturum JWT'si** (ör. 1 yıl) döner.
- JWT + kullanıcının cihazda üretilen özel anahtarı (§3.4) **`flutter_secure_storage`**
  ile saklanır (Android Keystore destekli). Uygulama her açılışta token'ı okur —
  **tekrar giriş yapılmaz.** Token süresi dolarsa sessizce yenilenir; olmazsa giriş
  ekranı bir kez daha gösterilir.
- Yanlış bilgi denemelerine karşı basit oran sınırlama (aynı cihazdan art arda
  deneme sayısı sınırı) — bu bir aile uygulaması, banka değil; ölçülü tutulur.

### 3.3 Bu modelin dürüst sınırları

Ad + soyad + doğum tarihi, "bilen girer" düzeyinde bir kimliktir; parola değildir.
Aile içi tehdit modeli için yeterli, çünkü APK zaten yalnızca aileye dağıtılıyor.
Yine de: APK herkese açık bir yere **yüklenmemeli** ve `PEPPER`/`PROFILE_KEY`
yalnızca sunucu tarafında kalmalı (APK içine gömülmez).

### 3.4 Görüşme gizliliği — sen dahil kimse izleyemez

- Her cihaz ilk girişte bir **X25519 anahtar çifti** üretir. Özel anahtar cihazda
  (`flutter_secure_storage`), açık anahtar kullanıcının Firestore profilinde durur.
- Arama başlarken iki taraf, karşılıklı açık anahtarlardan **ECDH + HKDF** ile aynı
  oda anahtarını türetir ve LiveKit'in **E2EE (uçtan uca şifreleme)** özelliğine verir.
- Sonuç: ses ve görüntü LiveKit sunucusundan **şifreli** geçer; ne LiveKit ne Vercel
  ne de veritabanına erişimi olan sen içeriği çözebilirsiniz. Oda anahtarı hiçbir
  sunucuya gönderilmez.
- Uygulamada arama kaydı özelliği **yok**; sunucu tarafında yalnızca "kim kimi ne
  zaman aradı" gibi minimum sinyal verisi oluşur (FCM push için zorunlu), içerik asla.
- İleride mesajlaşma eklenirse aynı ECDH anahtarıyla uçtan uca şifrelenir. (İlk
  sürümde mesajlaşma kapsam dışı — HopHop bir arama uygulaması olarak başlıyor.)

---

## 4. Veri modeli (Firestore)

```
users/{userId}
  credentialHash      // §3.1 — giriş eşleştirme
  encName, encSurname, encBirthDate   // AES-256-GCM şifreli
  photoBase64         // ~200×200 sıkıştırılmış JPEG (~20 KB) — Storage gerekmez*
  publicKey           // X25519 açık anahtar (E2EE için)
  fcmTokens: []       // cihaz push token'ları (çoklu cihaz desteklenir)
  createdAt

friendRequests/{requestId}
  fromUserId, toUserId, status: pending|accepted|rejected, createdAt

friendships/{pairId}   // pairId = sorted(userA, userB) birleşimi
  userIds: [a, b], since
```

\* Firebase Storage yeni projelerde ücretli plana geçmeyi gerektirebildiği için
profil fotoğrafları küçültülüp doğrudan Firestore belgesine base64 gömülür.
Ücretsiz, yeterli ve bir servis daha eksik.

Firestore'a istemciden doğrudan yazma **kapalı** (security rules); tüm yazmalar
Vercel API üzerinden, JWT doğrulamasıyla yapılır. Okumalar da API üzerinden —
böylece şifreli alanların çözümü ve "arkadaş olmayana profil detayı sızmasın"
kuralı tek yerde uygulanır.

---

## 5. Özellikler

### 5.1 Ana ekran — arkadaş kartları

- Giriş sonrası ana ekran: **arkadaş olunan profillerin kartları** (büyük fotoğraf,
  ad, doğum günü yaklaşıyorsa 🎂 rozeti).
- Her kartta iki büyük buton: **📞 Sesli ara** ve **📹 Görüntülü ara**.
- Üstte "Yaklaşan doğum günleri" şeridi: arkadaşların doğum tarihlerinden istemci
  tarafında hesaplanır (önümüzdeki 30 gün). Doğum günü **bugün** olan arkadaşın
  kartı süslenir (konfeti/balon animasyonu — çocuklar için hoş bir dokunuş).

### 5.2 Arkadaşlık sistemi

- **Kişiler** sekmesi: uygulamadaki tüm profiller listelenir (yalnızca ad-soyad +
  fotoğraf; arkadaş olmayanların doğum tarihi gösterilmez).
- Profil üzerinden **arkadaşlık isteği gönder**; karşı tarafa push bildirimi gider.
- **İstekler** sekmesi: gelen istekler (kabul / reddet) ve gönderilen bekleyenler
  (iptal edilebilir).
- Yalnızca **arkadaşlar birbirini arayabilir** — API katmanı `friendships`
  kaydı olmayan aramaları reddeder; kural yalnızca arayüzde değil sunucuda da uygulanır.
- Çocuk hesapları için ileride "istekleri veli onaylasın" katmanı eklenebilir
  (ilk sürümde yok; aile içi kullanımda gerek görülmedi).

### 5.3 Arama akışı

1. A, B'nin kartında "Görüntülü ara"ya basar → `/api/call` (JWT ile).
2. API arkadaşlığı doğrular, oda adı üretir (`pairId + zaman damgası`), B'nin tüm
   cihazlarına **FCM data mesajı** gönderir.
3. B'nin cihazında `flutter_local_notifications` ile **yüksek öncelikli, çalan,
   titreşen heads-up bildirim**: arayanın fotoğrafı + adı + **Cevapla / Reddet**.
   `Importance.max` + `fullScreenIntent: false` → ekstra sistem izni istemez.
4. Cevapla → iki taraf `/api/token`dan LiveKit token alır, ECDH ile oda anahtarını
   türetir, odaya **E2EE açık** şekilde katılır.
5. Reddet / 45 sn cevapsız → arayana "cevaplamadı" bilgisi, çalma durur
   (FCM ile "cancel" mesajı).
6. Video 720p'ye sabitlenir (kota, §7).

### 5.4 Görüşme içi yüz efektleri 🐰🐶

İki aşamalı yaklaşım — önce ücretsiz ve sürdürülebilir olan, gerekirse gösterişlisi:

**Aşama 1 (planlanan): ML Kit tabanlı overlay efektleri — ücretsiz, sınırsız kullanıcı**
- `google_mlkit_face_mesh_detection` (Google, cihaz üzerinde, ücretsiz) kameradaki
  yüzü ve 468 noktalı yüz ağını gerçek zamanlı izler; ağız açıklığı, göz konumu,
  kafa açısı landmark'lardan türetilir.
- Efekt çizimi (tavşan kulakları, köpek burnu + ağız açılınca sarkan dil, yüz
  genişletme/büyütme benzeri deformasyon) Flutter tarafında canvas/shader ile
  landmark'ları takip ederek yapılır.
- Efektin **karşı tarafta da görünmesi** için yüz landmark verisi (saniyede ~15-30
  küçük paket) LiveKit **data channel** üzerinden gönderilir; alıcı, gelen videonun
  üstüne aynı efekti çizer. Video karesine dokunulmadığı için E2EE bozulmaz,
  performans maliyeti düşük, LiveKit video-işleme boru hattıyla boğuşulmaz.
- Efekt seçici: görüşme ekranında alt şeritte 4-6 efekt (tavşan, köpek, büyük yüz,
  taç, gözlük, efekt yok). Çocukların kendi başına keşfedebileceği kadar basit.

**Aşama 2 (opsiyonel yükseltme): DeepAR**
- Snapchat kalitesinde hazır 3D maskeler sunar; ancak ücretsiz katmanı **10 aylık
  aktif kullanıcı + filigran** ile sınırlı (geniş aile bunu aşar), Flutter eklentisi
  topluluk bakımında ve LiveKit'in yayın öncesi kare işleme (VideoProcessor) desteği
  Flutter'da henüz olgunlaşıyor. Bu yüzden ilk sürüme alınmıyor; ML Kit yaklaşımı
  beğenilmezse ücretli katmanıyla değerlendirilecek B planı.

### 5.5 İzinler — uygulama içi pratik yönlendirme

"Hiç ayar yaptırmama" hedefi yerine **uygulamanın kendisi kullanıcıyı adım adım
yönlendirir**; hiçbir aile üyesinin kendi başına ayar menüsü araması gerekmez:

- **İlk açılış sihirbazı** (girişten hemen sonra, 3 kart):
  1. 🔔 Bildirim izni — "Seni arayanları duyabilmen için" → sistem diyaloğu tek dokunuşla.
  2. 📷 Kamera + 🎤 mikrofon — "Görüntülü konuşabilmek için" → iki sistem diyaloğu.
  3. 🔋 (Yalnızca gerekliyse) Pil optimizasyonu muafiyeti — agresif OEM'lerde
     (Xiaomi/Oppo/Vivo tespiti yapılır) tek dokunuşla ilgili ayar ekranına götüren
     buton + ekran görüntülü kısa anlatım. Diğer cihazlarda bu kart hiç gösterilmez.
- **Ayarlar → İzin durumu** ekranı: her iznin ✅/❌ durumu; eksik olanın yanında
  "Düzelt" butonu (sistem diyaloğunu açar ya da doğru ayar sayfasına derin bağlantı).
- Arama sırasında izin eksikse (ör. kamera reddedilmiş) sessizce bozulmak yerine
  açıklayıcı ekran + "Düzelt" butonu.
- Kalıcılık için `flutter_foreground_task` ile hafif bir ön plan servisi: uygulama
  arka plandayken de FCM'in güvenilir teslimini destekler; Doze'dan muaftır.

### 5.6 Profil ekranı

- Kendi profili: fotoğraf çek/galeriden seç (istemcide kırpılıp sıkıştırılır),
  ad-soyad ve doğum tarihi **salt okunur** (kimlik, yönetici kaydıyla sabit).
- Arkadaş profili: fotoğraf, ad, doğum günü + doğum gününe kalan gün.

---

## 6. Ücretsiz servisler ve aile ölçeğinde kota hesabı

| Servis | Plan | Sınır | Aile ölçeğinde değerlendirme |
|---|---|---|---|
| **LiveKit Cloud** | Build ($0) | 5.000 katılımcı-dk/ay, 50 GB | Aşağıda — tek dar boğaz bu |
| **FCM** | Spark ($0) | Pratikte sınırsız | Sorunsuz |
| **Vercel** | Hobby ($0) | Kişisel kullanım | Sorunsuz |
| **Firestore** | Spark ($0) | 50k okuma/gün, 1 GB | ~30 kullanıcı + fotoğraflar için bol bol yeter |
| **ML Kit (yüz izleme)** | $0 | Cihaz üzerinde, sınırsız | Sorunsuz |

**LiveKit hesabı (dikkat — kota artık tüm ailenin ortak havuzu):**
2 kişilik 30 dk görüşme = 60 katılımcı-dk. 5.000 dk/ay ≈ ayda **~41 saat** ikili
görüşme. Aile genelinde günde toplam ~1 saat 20 dk görüşmeye denk gelir. Başlangıç
için yeterli; aile uygulamayı severse ilk aşılacak sınır budur. O gün geldiğinde:
LiveKit ücretli katman (kullandıkça öde) ya da kendi sunucunda LiveKit OSS
(tamamen ücretsiz, bir VPS ister). Plan B hazır, panik yok. Dashboard'a ayda bir bakılır.

**Veri transferi:** 720p ~1,5 Mbps → saatte ~700 MB; ayda 41 saat ≈ 28 GB < 50 GB.
Çözünürlük kodda 720p'ye sabitlenir.

---

## 7. Flutter paketleri

```yaml
dependencies:
  livekit_client: ^2.x                 # LiveKit resmi SDK — E2EE desteğiyle
  firebase_core: ^3.x
  firebase_messaging: ^15.x            # FCM
  cloud_firestore: ^5.x                # (yalnızca gerekirse; esas erişim API üzerinden)
  flutter_local_notifications: ^18.x   # heads-up gelen arama bildirimi
  flutter_foreground_task: ^8.x        # arka plan dayanıklılığı
  flutter_secure_storage: ^9.x         # oturum JWT + E2EE özel anahtarı
  permission_handler: ^11.x            # izin sihirbazı + izin durumu ekranı
  cryptography: ^2.x                   # X25519 ECDH + HKDF (oda anahtarı)
  google_mlkit_face_mesh_detection: ^0.x  # yüz ağı — efekt motoru
  image_picker: ^1.x                   # profil fotoğrafı
  flutter_image_compress: ^2.x         # fotoğrafı ~20 KB'a sıkıştırma
  audioplayers: ^6.x                   # zil sesi
  device_info_plus: ^10.x              # OEM tespiti (pil optimizasyonu kartı için)
```

Backend (Vercel, Node.js/TypeScript): `firebase-admin`, `livekit-server-sdk`,
`jose` (JWT), Node `crypto` (SHA-256, AES-256-GCM). Yönetici betiği aynı repoda
küçük bir CLI.

`flutter_callkit_incoming` kullanılmıyor: asıl değeri olan tam ekran kilit ekranı
arayüzü Android 14+'ta ek izin istiyor; `Importance.max` heads-up bildirim izinsiz
aynı işi görüyor.

---

## 8. Yol haritası

### Aşama 0 — Hesaplar ve iskelet (yarım gün)
- LiveKit Cloud, Firebase (FCM + Firestore), Vercel projeleri; anahtarlar ortam değişkenlerine
- Flutter projesi `hophop`, temel navigasyon (Ana ekran / Kişiler / İstekler / Ayarlar)
- Vercel API iskeleti + Firestore bağlantısı

### Aşama 1 — Kimlik ve profiller (1 gün)
- Yönetici CLI: kullanıcı ekleme (hash + AES şifreli alanlar)
- `/api/login`, JWT üretimi; uygulamada giriş ekranı + `flutter_secure_storage` ile kalıcı oturum
- X25519 anahtar üretimi, açık anahtarın profile yazılması
- Profil ekranı + fotoğraf yükleme; ilk açılış izin sihirbazı (§5.5)

### Aşama 2 — Arkadaşlık sistemi (1 gün)
- Kişiler listesi, istek gönderme/kabul/red, bekleyenler
- İstek push bildirimleri
- Ana ekran arkadaş kartları + yaklaşan doğum günleri şeridi

### Aşama 3 — Sesli/görüntülü arama (1,5 gün)
- `/api/call` + `/api/token`; FCM data mesajı; çalan heads-up bildirim (Cevapla/Reddet)
- LiveKit odasına E2EE ile katılım (ECDH oda anahtarı), sesli ve görüntülü modlar
- Cevapsız/meşgul/iptal durumları; 720p sabitleme

### Aşama 4 — Dayanıklılık (yarım gün)
- `flutter_foreground_task`; ağ değişiminde yeniden bağlanma (LiveKit SDK büyük ölçüde halleder)
- Ayarlar → İzin durumu ekranı; OEM pil optimizasyonu yönlendirmesi
- Çoklu cihaz FCM token yönetimi (eski token temizliği)

### Aşama 5 — Yüz efektleri (1,5-2 gün)
- ML Kit yüz ağı entegrasyonu; landmark → efekt çizim motoru (canvas)
- İlk efekt seti: tavşan kulakları, köpek (ağız açılınca dil), büyük yüz, taç, gözlük
- Landmark verisinin data channel ile karşı tarafa taşınması + alıcıda çizim
- Efekt seçici arayüzü

### Aşama 6 — Dağıtım (yarım gün)
- `flutter build apk --release`, imzalama
- Aile üyelerini CLI ile kaydet, APK'yı dağıt (doğrudan gönderim; herkese açık link yok)
- Her cihazda ilk giriş + sihirbaz + test araması

**Toplam: ~6-7 günlük odaklı iş.** En riskli iki kalem: FCM bildirim güvenilirliği
(OEM çeşitliliği) ve efekt motorunun performansı — ikisi de kendi aşamasında ayrı test edilir.

---

## 9. Kabul kriterleri

- [ ] Kayıtlı ad-soyad-doğum tarihi ile giriş yapılıyor; uygulama silinip yeniden açılmadıkça bir daha giriş istenmiyor
- [ ] Yanlış bilgiyle giriş yapılamıyor
- [ ] Firestore'da hiçbir kimlik bilgisi düz metin durmuyor (hash + AES şifreli alanlar)
- [ ] Arkadaş olmayan iki kullanıcı birbirini arayamıyor (API katmanında engelli)
- [ ] İstek gönder → kabul et → kart ana ekranda beliriyor akışı çalışıyor
- [ ] Tablet kilitliyken arama geldiğinde çalan heads-up bildirim beliriyor; Cevapla → 5 sn içinde görüntü
- [ ] Görüşme E2EE ile kuruluyor (LiveKit dashboard'dan medya içeriğine erişilemediği doğrulanır)
- [ ] İzin sihirbazı dışında hiçbir sistem menüsüne elle girilmesi gerekmiyor; eksik izin "Düzelt" ile tamamlanabiliyor
- [ ] Tavşan/köpek efekti hem kendi önizlemende hem karşı tarafta yüzü takip ediyor; ağız açılınca köpek dili çıkıyor
- [ ] Yaklaşan doğum günleri doğru listeleniyor; doğum günü olan kartta kutlama görseli
- [ ] WiFi ↔ mobil veri geçişinde görüşme kopmuyor
- [ ] Uygulama 3 gün arka planda bekledikten sonra da arama alıyor

---

## 10. Bilinen riskler

| Risk | Etki | Azaltma |
|---|---|---|
| Agresif OEM (Xiaomi/Oppo/Vivo) arka plan servisini öldürür | Arama bildirimi gecikir/gelmez | OEM tespiti + izin sihirbazındaki pil optimizasyonu kartı; sorun yaşayan cihazda Ayarlar → İzin durumu ekranından tek dokunuş yönlendirme |
| LiveKit ortak kotası (5.000 dk/ay) aile genelinde aşılır | Ay sonunda görüşme kesilir | Ayda bir dashboard kontrolü; aşılırsa ücretli katman ya da self-host LiveKit (plan hazır, §6) |
| ML Kit yüz ağı düşük donanımlı tabletlerde yavaş kalır | Efektler takılır | Efekt kapalıyken sıfır maliyet; landmark sıklığı düşürülebilir; olmadı DeepAR ücretli katmanı (B planı) |
| DeepAR'a geçilirse 10 MAU ücretsiz sınırı | Efekt maliyeti doğar | İlk sürüm zaten ML Kit ile; DeepAR yalnızca bilinçli bir yükseltme kararı olarak gündeme gelir |
| APK'nın aile dışına sızması | Yabancı biri kayıtlı bir kimliği tahmin etmeye çalışabilir | APK yalnızca doğrudan paylaşım; girişte oran sınırlama; kimlik bilgisi zaten sadece ailece biliniyor |
| Cihaz kaybı/sıfırlanması | O cihazdaki E2EE özel anahtarı gider | Yeni girişte yeni anahtar çifti üretilir, profildeki açık anahtar güncellenir — görüşmeler kalıcı veri içermediği için kayıp yok |
