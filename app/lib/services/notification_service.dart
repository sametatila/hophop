import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'auth_service.dart';

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
    // Durum çubuğu ikonu tek renkli olmalı — renkli logo gri kare görünür.
    // İkon release'de kaynak küçültücüye yem olursa (res/raw/keep.xml onu
    // korur) uygulamayı hiç açılmaz hâle getirmek yerine uygulama ikonuna
    // düşülür: renkli bir bildirim, bildirimsiz bir arama uygulamasından iyidir.
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_stat_hophop'),
        ),
        onDidReceiveNotificationResponse: onResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
    } on PlatformException catch (e) {
      if (e.code != 'invalid_icon') rethrow;
      debugPrint('⚠ ic_stat_hophop bulunamadı — uygulama ikonuna düşülüyor');
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: onResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
    }
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
      // Kilitli/kapalı ekranda arama ekranı DOĞRUDAN açılır (WhatsApp gibi).
      // Mağaza dışı kurulumda izin varsayılan verilidir; reddedilmişse
      // Ayarlar'daki "Tam ekran arama" kartı yönlendirir.
      fullScreenIntent: true,
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
      id: callNotificationId,
      title: call.video ? '📹 ${call.callerName}' : '📞 ${call.callerName}',
      body: call.video ? 'Görüntülü arıyor…' : 'Sesli arıyor…',
      notificationDetails: NotificationDetails(android: android),
      payload: jsonEncode(call.toData()),
    );
  }

  static Future<void> cancelIncomingCall() =>
      _plugin.cancel(id: callNotificationId);

  /// [payload] örn. `chat:friendId` — dokununca ilgili ekrana gidilir.
  static Future<void> showGeneral(int id, String title, String body,
      {String? payload}) async {
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          generalChannel.id,
          generalChannel.name,
          channelDescription: generalChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: payload,
    );
  }
}

/// Arka planda (uygulama kapalıyken) bildirim aksiyonu işleyici.
/// "Cevapla" showsUserInterface ile uygulamayı açar (main.dart yürütür);
/// "Reddet" burada GERÇEK red gönderir — arayan 45 sn beklemez.
@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  if (response.actionId != 'reject') return;
  final payload = response.payload;
  if (payload == null || payload.isEmpty) return;
  try {
    final call = IncomingCall.fromData(
        Map<String, dynamic>.from(jsonDecode(payload) as Map));
    final token = await AuthService.readToken();
    if (token == null) return;
    api.setToken(token);
    await api.respondCall(call.roomName, call.callerId, false, call.video);
  } catch (_) {/* çevrimdışı — arayan zaman aşımıyla düşer */}
}
