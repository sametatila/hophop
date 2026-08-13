import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'notification_service.dart';

/// FCM data mesajlarının yönlendirilmesi.
///
/// Arama sinyalleşmesi tamamen data-only mesajlarla yapılır; bildirim çizimini
/// her zaman biz yaparız (notification payload kullanılmaz) — böylece zil sesi,
/// aksiyon butonları ve zaman aşımı bizim kontrolümüzde kalır.
class FcmService {
  static final _messaging = FirebaseMessaging.instance;

  /// Uygulama açıkken gelen arama olayları buradan akar (CallManager dinler).
  static final callEvents = StreamController<RemoteMessage>.broadcast();

  static Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_handleForeground);
  }

  /// Girişten sonra: cihaz token'ını sunucuya kaydet, yenilenmeleri izle.
  static Future<void> registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await api.updateMe(addFcmToken: token);
      }
      _messaging.onTokenRefresh.listen((t) async {
        try {
          await api.updateMe(addFcmToken: t);
        } catch (_) {}
      });
    } catch (_) {/* Firebase yoksa/çevrimdışıysa sonraki açılışta denenir */}
  }

  static Future<void> _handleForeground(RemoteMessage message) async {
    final type = message.data['type'];
    switch (type) {
      case 'incoming_call':
      case 'call_cancelled':
      case 'call_rejected':
      case 'call_accepted':
        callEvents.add(message);
        // Uygulama ön plandayken gelen arama da bildirim gösterir — kullanıcı
        // başka ekrandaysa gözden kaçmasın. CallManager ayrıca ekran açar.
        if (type == 'incoming_call') {
          await NotificationService.showIncomingCall(
              IncomingCall.fromData(message.data));
        } else {
          await NotificationService.cancelIncomingCall();
        }
      case 'friend_request':
        await NotificationService.showGeneral(
          2001,
          'Arkadaşlık isteği 👋',
          '${message.data['fromName']} seninle arkadaş olmak istiyor',
        );
      case 'request_accepted':
        await NotificationService.showGeneral(
          2002,
          'İstek kabul edildi 🎉',
          '${message.data['byName']} artık arkadaşın — arayabilirsin!',
        );
    }
  }
}

/// Uygulama arka planda/kapalıyken FCM data mesajı işleyici (ayrı isolate).
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Ayrı isolate: bildirim eklentisini burada da başlatmak gerekir.
  await NotificationService.init(onResponse: (_) {});
  switch (message.data['type']) {
    case 'incoming_call':
      await NotificationService.showIncomingCall(
          IncomingCall.fromData(message.data));
    case 'call_cancelled':
      await NotificationService.cancelIncomingCall();
    case 'friend_request':
      await NotificationService.showGeneral(
        2001,
        'Arkadaşlık isteği 👋',
        '${message.data['fromName']} seninle arkadaş olmak istiyor',
      );
    case 'request_accepted':
      await NotificationService.showGeneral(
        2002,
        'İstek kabul edildi 🎉',
        '${message.data['byName']} artık arkadaşın — arayabilirsin!',
      );
  }
}
