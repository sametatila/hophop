import 'dart:io';

import 'package:flutter/services.dart';

/// Görüşme ekranının kilit ekranının ÜSTÜNDE açılması (WhatsApp davranışı).
///
/// SORUN NEYDİ: gelen arama bildirimi `fullScreenIntent` ile geliyordu ama
/// MainActivity kilit ekranının üstünde görünme yetkisine sahip olmadığı için
/// pencere keyguard'ın ARKASINA açılıyordu. Kullanıcıya geriye yalnızca titreşen
/// bir bildirim kalıyordu — "tam ekran arama" izni açık olsa bile.
///
/// NEDEN AÇ/KAPA: yetki manifestte kalıcı verilseydi, kullanıcı uygulama açıkken
/// telefonu kilitlediğinde sohbetler kilit ekranında görünürdü. Bu yüzden
/// yalnızca arama boyunca açılıyor.
///
/// Not: bildirimden doğan soğuk açılışta bayrağı MainActivity kendisi
/// onCreate'te veriyor (Flutter'ın açılmasını beklemek geç kalıyor); buradaki
/// çağrılar uygulama zaten çalışırken gelen aramalar ve kapatma içindir.
class LockScreen {
  static const _native = MethodChannel('hophop/updater');

  static Future<void> _set(bool on) async {
    if (!Platform.isAndroid) return;
    try {
      await _native.invokeMethod('lockScreenCall', {'on': on});
    } catch (_) {}
  }

  /// Arama çalmaya başladı ya da görüşme sürüyor.
  static Future<void> enable() => _set(true);

  /// Görüşme bitti / arama düştü.
  static Future<void> disable() => _set(false);
}
