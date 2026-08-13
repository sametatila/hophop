import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Uygulama İÇİ zil: gelen arama ekranı görünürken bildirim şeridi yerine
/// uygulamanın kendisi çalar (WhatsApp davranışı).
class RingtonePlayer {
  static final _player = AudioPlayer();
  static bool _ringing = false;

  static Future<void> start() async {
    if (_ringing) return;
    _ringing = true;
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('sounds/ringtone.wav'));
      HapticFeedback.vibrate();
    } catch (_) {}
  }

  static Future<void> stop() async {
    if (!_ringing) return;
    _ringing = false;
    try {
      await _player.stop();
    } catch (_) {}
  }
}
