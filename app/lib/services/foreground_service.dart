import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Sessiz, minimum önemde kalıcı bildirimle uygulamayı ayakta tutar.
/// FCM zaten uygulama kapalıyken de çalışır; bu servis agresif OEM'lerde
/// (Xiaomi/Oppo/Vivo…) sürecin öldürülme olasılığını azaltan ek sigortadır.
class ForegroundService {
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
      notificationTitle: 'HopHop hazır 🐇',
      notificationText: 'Seni arayanlar için bekliyor',
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
