import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// İzin durumu + pratik yönlendirme mantığı.
class PermissionService {
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
