import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// İzin durumu + pratik yönlendirme mantığı.
class PermissionService {
  /// Tam ekran arama izninin durumunu okumak için (MainActivity'deki köprü).
  /// permission_handler bu izni tanımıyor, flutter_local_notifications ise
  /// yalnızca "iste" diyebiliyor — sormak için ayrı bir yol gerekiyor.
  static const _native = MethodChannel('hophop/updater');

  /// Kilitli ekranda arama ekranının doğrudan açılması (USE_FULL_SCREEN_INTENT)
  /// izni verilmiş mi? Android 14 öncesinde kurulumda verilir → hep true.
  static Future<bool> canUseFullScreenIntent() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _native.invokeMethod<bool>('canFullScreenIntent') ?? true;
    } catch (_) {
      // Eski bir APK'nın üzerine yeni Dart kodu koşulursa (hot reload) metot
      // yok sayılır; kullanıcıya gereksiz "kapalı" uyarısı gösterme.
      return true;
    }
  }

  /// Agresif pil yönetimi yapan üreticiler — yalnızca bunlarda pil kartı gösterilir.
  static const _aggressiveOems = [
    'xiaomi', 'redmi', 'poco', 'oppo', 'vivo', 'realme', 'oneplus', 'huawei', 'honor', 'meizu',
  ];

  static Future<bool> isAggressiveOem() async {
    if (!Platform.isAndroid) return false;
    final info = await DeviceInfoPlugin().androidInfo;
    final m = info.manufacturer.toLowerCase();
    return _aggressiveOems.any(m.contains);
  }

  static Future<Map<Permission, PermissionStatus>> statuses() async {
    return {
      Permission.notification: await Permission.notification.status,
      Permission.camera: await Permission.camera.status,
      Permission.microphone: await Permission.microphone.status,
      Permission.ignoreBatteryOptimizations:
          await Permission.ignoreBatteryOptimizations.status,
    };
  }

  /// Tek dokunuş "Düzelt": izni ister; kalıcı reddedilmişse uygulama ayarlarını açar.
  static Future<void> fix(Permission permission) async {
    final status = await permission.request();
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
  }
}
