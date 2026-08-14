import 'activity_store.dart';
import 'api_client.dart';
import 'call_manager.dart';
import 'crypto_service.dart';
import 'fcm_service.dart';
import 'foreground_service.dart';
import 'ring_listener.dart';

/// Oturum hazır olduğunda (açılışta ya da yeni girişte) çalışır:
/// E2EE açık anahtarı ve FCM token'ı sunucuya yazar, ön plan servisini başlatır.
/// Idempotent — birden çok çağrılması sorun değildir.
Future<void> postLoginSetup() async {
  try {
    final publicKey = await crypto.ensureKeyPair();
    await api.updateMe(publicKey: publicKey);
  } catch (_) {/* çevrimdışı — sonraki açılışta tekrar denenir */}
  await FcmService.registerToken();
  ActivityStore.init(); // rozetler: okunmamış + cevapsız (arka planda tazelenir)
  RingListener.start(); // gerçek-zamanlı yedek zil yolu (FCM'den bağımsız)
  CallManager.checkPendingRing(); // soğuk açılışta bekleyen arama varsa çaldır
  try {
    // Yalnızca kullanıcı Ayarlar'dan açtıysa — varsayılanda kalıcı bildirim çıkmaz.
    await ForegroundService.startIfEnabled();
  } catch (_) {}
}
