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
    if (_inCall || _handledRooms.contains(ring.roomName)) return;
    _handledRooms.add(ring.roomName);
    final foreground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (foreground) {
      RingtonePlayer.start();
    } else {
      await NotificationService.showIncomingCall(ring);
    }
    _nav?.push(MaterialPageRoute(
      builder: (_) => IncomingCallScreen(call: ring),
      fullscreenDialog: true,
    ));
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
        if (_inCall) return; // meşgul — kendi kendine düşer
        await handleRing(IncomingCall.fromData(data));
      case 'call_cancelled':
        await NotificationService.cancelIncomingCall();
        await RingtonePlayer.stop();
        // oda _handledRooms kümesinde kalır — yeniden çalmaz
        if (!_inCall) {
          final callerId = data['callerId'] as String?;
          if (callerId != null) ActivityStore.recordMissed(callerId);
        }
        _popIfCurrent<IncomingCallScreen>();
      case 'call_rejected':
        _popIfCurrent<OutgoingCallScreen>();
        _toast('Cevaplamadı');
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
      } else if (data['type'] == 'call_rejected' && !settled) {
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
    } catch (e, st) {
      debugPrint('HopHop: aramaya katılınamadı: $e\n$st');
      _toast('Aramaya katılınamadı');
      return false;
    }
  }

  static Future<void> rejectIncoming(IncomingCall call) async {
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
        builder: (_) => CallScreen(room: room, peer: peer, videoCall: video),
        fullscreenDialog: true,
      );
      if (replaceCurrent && nav.canPop()) {
        await nav.pushReplacement(route);
      } else {
        await nav.push(route);
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
