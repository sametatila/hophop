import 'activity_store.dart';
import 'api_client.dart';
import 'crypto_service.dart';
import 'fcm_service.dart';
import 'foreground_service.dart';

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
  try {
    await ForegroundService.start();
  } catch (_) {}
}
