import 'dart:async';
import 'package:flutter/material.dart';
import '../config.dart';
import '../models/models.dart';
import '../screens/call_screen.dart';
import '../screens/incoming_call_screen.dart';
import '../screens/outgoing_call_screen.dart';
import 'activity_store.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'call_service.dart';
import 'crypto_service.dart';
import 'fcm_service.dart';
import 'notification_service.dart';
import 'ringtone_player.dart';

/// Süren aramanın bilgisi — davet akışı (grup arama) buradan beslenir.
class ActiveCall {
  final String roomName;
  final String roomKeyB64;
  final bool video;
  ActiveCall({required this.roomName, required this.roomKeyB64, required this.video});
}

/// Arama durum makinesi: giden arama (çaldır → kabul/red/zaman aşımı),
/// gelen arama (bildirimden ya da uygulama içinden cevapla/reddet), oda kurulumu.
class CallManager {
  static final navigatorKey = GlobalKey<NavigatorState>();
  static StreamSubscription? _sub;
  static bool _inCall = false;
  static ActiveCall? activeCall;

  /// İşlenmiş oda adları — FCM, dinleyici ve yoklama yolları aynı aramayı
  /// ASLA ikinci kez çaldırmaz (dinleyici yeniden bağlanıp aynı zil belgesini
  /// tekrar teslim etse bile). Cevaplandıktan sonra da kayıtlı kalır.
  static final _handledRooms = <String>{};

  /// Şu an ÇALAN arama ve ekranı — iptal sinyali (FCM ya da zil belgesinin
  /// silinmesi) geldiğinde susturup kapatabilmek için.
  static IncomingCall? _ringing;
  static Route<dynamic>? _ringRoute;

  static void init() {
    _sub?.cancel();
    _sub = FcmService.callEvents.stream.listen(_onCallEvent);
  }

  /// Gerçek-zamanlı dinleyiciden ya da yoklamadan gelen aramayı çaldırır.
  /// Oda adına göre çift-çalma koruması içerir.
  ///
  /// WhatsApp davranışı: uygulama ÖN PLANDAYSA arama ekranı zaten görünür —
  /// üstten bildirim şeridi ÇIKMAZ, zili uygulama kendisi çalar. Uygulama
  /// arka plandaysa bildirim (zil sesli + tam ekran intent) devrede kalır.
  static Future<void> handleRing(IncomingCall ring) async {
    if (_handledRooms.contains(ring.roomName)) return;
    if (_inCall) {
      // Meşgul: arayana anında "meşgul" sinyali dön (45 sn bekletme yok).
      _handledRooms.add(ring.roomName);
      unawaited(() async {
        try {
          await api.respondCall(ring.roomName, ring.callerId, false, ring.video,
              busy: true);
        } catch (_) {}
      }());
      return;
    }
    _handledRooms.add(ring.roomName);
    _ringing = ring;
    final foreground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (foreground) {
      RingtonePlayer.start();
    } else {
      await NotificationService.showIncomingCall(ring);
    }
    final route = MaterialPageRoute(
      builder: (_) => IncomingCallScreen(call: ring),
      fullscreenDialog: true,
    );
    _ringRoute = route;
    _nav?.push(route);
  }

  /// Arayan vazgeçti: FCM 'call_cancelled' YA DA zil belgesinin silinmesiyle
  /// gelir (FCM bayatlasa bile Firestore yolu iptali taşır). Hâlâ çalıyorsa
  /// susturur, gelen arama ekranını kapatır, cevapsız olarak işler.
  /// Cevaplandıktan/reddedildikten sonra no-op'tur.
  static Future<void> handleRingGone(String? roomName) async {
    final ring = _ringing;
    if (ring == null) return;
    if (roomName != null && roomName != ring.roomName) return;
    _ringing = null;
    await NotificationService.cancelIncomingCall();
    await RingtonePlayer.stop();
    await ActivityStore.recordMissed(ring.callerId);
    final route = _ringRoute;
    _ringRoute = null;
    if (route != null && route.isActive) _nav?.removeRoute(route);
  }

  /// Gelen arama ekranı kendi zaman aşımıyla kapandığında durum temizliği.
  static void ringScreenClosed(String roomName) {
    if (_ringing?.roomName == roomName) {
      _ringing = null;
      _ringRoute = null;
    }
  }

  /// Sunucuya "beni arayan var mı?" diye sorar (öne geliş/açılış anı için).
  static Future<void> checkPendingRing() async {
    if (_inCall) return;
    try {
      final ring = await api.pendingCall();
      if (ring != null) await handleRing(ring);
    } catch (_) {/* çevrimdışı */}
  }

  static NavigatorState? get _nav => navigatorKey.currentState;

  static Future<void> _onCallEvent(dynamic message) async {
    final data = Map<String, dynamic>.from(message.data as Map);
    switch (data['type']) {
      case 'incoming_call':
        await handleRing(IncomingCall.fromData(data)); // meşgulse busy döner
      case 'call_cancelled':
        // oda _handledRooms kümesinde kalır — yeniden çalmaz
        if (_ringing != null) {
          await handleRingGone(data['roomName'] as String?);
        } else {
          // Zil bu uygulama örneğinde hiç çalmadı (yalnızca bildirim vardı).
          await NotificationService.cancelIncomingCall();
          await RingtonePlayer.stop();
          if (!_inCall) {
            final callerId = data['callerId'] as String?;
            if (callerId != null) ActivityStore.recordMissed(callerId);
          }
        }
      case 'call_rejected':
        _popIfCurrent<OutgoingCallScreen>();
        _toast('Cevaplamadı');
      case 'call_busy':
        _popIfCurrent<OutgoingCallScreen>();
        _toast('Meşgul — başka bir görüşmede');
    }
  }

  static void _popIfCurrent<T>() {
    final nav = _nav;
    if (nav != null && nav.canPop()) nav.pop();
  }

  static void _toast(String msg) {
    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // ---- Giden arama ----

  static Future<void> startCall(UserProfile friend, bool video) async {
    if (_inCall) return;
    final nav = _nav;
    if (nav == null) return;
    ActivityStore.clearMissed(friend.id); // geri arama rozeti temizler
    ActivityStore.bumpActivity(friend.id);

    final publicKey = friend.publicKey;
    if (publicKey == null || publicKey.isEmpty) {
      _toast('${friend.firstName} henüz hiç giriş yapmamış');
      return;
    }

    late final ({
      String roomName,
      String livekitToken,
      String livekitUrl,
      String? calleePublicKey
    }) r;
    // Oda anahtarını BİZ üretiriz; karşıya yalnızca ona özel sarılmış hali gider.
    final roomKey = crypto.generateRoomKey();
    try {
      // Oda adı sunucudan geldiği için sarma işlemi iki adımda yapılır:
      // önce oda adı alınır, sonra davet mantığıyla aynı sarmayla push gider.
      // initiate, roomKeyEnc'i pushta iletir; sarmak için oda adı gerektiğinden
      // sunucu, roomName'i yanıtta döner ve push'u sarılmış anahtar olmadan
      // atamaz — bu yüzden roomName'den bağımsız sarma bağlamı kullanıyoruz.
      final wrapped = await crypto.wrapRoomKey(publicKey, 'call', roomKey);
      r = await api.initiateCall(friend.id, video, wrapped);
    } on ApiException {
      _toast('Arama başlatılamadı — bağlantını kontrol et');
      return;
    }

    var settled = false; // kabul, red veya iptal gerçekleşti mi
    final status = ValueNotifier<String>('ringing');
    StreamSubscription? sub;
    Timer? timeout;

    void cleanup() {
      sub?.cancel();
      timeout?.cancel();
    }

    sub = FcmService.callEvents.stream.listen((message) async {
      final data = Map<String, dynamic>.from(message.data as Map);
      if (data['roomName'] != r.roomName) return;
      if (data['type'] == 'call_accepted' && !settled) {
        settled = true;
        cleanup();
        status.value = 'connecting'; // "Aranıyor" → "Bağlanıyor"
        await _joinRoom(
          url: r.livekitUrl,
          token: r.livekitToken,
          sharedKey: roomKey,
          video: video,
          peer: friend,
          replaceCurrent: true,
          roomName: r.roomName,
        );
      } else if ((data['type'] == 'call_rejected' ||
              data['type'] == 'call_busy') &&
          !settled) {
        settled = true;
        cleanup();
      }
    });

    timeout = Timer(ringTimeout, () async {
      if (settled) return;
      settled = true;
      cleanup();
      try {
        await api.cancelCall(r.roomName, friend.id, video);
      } catch (_) {}
      _popIfCurrent<OutgoingCallScreen>();
      _toast('Cevaplamadı');
    });

    await nav.push(MaterialPageRoute(
      builder: (_) => OutgoingCallScreen(
        friend: friend,
        video: video,
        status: status,
        onCancel: () async {
          if (settled) return;
          settled = true;
          cleanup();
          try {
            await api.cancelCall(r.roomName, friend.id, video);
          } catch (_) {}
        },
      ),
      fullscreenDialog: true,
    ));
  }

  // ---- Gelen arama ----

  /// Aramaya katılır. IncomingCallScreen açıksa görüşme ekranı ONUN YERİNE
  /// gelir (arada ana ekran görünmez). Başarısız olursa false döner.
  static Future<bool> answerIncoming(IncomingCall call) async {
    // Önce zil durumu temizlenir: cevap sonrası sunucunun zil belgesini
    // silmesi handleRingGone'u tetiklememeli.
    _ringing = null;
    _ringRoute = null;
    await NotificationService.cancelIncomingCall();
    await RingtonePlayer.stop();
    // oda _handledRooms kümesinde kalır — yeniden çalmaz
    try {
      final r = await api.respondCall(call.roomName, call.callerId, true, call.video);
      if (call.callerPublicKey.isEmpty || call.roomKeyEnc.isEmpty) {
        _toast('Arayanın anahtarı eksik — arama kurulamadı');
        return false;
      }
      final key = await crypto.unwrapRoomKey(
          call.callerPublicKey, 'call', call.roomKeyEnc);
      final friends = await AuthService.cachedFriends();
      final peer = friends.where((f) => f.id == call.callerId).firstOrNull ??
          UserProfile(
            id: call.callerId,
            firstName: call.callerName,
            lastName: '',
            friendStatus: 'friend',
          );
      return await _joinRoom(
        url: r.livekitUrl,
        token: r.livekitToken,
        sharedKey: key,
        video: call.video,
        peer: peer,
        replaceCurrent: true,
        roomName: call.roomName,
      );
    } on ApiException catch (e) {
      // 410: arayan bu arada vazgeçmiş — boş odaya bağlanmak yerine bilgi ver.
      _toast(e.status == 410 ? 'Arama sona ermiş' : 'Aramaya katılınamadı');
      return false;
    } catch (e, st) {
      debugPrint('HopHop: aramaya katılınamadı: $e\n$st');
      _toast('Aramaya katılınamadı');
      return false;
    }
  }

  static Future<void> rejectIncoming(IncomingCall call) async {
    _ringing = null;
    _ringRoute = null;
    await NotificationService.cancelIncomingCall();
    await RingtonePlayer.stop();
    // oda _handledRooms kümesinde kalır — yeniden çalmaz
    try {
      await api.respondCall(call.roomName, call.callerId, false, call.video);
    } catch (_) {}
  }

  // ---- Oda ----

  static Future<bool> _joinRoom({
    required String url,
    required String token,
    required String sharedKey,
    required bool video,
    required UserProfile peer,
    required bool replaceCurrent,
    required String roomName,
  }) async {
    final nav = _nav;
    if (nav == null) return false;
    _inCall = true;
    activeCall = ActiveCall(roomName: roomName, roomKeyB64: sharedKey, video: video);
    try {
      final room = await CallService.connect(
        url: url,
        token: token,
        sharedKeyB64: sharedKey,
        video: video,
      );
      final route = MaterialPageRoute(
        builder: (_) => CallScreen(
            room: room,
            peer: peer,
            videoCall: video,
            roomName: roomName,
            livekitUrl: url,
            livekitToken: token),
        fullscreenDialog: true,
      );
      final result = replaceCurrent && nav.canPop()
          ? await nav.pushReplacement(route)
          : await nav.push(route);
      // Bağlantı koptuysa (kullanıcı kapatmadı) tek dokunuşla yeniden ara.
      if (result == 'dropped') {
        final messenger = navigatorKey.currentContext == null
            ? null
            // ignore: use_build_context_synchronously
            : ScaffoldMessenger.maybeOf(navigatorKey.currentContext!);
        messenger?.showSnackBar(SnackBar(
          content: const Text('Bağlantı koptu'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Yeniden ara',
            onPressed: () => startCall(peer, video),
          ),
        ));
      }
      return true;
    } catch (e, st) {
      debugPrint('HopHop: oda kurulamadı: $e\n$st');
      _toast('Görüşme kurulamadı');
      return false;
    } finally {
      _inCall = false;
      activeCall = null;
    }
  }
}
