import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Küçük pencere (Android Picture-in-Picture).
///
/// Görüşme sürerken geri tuşuna basmak, küçült düğmesine dokunmak ya da
/// uygulamayı arka plana almak görüşmeyi bitirmez: ekran WhatsApp'taki gibi
/// köşede sürüklenebilir küçük bir pencereye döner.
///
/// Sistem kipi kendi de değiştirebildiği için (kullanıcı pencereyi büyütünce,
/// başka uygulama tam ekran açılınca) durum tek yönlü değil — native taraf
/// [inPip] üzerinden geri haber verir.
class PipService {
  static const _channel = MethodChannel('hophop/pip');

  /// Şu an küçük pencerede miyiz? Arama ekranı buna göre sade düzene geçer.
  static final inPip = ValueNotifier<bool>(false);

  static bool _wired = false;
  static bool _supported = false;

  static void _wire() {
    if (_wired) return;
    _wired = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') {
        inPip.value = call.arguments == true;
      }
      return null;
    });
  }

  /// Cihaz destekliyor mu (Android 8+ ve özellik açık)? Desteklemiyorsa
  /// küçült düğmesi hiç gösterilmez.
  static Future<bool> isSupported() async {
    if (!Platform.isAndroid) return false;
    _wire();
    try {
      return _supported = await _channel.invokeMethod<bool>('isSupported') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Görüşme başlarken açılır, biterken kapanır. Yalnızca açıkken ev tuşu
  /// küçük pencereye geçirir — ana ekranda uygulama küçülmez.
  static Future<void> setEligible(bool on) async {
    if (!Platform.isAndroid) return;
    _wire();
    try {
      await _channel.invokeMethod('setEligible', {'on': on});
    } catch (_) {}
  }

  /// Küçük pencereye geç. [w]/[h] en-boy oranı: görüntülüde 16:9, seslide 1:1.
  static Future<bool> enter({int w = 16, int h = 9}) async {
    if (!Platform.isAndroid) return false;
    _wire();
    try {
      return await _channel.invokeMethod<bool>('enter', {'w': w, 'h': h}) ?? false;
    } catch (_) {
      return false;
    }
  }

  static bool get supported => _supported;
}
