import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'models/models.dart';
import 'screens/chat_screen.dart';
import 'screens/incoming_call_screen.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';
import 'services/activity_store.dart';
import 'services/auth_service.dart';
import 'services/bootstrap.dart';
import 'services/ring_listener.dart';
import 'theme/hop_theme.dart';
import 'services/call_manager.dart';
import 'services/fcm_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Açılış hiçbir koşulda takılmamalı ya da yarıda kesilmemeli: her hazırlık
  // adımı ayrı ayrı korunur. Biri patlarsa (ör. release'de kırpılmış bir kaynak)
  // ya da yanıt vermezse (ör. ağ), uygulama o özellik olmadan yine de açılır.
  // Bunun alternatifi, kullanıcının gördüğü sonsuz beyaz ekrandır.
  await _step('firebase', () async {
    await Firebase.initializeApp();
    await FcmService.init();
  });
  await _step('bildirimler',
      () => NotificationService.init(onResponse: _onNotificationResponse));
  await _step('tarih biçimleri', () => initializeDateFormatting('tr'));

  // Oturum: yerel token okunur; sunucu tazelemesi ağ yavaşsa beklenmez.
  final loggedIn =
      await _step('oturum', auth.restore, timeout: const Duration(seconds: 8)) ??
          auth.me != null;

  runApp(HopHopApp(loggedIn: loggedIn));
}

/// Bir açılış adımını zaman aşımı + hata yutmayla çalıştırır.
/// Başarısızlıkta null döner; açılış her hâlükârda devam eder.
Future<T?> _step<T>(
  String name,
  Future<T> Function() run, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  try {
    return await run().timeout(timeout);
  } catch (e) {
    debugPrint('⚠ Açılış adımı "$name" atlandı: $e');
    return null;
  }
}

/// Bildirim aksiyonları (uygulama ön planda/arka planda ama süreç canlıyken).
void _onNotificationResponse(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null || payload.isEmpty) return;
  // Mesaj bildirimi → doğrudan o sohbeti aç.
  if (payload.startsWith('chat:')) {
    final friendId = payload.substring(5);
    AuthService.cachedFriends().then((friends) {
      final friend = friends.where((f) => f.id == friendId).firstOrNull;
      if (friend != null) {
        CallManager.navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => ChatScreen(friend: friend)));
      }
    });
    return;
  }
  late final IncomingCall call;
  try {
    call = IncomingCall.fromData(
        Map<String, dynamic>.from(jsonDecode(payload) as Map));
  } catch (_) {
    return;
  }
  switch (response.actionId) {
    case 'answer':
      CallManager.answerIncoming(call);
    case 'reject':
      CallManager.rejectIncoming(call);
    default:
      // Bildirimin gövdesine dokunuldu → uygulama içi gelen arama ekranı.
      CallManager.navigatorKey.currentState?.push(MaterialPageRoute(
        builder: (_) => IncomingCallScreen(call: call),
        fullscreenDialog: true,
      ));
  }
}

class HopHopApp extends StatefulWidget {
  final bool loggedIn;
  const HopHopApp({super.key, required this.loggedIn});

  @override
  State<HopHopApp> createState() => _HopHopAppState();
}

class _HopHopAppState extends State<HopHopApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CallManager.init();
    if (widget.loggedIn) {
      _postLoginSetup();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Öne gelir gelmez: bekleyen arama var mı (anında çaldır) + rozetleri
      // tazele + dinleyici koptaysa yeniden kur.
      CallManager.checkPendingRing();
      ActivityStore.refresh();
      RingListener.start();
    }
  }

  /// Oturum hazır olduğunda: E2EE anahtarı + FCM token sunucuya, ön plan
  /// servisi ayağa, "Cevapla" ile açıldıysak aramaya katıl.
  Future<void> _postLoginSetup() async {
    await postLoginSetup();
    final launch = await NotificationService.launchDetails();
    if (launch != null) _onNotificationResponse(launch);
  }

  @override
  Widget build(BuildContext context) {
    // Tema, girişte doğum tarihinden türeyen moda (çocuk/yetişkin) göre
    // canlı olarak değişir.
    return ValueListenableBuilder(
      valueListenable: appMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'HopHop',
        navigatorKey: CallManager.navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: hopTheme(mode),
        themeAnimationDuration: const Duration(milliseconds: 500),
        themeAnimationCurve: Curves.easeOutCubic,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('tr'), Locale('en')],
        locale: const Locale('tr'),
        home: widget.loggedIn ? const Shell() : const LoginScreen(),
      ),
    );
  }
}
