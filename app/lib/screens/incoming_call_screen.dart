import 'dart:async';
import 'package:flutter/material.dart';
import '../config.dart';
import '../models/models.dart';
import '../services/activity_store.dart';
import '../services/auth_service.dart';
import '../services/call_manager.dart';
import '../services/ringtone_player.dart';
import '../theme/hop_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/hop_ui.dart';
import '../widgets/preview_layer.dart';

/// Uygulama içi gelen arama ekranı (uygulama açıkken; kapalıyken bildirim var).
/// Cevaplayınca ekran kapanmaz: "Bağlanıyor…" durumuna geçer ve görüşme
/// ekranı bu ekranın YERİNE gelir — arada ana ekran görünmez.
class IncomingCallScreen extends StatefulWidget {
  final IncomingCall call;
  const IncomingCallScreen({super.key, required this.call});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  Timer? _timeout;
  UserProfile? _caller;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _timeout = Timer(ringTimeout, () {
      if (!mounted || _connecting) return;
      CallManager.ringScreenClosed(widget.call.roomName);
      RingtonePlayer.stop();
      ActivityStore.recordMissed(widget.call.callerId); // cevapsız
      // pop() YIĞININ EN ÜSTÜNÜ atar, bu ekranı değil. Yarışlar yüzünden bu
      // ekran görüşme ekranının ALTINDA kalabiliyor; düz pop çağrısı o durumda
      // 45 saniye sonra SÜREN GÖRÜŞMEYİ kapatırdı. Kendi rotamızı adresleyerek
      // kaldırıyoruz.
      final route = ModalRoute.of(context);
      if (route == null) return;
      if (route.isCurrent) {
        Navigator.of(context).pop();
      } else if (route.isActive) {
        Navigator.of(context).removeRoute(route);
      }
    });
    AuthService.cachedFriends().then((friends) {
      final match =
          friends.where((f) => f.id == widget.call.callerId).firstOrNull;
      if (match != null && mounted) setState(() => _caller = match);
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  Future<void> _answer() async {
    _timeout?.cancel();
    setState(() => _connecting = true);
    // CallManager bağlantı kurulunca bu ekranı CallScreen ile DEĞİŞTİRİR.
    final joined = await CallManager.answerIncoming(widget.call);
    if (!joined && mounted) {
      Navigator.of(context).pop(); // kurulamadı — geri dön (toast gösterildi)
    }
  }

  /// "Ali, Mehmet ve Ayşe" — soyadlar atılır, uzun liste kısaltılır.
  static String _participantLabel(List<String> names) {
    final firsts = names
        .map((n) => n.trim().split(' ').first)
        .where((n) => n.isNotEmpty)
        .toList();
    if (firsts.isEmpty) return '';
    if (firsts.length == 1) return firsts.first;
    if (firsts.length <= 3) {
      return '${firsts.sublist(0, firsts.length - 1).join(', ')} ve ${firsts.last}';
    }
    return '${firsts.take(2).join(', ')} ve ${firsts.length - 2} kişi daha';
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    final caller = _caller ??
        UserProfile(
            id: call.callerId,
            firstName: call.callerName,
            lastName: '',
            friendStatus: 'friend');
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Hop.callGradient.first,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: Hop.callGradient,
                ),
              ),
            ),
            // Görüntülü arama gelirken kendini gör (WhatsApp gibi).
            PreviewLayer(enabled: widget.call.video),
            const BlobBackground(dark: true),
            SafeArea(
          child: SizedBox.expand(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),
                if (_connecting)
                  Avatar(user: caller, radius: 72)
                else
                  PulseRing(
                    radius: 78,
                    child: Avatar(user: caller, radius: 72),
                  ),
                const SizedBox(height: 24),
                Text(call.callerName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(call.video ? Icons.videocam : Icons.call,
                        color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _connecting
                          ? 'Bağlanıyor…'
                          : call.group
                              ? 'Seni gruba çağırıyor…'
                              : call.video
                                  ? 'Görüntülü arıyor…'
                                  : 'Sesli arıyor…',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                  ],
                ),
                // Grup davetinde odada kimlerin olduğu — "kimin yanına
                // giriyorum?" sorusu cevapsız kalmasın.
                if (!_connecting && call.group && call.participants.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.groups,
                              color: Colors.white70, size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Görüşmede: ${_participantLabel(call.participants)}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_connecting) ...[
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(color: Colors.white54),
                ],
                const Spacer(),
                if (!_connecting)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 48),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            GradientOrb(
                              icon: Icons.call_end,
                              size: 76,
                              colors: const [
                                Color(0xFFE85D5D),
                                Color(0xFFC62839)
                              ],
                              onTap: () {
                                _timeout?.cancel();
                                Navigator.of(context).pop();
                                CallManager.rejectIncoming(widget.call);
                              },
                            ),
                            const SizedBox(height: 8),
                            const Text('Reddet',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                        Column(
                          children: [
                            PulseRing(
                              radius: 40,
                              color: const Color(0xFF34B979),
                              child: GradientOrb(
                                icon: Icons.call,
                                size: 76,
                                colors: const [
                                  Color(0xFF34B979),
                                  Color(0xFF1F9D8A)
                                ],
                                onTap: _answer,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text('Cevapla',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox(height: 88),
              ],
            ),
          ),
            ),
          ],
        ),
      ),
    );
  }
}
