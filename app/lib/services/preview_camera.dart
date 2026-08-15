import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

/// Arama kurulmadan ÖNCE kendi kameranı gösteren önizleme (WhatsApp davranışı).
///
/// Görüntülü ararken ve görüntülü arama gelirken kişi kendini görür; "kamera
/// açık mı, saçım nasıl?" sorusu görüşme başlamadan cevaplanır. Eskiden bu
/// ekranlarda yalnızca avatar ve degrade vardı.
///
/// TEK KAMERA KURALI: Android'de kamerayı aynı anda iki oturum açamaz. Bu
/// yüzden odaya bağlanmadan hemen önce [stop] çağrılır ([CallManager._joinRoom]);
/// yoksa LiveKit kamerayı açamaz ve görüntü hiç gelmez.
class PreviewCamera {
  /// Ekranlar bunu dinler; null → gösterilecek görüntü yok.
  static final track = ValueNotifier<LocalVideoTrack?>(null);

  static bool _busy = false;

  static Future<void> start() async {
    if (track.value != null || _busy) return;
    _busy = true;
    try {
      // Ön kamera: kendine bakıyorsun.
      track.value = await LocalVideoTrack.createCameraTrack(
        const CameraCaptureOptions(cameraPosition: CameraPosition.front),
      );
    } catch (_) {
      // İzin yok, kamera meşgul ya da uygulama arka planda (Android 9+ arka
      // planda kamerayı engelliyor) — önizleme olmadan devam edilir.
      track.value = null;
    } finally {
      _busy = false;
    }
  }

  static Future<void> stop() async {
    final t = track.value;
    if (t == null) return;
    track.value = null;
    try {
      await t.stop();
      await t.dispose();
      // Kamera donanımı hemen serbest kalmıyor; LiveKit'in onu açması bu
      // beklemeden hemen sonra gelirse (özellikle MIUI'de) hata veriyordu.
      await Future<void>.delayed(const Duration(milliseconds: 150));
    } catch (_) {}
  }
}
