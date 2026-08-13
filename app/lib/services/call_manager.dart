import 'dart:async';
import 'package:flutter/material.dart';
import '../config.dart';
import '../models/models.dart';
import '../screens/call_screen.dart';
import '../screens/incoming_call_screen.dart';
import '../screens/outgoing_call_screen.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'call_service.dart';
import 'crypto_service.dart';
import 'fcm_service.dart';
import 'notification_service.dart';

/// Arama durum makinesi: giden arama (çaldır → kabul/red/zaman aşımı),
/// gelen arama (bildirimden ya da uygulama içinden cevapla/reddet), oda kurulumu.
class CallManager {
  static final navigatorKey = GlobalKey<NavigatorState>();
  static StreamSubscription? _sub;
  static bool _inCall = false;

  static void init() {
    _sub?.cancel();
    _sub = FcmService.callEvents.stream.listen(_onCallEvent);
  }

  static NavigatorState? get _nav => navigatorKey.currentState;

  static Future<void> _onCallEvent(dynamic message) async {
    final data = Map<String, dynamic>.from(message.data as Map);
    switch (data['type']) {
      case 'incoming_call':
        if (_inCall) return; // meşgul — bildirim zaten gösterildi, kendi kendine düşer
        final call = IncomingCall.fromData(data);
        _nav?.push(MaterialPageRoute(
          builder: (_) => IncomingCallScreen(call: call),
          fullscreenDialog: true,
        ));
      case 'call_cancelled':
        await NotificationService.cancelIncomingCall();
        _popIfCurrent<IncomingCallScreen>();
      case 'call_rejected':
        _popIfCurrent<OutgoingCallScreen>();
        _toast('Cevaplamadı 😔');
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

    late final ({
      String roomName,
      String livekitToken,
      String livekitUrl,
      String? calleePublicKey
    }) r;
    try {
      r = await api.initiateCall(friend.id, video);
    } on ApiException {
      _toast('Arama başlatılamadı — bağlantını kontrol et');
      return;
    }

    var settled = false; // kabul, red veya iptal gerçekleşti mi
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
        final publicKey = r.calleePublicKey ?? friend.publicKey;
        if (publicKey == null || publicKey.isEmpty) {
          _popIfCurrent<OutgoingCallScreen>();
          _toast('Karşı taraf henüz hiç giriş yapmamış');
          return;
        }
        final key = await crypto.deriveRoomKey(publicKey, r.roomName);
        await _joinRoom(
          url: r.livekitUrl,
          token: r.livekitToken,
          sharedKey: key,
          video: video,
          peer: friend,
          replaceCurrent: true,
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
        await api.cancelCall(r.roomName, friend.id);
      } catch (_) {}
      _popIfCurrent<OutgoingCallScreen>();
      _toast('Cevaplamadı 😔');
    });

    await nav.push(MaterialPageRoute(
      builder: (_) => OutgoingCallScreen(
        friend: friend,
        video: video,
        onCancel: () async {
          if (settled) return;
          settled = true;
          cleanup();
          try {
            await api.cancelCall(r.roomName, friend.id);
          } catch (_) {}
        },
      ),
      fullscreenDialog: true,
    ));
  }

  // ---- Gelen arama ----

  static Future<void> answerIncoming(IncomingCall call) async {
    await NotificationService.cancelIncomingCall();
    try {
      final r = await api.respondCall(call.roomName, call.callerId, true);
      if (call.callerPublicKey.isEmpty) {
        _toast('Arayanın anahtarı eksik — arama kurulamadı');
        return;
      }
      final key = await crypto.deriveRoomKey(call.callerPublicKey, call.roomName);
      final friends = await AuthService.cachedFriends();
      final peer = friends.where((f) => f.id == call.callerId).firstOrNull ??
          UserProfile(
            id: call.callerId,
            firstName: call.callerName,
            lastName: '',
            friendStatus: 'friend',
          );
      await _joinRoom(
        url: r.livekitUrl,
        token: r.livekitToken,
        sharedKey: key,
        video: call.video,
        peer: peer,
        replaceCurrent: false,
      );
    } on ApiException {
      _toast('Aramaya katılınamadı');
    }
  }

  static Future<void> rejectIncoming(IncomingCall call) async {
    await NotificationService.cancelIncomingCall();
    try {
      await api.respondCall(call.roomName, call.callerId, false);
    } catch (_) {}
  }

  // ---- Oda ----

  static Future<void> _joinRoom({
    required String url,
    required String token,
    required String sharedKey,
    required bool video,
    required UserProfile peer,
    required bool replaceCurrent,
  }) async {
    final nav = _nav;
    if (nav == null) return;
    _inCall = true;
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
    } catch (_) {
      _toast('Görüşme kurulamadı');
      if (replaceCurrent && nav.canPop()) nav.pop();
    } finally {
      _inCall = false;
    }
  }
}
