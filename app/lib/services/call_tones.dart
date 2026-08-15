import 'package:audioplayers/audioplayers.dart';

/// Görüşmenin sesli geri bildirimi: aranıyor / bağlandı / kapandı.
///
/// NEDEN: arayan taraf kırmızı düğmeye basana kadar hiçbir ses duymuyordu.
/// Ekranda "Aranıyor…" yazması yetmiyor — telefonun karşı tarafta çaldığını
/// insan KULAĞIYLA anlıyor. Aynı şekilde görüşmenin kurulduğu ve kapandığı da
/// kısa birer tonla duyuluyor; sessizce kesilen bir görüşme "kapattı mı, ağ mı
/// gitti?" diye düşündürüyordu.
///
/// Sesler `tools/make_call_tones.py` ile üretiliyor (425 Hz — Türkiye'nin
/// santral zil geri dönüş tonu).
class CallTones {
  /// Döngüdeki zil geri dönüş tonu ile kısa tonlar ayrı çalıcılarda: geri
  /// dönüşü durdurmak "bağlandı" tonunu kesmesin.
  static final _ringback = AudioPlayer();
  static final _blip = AudioPlayer();
  static bool _ringing = false;

  /// Aranıyor tonu ses akışında "görüşme sinyali" olarak işaretlenir; sistem
  /// bunu görüşme sesiyle aynı yoldan verir (meşgul tonu, DTMF ile aynı sınıf).
  static final _signalling = AudioContext(
    android: AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.voiceCommunicationSignalling,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
  );

  /// Bağlandı/kapandı tonları arayüz sesi sınıfında: görüşme bitmiş olsa da
  /// (ses kipi normale dönmüşken) duyulmaları gerekiyor.
  static final _uiSound = AudioContext(
    android: AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.assistanceSonification,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
  );

  /// Karşı taraf çalarken döner. Kabul/red/zaman aşımında [stopRingback].
  static Future<void> startRingback() async {
    if (_ringing) return;
    _ringing = true;
    try {
      await _ringback.setAudioContext(_signalling);
      await _ringback.setReleaseMode(ReleaseMode.loop);
      await _ringback.play(AssetSource('sounds/ringback.wav'));
    } catch (_) {/* ses yoksa arama akışı etkilenmez */}
  }

  static Future<void> stopRingback() async {
    if (!_ringing) return;
    _ringing = false;
    try {
      await _ringback.stop();
    } catch (_) {}
  }

  static Future<void> connected() => _play('sounds/connect.wav');

  static Future<void> ended() => _play('sounds/end.wav');

  static Future<void> _play(String asset) async {
    try {
      await _blip.setAudioContext(_uiSound);
      await _blip.setReleaseMode(ReleaseMode.stop);
      await _blip.play(AssetSource(asset));
    } catch (_) {}
  }
}
