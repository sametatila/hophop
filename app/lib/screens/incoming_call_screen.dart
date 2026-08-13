import 'dart:async';
import 'package:flutter/material.dart';
import '../config.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/call_manager.dart';
import '../widgets/avatar.dart';

/// Uygulama içi gelen arama ekranı (uygulama açıkken; kapalıyken bildirim var).
class IncomingCallScreen extends StatefulWidget {
  final IncomingCall call;
  const IncomingCallScreen({super.key, required this.call});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  Timer? _timeout;
  UserProfile? _caller;

  @override
  void initState() {
    super.initState();
    _timeout = Timer(ringTimeout, () {
      if (mounted) Navigator.of(context).pop();
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
        backgroundColor: const Color(0xFF1B2430),
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              Avatar(user: caller, radius: 72),
              const SizedBox(height: 24),
              Text(call.callerName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                call.video ? '📹 Görüntülü arıyor…' : '📞 Sesli arıyor…',
                style: const TextStyle(color: Colors.white70, fontSize: 18),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        FloatingActionButton.large(
                          heroTag: 'reject',
                          backgroundColor: Colors.red,
                          onPressed: () {
                            _timeout?.cancel();
                            Navigator.of(context).pop();
                            CallManager.rejectIncoming(call);
                          },
                          child: const Icon(Icons.call_end, size: 40),
                        ),
                        const SizedBox(height: 8),
                        const Text('Reddet',
                            style: TextStyle(color: Colors.white)),
                      ],
                    ),
                    Column(
                      children: [
                        FloatingActionButton.large(
                          heroTag: 'answer',
                          backgroundColor: Colors.green,
                          onPressed: () {
                            _timeout?.cancel();
                            Navigator.of(context).pop();
                            CallManager.answerIncoming(call);
                          },
                          child: const Icon(Icons.call, size: 40),
                        ),
                        const SizedBox(height: 8),
                        const Text('Cevapla',
                            style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
