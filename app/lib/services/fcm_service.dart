import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/models.dart';
import 'activity_store.dart';
import 'api_client.dart';
import 'auth_service.dart';
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

  /// Gelen mesaj olayları (açık ChatScreen anında güncellenir).
  static final messageEvents = StreamController<RemoteMessage>.broadcast();

  /// "Yazıyor…" olayları (yalnızca uygulama açıkken anlamlı).
  static final typingEvents = StreamController<RemoteMessage>.broadcast();

  /// Mesaj cihaza ulaştı → sunucuda "iletildi" damgası (✓✓) bassın diye
  /// alıcı taraf sessizce listeyi çeker. Gönderen bir sonraki tazelemede görür.
  static Future<void> ackDelivery(String fromUserId) async {
    try {
      await api.listMessages(fromUserId);
    } catch (_) {}
  }

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
          'Arkadaşlık isteği',
          '${message.data['fromName']} seninle arkadaş olmak istiyor',
        );
      case 'request_accepted':
        await NotificationService.showGeneral(
          2002,
          'İstek kabul edildi',
          '${message.data['byName']} artık arkadaşın — arayabilirsin!',
        );
      case 'new_message':
        messageEvents.add(message);
        final from = message.data['fromUserId'] as String;
        ActivityStore.onIncomingMessage(from);
        ackDelivery(from); // ✓✓ — cihaz aldı, sohbet açılmasa da iletildi olur
        // İçerik bildirimde gösterilmez (uçtan uca şifreli — yalnızca gönderen adı).
        await NotificationService.showGeneral(
          2003,
          message.data['fromName'] as String? ?? 'Yeni mesaj',
          'Sana bir mesaj gönderdi',
        );
      case 'typing':
        typingEvents.add(message);
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
      // Cevapsız arama: arka planda dosyaya işlenir, açılışta rozete döner.
      final callerId = message.data['callerId'] as String?;
      if (callerId != null) {
        await ActivityStore.recordMissedInBackground(callerId);
      }
    case 'friend_request':
      await NotificationService.showGeneral(
        2001,
        'Arkadaşlık isteği',
        '${message.data['fromName']} seninle arkadaş olmak istiyor',
      );
    case 'request_accepted':
      await NotificationService.showGeneral(
        2002,
        'İstek kabul edildi',
        '${message.data['byName']} artık arkadaşın — arayabilirsin!',
      );
    case 'new_message':
      await NotificationService.showGeneral(
        2003,
        message.data['fromName'] as String? ?? 'Yeni mesaj',
        'Sana bir mesaj gönderdi',
      );
      // Uygulama kapalıyken de "iletildi" (✓✓) damgalansın.
      final token = await AuthService.readToken();
      final from = message.data['fromUserId'] as String?;
      if (token != null && from != null) {
        api.setToken(token);
        await FcmService.ackDelivery(from);
      }
  }
}
