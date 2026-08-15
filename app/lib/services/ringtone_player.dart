import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Uygulama İÇİ zil: gelen arama ekranı görünürken bildirim şeridi yerine
/// uygulamanın kendisi çalar (WhatsApp davranışı).
///
/// TELEFONUN ZİL KİPİNE UYAR. Bunu sistem bizim yerimize yapmıyor: çalan şey
/// bir bildirim değil, uygulamanın kendi çaldığı bir ses dosyası. Eskiden
/// medya akışında çalıyor ve tek bir kısa titreşim veriyordu; sonuç olarak
/// telefon titreşimdeyken arama SESSİZ geliyordu.
///
///   normal   → ses + titreşim
///   vibrate  → yalnız titreşim
///   silent   → ikisi de yok (ekran yine de açılır)
class RingtonePlayer {
  /// Zil kipi ve titreşim için yerel köprü (MainActivity).
  static const _native = MethodChannel('hophop/updater');

  static final _player = AudioPlayer();
  static bool _ringing = false;

  static Future<String> _ringerMode() async {
    try {
      return await _native.invokeMethod<String>('ringerMode') ?? 'normal';
    } catch (_) {
      return 'normal';
    }
  }

  static Future<void> start() async {
    if (_ringing) return;
    _ringing = true;
    final mode = await _ringerMode();
    if (mode == 'silent') return;

    if (mode == 'normal') {
      try {
        // Zil akışı: sesin yüksekliğini kullanıcının ZİL ayarı belirlesin,
        // medya ayarı değil. mayDuck: çalan müzik susmak yerine kısılır.
        await _player.setAudioContext(AudioContext(
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.notificationRingtone,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ));
        await _player.setReleaseMode(ReleaseMode.loop);
        await _player.play(AssetSource('sounds/ringtone.wav'));
      } catch (_) {/* ses çalınamadı — titreşim yine de devrede */}
    }

    try {
      await _native.invokeMethod('vibrateRing');
    } catch (_) {}
  }

  static Future<void> stop() async {
    if (!_ringing) return;
    _ringing = false;
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await _native.invokeMethod('vibrateStop');
    } catch (_) {}
  }
}
