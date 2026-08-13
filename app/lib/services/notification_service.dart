import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config.dart';
import '../models/models.dart';

/// Gelen arama bildirimi — işin kalbi.
///
/// Importance.max + fullScreenIntent kullanılmadan, ekranın üstünde beliren,
/// zil sesi çalan, Cevapla/Reddet butonlu heads-up bildirim. Android 14+ dahil
/// hiçbir ek sistem izni gerektirmez (yalnızca Android 13+ bildirim izni diyaloğu).
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const callChannel = AndroidNotificationChannel(
    'incoming_call',
    'Gelen Aramalar',
    description: 'HopHop gelen arama zili',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('ringtone'),
    enableVibration: true,
  );

  static const generalChannel = AndroidNotificationChannel(
    'general',
    'Bildirimler',
    description: 'Arkadaşlık istekleri ve diğer bildirimler',
    importance: Importance.high,
  );

  static const int callNotificationId = 1001;

  /// Bildirime dokunma/aksiyon geri çağrıları main.dart'ta bağlanır.
  static Future<void> init({
    required void Function(NotificationResponse) onResponse,
  }) async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: onResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(callChannel);
    await android?.createNotificationChannel(generalChannel);
  }

  /// Uygulama bildirimden mi açıldı? (öldürülmüş durumdan Cevapla ile açılış)
  static Future<NotificationResponse?> launchDetails() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp == true) {
      return details!.notificationResponse;
    }
    return null;
  }

  static Future<void> showIncomingCall(IncomingCall call) async {
    final android = AndroidNotificationDetails(
      callChannel.id,
      callChannel.name,
      channelDescription: callChannel.description,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: false, // bilinçli: Android 14+ izin istemesin
      ongoing: true,
      autoCancel: false,
      timeoutAfter: ringTimeout.inMilliseconds,
      sound: callChannel.sound,
      playSound: true,
      enableVibration: true,
      actions: const [
        AndroidNotificationAction(
          'answer',
          '✅ Cevapla',
          showsUserInterface: true, // uygulamayı açar
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'reject',
          '❌ Reddet',
          cancelNotification: true,
        ),
      ],
    );
    await _plugin.show(
      callNotificationId,
      call.video ? '📹 ${call.callerName}' : '📞 ${call.callerName}',
      call.video ? 'Görüntülü arıyor…' : 'Sesli arıyor…',
      NotificationDetails(android: android),
      payload: jsonEncode(call.toData()),
    );
  }

  static Future<void> cancelIncomingCall() => _plugin.cancel(callNotificationId);

  static Future<void> showGeneral(int id, String title, String body) async {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          generalChannel.id,
          generalChannel.name,
          channelDescription: generalChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}

/// Arka planda (uygulama kapalıyken) bildirim aksiyonu işleyici.
/// "Reddet" burada ele alınır; "Cevapla" showsUserInterface ile uygulamayı açar
/// ve main.dart'taki onResponse üzerinden yürür.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // Reddet: sessizce yut — arayan taraf 45 sn zaman aşımıyla düşer.
  // (Arka plan isolate'inde API çağrısı için oturum açmak gerekir; reddin
  // anında iletilmesi uygulama açıkken zaten yapılıyor.)
}
