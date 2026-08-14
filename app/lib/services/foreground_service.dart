import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Sessiz, minimum önemde kalıcı bildirimle süreci ayakta tutar.
///
/// NE İŞE YARAR: süreç canlı kaldıkça gerçek-zamanlı zil dinleyicisi bağlı
/// kalır ve uygulama sistem tarafından öldürülmez.
///
/// NEDEN HER CİHAZDA VARSAYILAN KAPALI: yüksek öncelikli FCM mesajı, uygulama
/// kapalıyken de cihazı uyandırıp arama bildirimini gösterebiliyor — yani
/// servis olmadan da aramalar geliyor. Karşılığında bildirim gölgesinde hiç
/// kaybolmayan kalıcı bir satır duruyor; bunu kullanıcıya sormadan açmak
/// (Xiaomi/Oppo gibi agresif markalarda bile) doğru değil. Aramalar geç gelen
/// kullanıcı Ayarlar'dan kendisi açar; agresif markalarda ayardaki açıklama
/// açmayı önerir.
class ForegroundService {
  static const _prefKey = 'hophop_background_service';

  static const _storage = FlutterSecureStorage();

  /// Kullanıcı tercihi; hiç dokunulmamışsa kapalı.
  static Future<bool> isEnabled() async {
    final saved = await _storage.read(key: _prefKey);
    return saved == '1';
  }

  static Future<void> setEnabled(bool enabled) async {
    await _storage.write(key: _prefKey, value: enabled ? '1' : '0');
    if (enabled) {
      await start();
    } else {
      await stop();
    }
  }

  static Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  /// Tercih kapalıysa hiçbir şey yapmaz (kalıcı bildirim çıkmaz).
  static Future<void> startIfEnabled() async {
    if (await isEnabled()) await start();
  }

  static Future<void> start() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'hophop_service',
        channelName: 'HopHop arka plan',
        channelDescription: 'Aramaların gelmesi için sessizce çalışır',
        channelImportance: NotificationChannelImportance.MIN,
        priority: NotificationPriority.MIN,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
      ),
    );
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      notificationTitle: 'HopHop',
      notificationText: 'Aramaları kaçırmamak için arka planda',
      callback: _startCallback,
    );
  }
}

@pragma('vm:entry-point')
void _startCallback() {
  FlutterForegroundTask.setTaskHandler(_IdleHandler());
}

class _IdleHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
