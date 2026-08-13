import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'models/models.dart';
import 'screens/incoming_call_screen.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';
import 'services/auth_service.dart';
import 'services/bootstrap.dart';
import 'services/call_manager.dart';
import 'services/fcm_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase yapılandırması bozuksa (ör. yer tutucu google-services.json ile
  // emülatör testi) uygulama arama bildirimi almadan da açılabilmeli.
  try {
    await Firebase.initializeApp();
    await FcmService.init();
  } catch (_) {}
  await NotificationService.init(onResponse: _onNotificationResponse);
  await initializeDateFormatting('tr');
  final loggedIn = await auth.restore();
  runApp(HopHopApp(loggedIn: loggedIn));
}

/// Bildirim aksiyonları (uygulama ön planda/arka planda ama süreç canlıyken).
void _onNotificationResponse(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null || payload.isEmpty) return;
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

class _HopHopAppState extends State<HopHopApp> {
  @override
  void initState() {
    super.initState();
    CallManager.init();
    if (widget.loggedIn) {
      _postLoginSetup();
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
    return MaterialApp(
      title: 'HopHop',
      navigatorKey: CallManager.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF7A3D)),
        cardTheme: const CardThemeData(elevation: 1),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr'), Locale('en')],
      locale: const Locale('tr'),
      home: widget.loggedIn ? const Shell() : const LoginScreen(),
    );
  }
}
