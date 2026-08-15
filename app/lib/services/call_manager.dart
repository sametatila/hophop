import 'dart:async';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../config.dart';
import '../models/models.dart';
import '../screens/call_screen.dart';
import '../screens/incoming_call_screen.dart';
import '../screens/outgoing_call_screen.dart';
import '../widgets/mini_call.dart';
import 'activity_store.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'call_service.dart';
import 'call_tones.dart';
import 'crypto_service.dart';
import 'fcm_service.dart';
import 'lock_screen.dart';
import 'notification_service.dart';
import 'pip_service.dart';
import 'preview_camera.dart';
import 'ringtone_player.dart';
import 'update_service.dart';

/// Süren aramanın bilgisi — davet akışı (grup arama) buradan beslenir.
class ActiveCall {
  final String roomName;
  final String roomKeyB64;
  final bool video;
  ActiveCall({required this.roomName, required this.roomKeyB64, required this.video});
}

/// Küçültülmüş görüşmenin tüm durumu.
///
/// Görüşme ekranı kapansa da oda BAĞLI kalsın diye durum ekrandan çıkarılıp
/// buraya alınır; tam ekrana dönüldüğünde ekran bu kayıttan kaldığı yerden
/// kurulur. Süre `startedAt`ten hesaplanır — küçültme/büyütme sayacı sıfırlamaz.
class MinimizedCall {
  final Room room;
  final UserProfile peer;
  final bool video;
  final String roomName;
  final String livekitUrl;
  final String livekitToken;
  final DateTime startedAt;
  final bool micOn;
  final bool camOn;
  final bool speakerOn;

  const MinimizedCall({
    required this.room,
    required this.peer,
    required this.video,
    required this.roomName,
    required this.livekitUrl,
    required this.livekitToken,
    required this.startedAt,
    required this.micOn,
    required this.camOn,
    required this.speakerOn,
  });

  Duration get elapsed => DateTime.now().difference(startedAt);
}

/// Arama durum makinesi: giden arama (çaldır → kabul/red/zaman aşımı),
/// gelen arama (bildirimden ya da uygulama içinden cevapla/reddet), oda kurulumu.
class CallManager {
  static final navigatorKey = GlobalKey<NavigatorState>();
  static StreamSubscription? _sub;
  static ActiveCall? activeCall;

  /// Görüşmede miyiz? AYRI BİR BAYRAK TUTULMUYOR: iki değişken kaçınılmaz
  /// olarak birbirinden ayrı düşüyordu ve asılı kalan bayrak cihazı kalıcı
  /// olarak "meşgul" yapıp gelen her aramayı sessizce reddettiriyordu.
  static bool get _inCall => activeCall != null;

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
    // Kilitli telefonda arama ekranı keyguard'ın üstünde açılsın.
    unawaited(LockScreen.enable());
    // Arayana "telefonu gerçekten çalıyor" de. Bildirimin FCM tarafından kabul
    // edilmesi çaldığı anlamına gelmiyordu; arayan bu onay gelmezse boşuna
    // bekliyordu. Başarısız olursa arama akışı etkilenmez.
    unawaited(() async {
      try {
        await api.notifyRinging(ring.roomName, ring.callerId);
      } catch (_) {}
    }());
    final foreground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (foreground) {
      // Görüntülü arama gelirken kendini gör (WhatsApp gibi). Arka planda
      // Android kamerayı vermediği için yalnızca ön planda denenir.
      if (ring.video) unawaited(PreviewCamera.start());
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
    unawaited(LockScreen.disable());
    unawaited(PreviewCamera.stop());
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
      // Cevaplanmadan kapandı — kilit ekranı yetkisi geri alınmalı.
      if (!_inCall) {
        unawaited(LockScreen.disable());
        unawaited(PreviewCamera.stop());
      }
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
        unawaited(CallTones.ended());
        unawaited(PreviewCamera.stop());
        _popIfCurrent<OutgoingCallScreen>();
        _toast('Cevaplamadı');
      case 'call_busy':
        unawaited(CallTones.ended());
        unawaited(PreviewCamera.stop());
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
      String? calleePublicKey,
      int devices,
      int delivered,
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

    // "Aranıyor" tonu: karşı taraf çalarken arayan da bir şey duysun.
    unawaited(CallTones.startRingback());
    // Görüntülü ararken kendini gör (WhatsApp gibi).
    if (video) unawaited(PreviewCamera.start());

    var settled = false; // kabul, red veya iptal gerçekleşti mi
    // 'ringing'      → bildirim yollandı, karşı cihazdan haber yok
    // 'ringing_ok'   → karşı cihaz "çalıyorum" dedi (gerçekten çalıyor)
    // 'unreachable'  → bildirim hiçbir cihaza teslim edilemedi
    // 'connecting'   → kabul edildi, odaya giriliyor
    final status = ValueNotifier<String>(
        r.devices == 0 || r.delivered == 0 ? 'unreachable' : 'ringing');
    StreamSubscription? sub;
    Timer? timeout;

    void cleanup() {
      sub?.cancel();
      timeout?.cancel();
      CallTones.stopRingback();
    }

    sub = FcmService.callEvents.stream.listen((message) async {
      final data = Map<String, dynamic>.from(message.data as Map);
      if (data['roomName'] != r.roomName) return;
      if (data['type'] == 'call_ringing' && !settled) {
        // Karşı cihaz bildirimi aldı ve zili çaldırdı — artık eminiz.
        if (status.value != 'connecting') status.value = 'ringing_ok';
        return;
      }
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
      unawaited(CallTones.ended());
      unawaited(PreviewCamera.stop());
      _popIfCurrent<OutgoingCallScreen>();
      // Telefonu hiç çalmadıysa "cevaplamadı" demek yanıltıcı olur.
      _toast(status.value == 'ringing_ok'
          ? 'Cevaplamadı'
          : '${friend.firstName} kişisine ulaşılamadı — telefonu kapalı ya da '
              'çevrimdışı olabilir');
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
          unawaited(PreviewCamera.stop());
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
    // Odayı BURADA işaretle. Eskiden bunun handleRing'de yapılmış olduğu
    // varsayılıyordu; oysa bildirimden cevaplanan soğuk açılışta handleRing bu
    // isolate'te hiç çalışmıyor. İşaretlenmeyen oda, cevap verdikten sonra
    // gerçek-zamanlı dinleyici ya da bekleyen-arama yoklamasıyla tekrar gelip
    // görüşmenin ALTINA bir "gelen arama" ekranı bırakıyordu; görüşme bitince
    // o ekran karşımıza çıkıyordu.
    _handledRooms.add(call.roomName);
    // Kamerayı HEMEN bırak: sunucu turu (respondCall) boyunca donanım serbest
    // kalsın, LiveKit'in açması gecikmeye takılmasın.
    await PreviewCamera.stop();
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
      // Sebebi de yaz: düz "katılınamadı" hata ihbarlarını teşhis edilemez
      // kılıyordu.
      _toast('Aramaya katılınamadı: $e');
      return false;
    }
  }

  static Future<void> rejectIncoming(IncomingCall call) async {
    _ringing = null;
    _ringRoute = null;
    _handledRooms.add(call.roomName); // bkz. answerIncoming
    unawaited(LockScreen.disable());
    unawaited(PreviewCamera.stop());
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
    if (_nav == null) return false;
    activeCall = ActiveCall(roomName: roomName, roomKeyB64: sharedKey, video: video);
    // Kamerayı LiveKit'e devretmeden önce önizlemeyi bırak: aynı anda iki
    // kamera oturumu açılamıyor.
    await PreviewCamera.stop();
    final Room room;
    try {
      room = await CallService.connect(
        url: url,
        token: token,
        sharedKeyB64: sharedKey,
        video: video,
      );
    } catch (e, st) {
      debugPrint('HopHop: oda kurulamadı: $e\n$st');
      activeCall = null;
      // Sebep de yazılıyor: düz "kurulamadı" hata ihbarlarını teşhis
      // edilemez kılıyordu.
      _toast('Görüşme kurulamadı: $e');
      return false;
    }
    // "Bağlandı" tonu — iki tarafta da çalar (arayan ve cevaplayan).
    unawaited(CallTones.stopRingback());
    unawaited(CallTones.connected());
    // Ekranı açmayı beklemeden döneriz: görüşme artık ekrana değil, buradaki
    // duruma bağlı (küçültülünce ekran kapansa da oda ayakta kalır).
    unawaited(_showCallScreen(
      room: room,
      peer: peer,
      video: video,
      roomName: roomName,
      url: url,
      token: token,
      replaceCurrent: replaceCurrent,
    ));
    return true;
  }

  // ---- Görüşme ekranı ↔ küçük pencere ----

  /// Ekranda duran küçük pencere (varsa) ve ona ait görüşme.
  static OverlayEntry? _miniEntry;
  static MinimizedCall? minimized;

  /// Görüşme ekranını açar ve kapanışını yönetir. Ekran [MinimizedCall] ile
  /// kapandıysa görüşme bitmemiştir — küçük pencereye devredilir.
  static Future<void> _showCallScreen({
    required Room room,
    required UserProfile peer,
    required bool video,
    required String roomName,
    required String url,
    required String token,
    bool replaceCurrent = false,
    MinimizedCall? resume,
  }) async {
    // Soğuk açılışta (bildirimdeki "Cevapla" ile) Navigator henüz kurulmamış
    // olabiliyor. Eskiden burada sessizce vazgeçiliyordu: görüşme durumu
    // asılı kalıyor ve cihaz o andan sonra gelen HER aramayı otomatik
    // "meşgul" diye reddediyordu — kullanıcıya tek belirti sohbetteki cevapsız
    // arama kaydı oluyordu. Kısa bir süre bekle, yine yoksa düzgünce kapat.
    var nav = _nav;
    for (var i = 0; nav == null && i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      nav = _nav;
    }
    if (nav == null) {
      debugPrint('HopHop: görüşme ekranı açılamadı — oda kapatılıyor');
      try {
        await room.disconnect();
        await room.dispose();
      } catch (_) {}
      _finishCall(peer: peer, video: video, dropped: false);
      return;
    }
    final route = MaterialPageRoute(
      builder: (_) => CallScreen(
        room: room,
        peer: peer,
        videoCall: video,
        roomName: roomName,
        livekitUrl: url,
        livekitToken: token,
        resume: resume,
      ),
      fullscreenDialog: true,
    );
    // Çalan ekranı pushReplacement'a bırakmıyoruz: o yalnızca EN ÜSTTEKİ rotayı
    // değiştirir. Zil ekranı yarışlar yüzünden görüşme ekranının altında
    // kalabildiği için rotayı adıyla kaldırıyoruz — görüşme bitince altından
    // "gelen arama" ekranı çıkmasın.
    final ringRoute = _ringRoute;
    _ringRoute = null;
    final pushed = replaceCurrent && ringRoute == null && nav.canPop()
        ? nav.pushReplacement(route)
        : nav.push(route);
    if (ringRoute != null && ringRoute.isActive) nav.removeRoute(ringRoute);
    final result = await pushed;
    if (result is MinimizedCall) {
      _showMini(result);
      return;
    }
    _finishCall(peer: peer, video: video, dropped: result == 'dropped');
  }

  /// Görüşme gerçekten bitti: durum temizlenir. (Oda ekranın dispose'unda
  /// kapatıldı; küçük pencereden bitirmede [endMinimized] kapatır.)
  static void _finishCall({
    required UserProfile peer,
    required bool video,
    required bool dropped,
  }) {
    _removeMini();
    activeCall = null;
    unawaited(LockScreen.disable());
    unawaited(PreviewCamera.stop());
    // "Kapandı" tonu: sessizce biten görüşme "kapattı mı, ağ mı gitti?"
    // diye düşündürüyordu.
    unawaited(CallTones.ended());
    // Bağlantı koptuysa (kullanıcı kapatmadı) tek dokunuşla yeniden ara.
    if (!dropped) return;
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(SnackBar(
      content: const Text('Bağlantı koptu'),
      duration: const Duration(seconds: 8),
      action: SnackBarAction(
        label: 'Yeniden ara',
        onPressed: () => startCall(peer, video),
      ),
    ));
  }

  /// Görüşmeyi uygulamanın ÜSTÜNDE yüzen küçük pencereye alır. Katman
  /// Navigator'ın overlay'ine elle eklendiği için sonradan açılan sayfaların da
  /// üstünde kalır — kullanıcı sohbetlerde gezerken görüşme görünür durur.
  static void _showMini(MinimizedCall call) {
    _removeMini();
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) {
      // Katman yoksa görüşmeyi askıda bırakma — sessizce kapat.
      _closeRoom(call);
      _finishCall(peer: call.peer, video: call.video, dropped: false);
      return;
    }
    minimized = call;
    _miniEntry = OverlayEntry(builder: (_) => MiniCallWindow(call: call));
    overlay.insert(_miniEntry!);
  }

  static void _removeMini() {
    _miniEntry?.remove();
    _miniEntry = null;
    minimized = null;
  }

  /// Küçük pencereden tam ekrana dön.
  static Future<void> restoreMinimized() async {
    final call = minimized;
    if (call == null) return;
    _removeMini();
    await _showCallScreen(
      room: call.room,
      peer: call.peer,
      video: call.video,
      roomName: call.roomName,
      url: call.livekitUrl,
      token: call.livekitToken,
      resume: call,
    );
  }

  /// Küçük pencereden kapatma (kırmızı düğme) ya da o sırada bağlantının
  /// kopması. Odayı ve görüşmeye özel sistem kilitlerini burada bırakırız —
  /// normalde bunu görüşme ekranının dispose'u yapıyor.
  static void endMinimized({bool dropped = false}) {
    final call = minimized;
    if (call == null) return;
    _closeRoom(call);
    _finishCall(peer: call.peer, video: call.video, dropped: dropped);
  }

  static void _closeRoom(MinimizedCall call) {
    WakelockPlus.disable();
    UpdateService.setProximity(false);
    PipService.setEligible(false);
    call.room.disconnect();
    call.room.dispose();
    final seconds = call.elapsed.inSeconds;
    if (seconds > 0) {
      api.callEnded(call.roomName, seconds).catchError((_) {});
    }
  }
}
