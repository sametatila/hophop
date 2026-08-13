import 'package:flutter/material.dart';
import '../models/models.dart';
import '../widgets/avatar.dart';

/// Giden arama — "çalıyor" ekranı. Kabul edilince [status] "Bağlanıyor…"a
/// döner ve CallManager bu ekranı CallScreen ile değiştirir;
/// red/zaman aşımında kapatılır.
class OutgoingCallScreen extends StatelessWidget {
  final UserProfile friend;
  final bool video;
  final Future<void> Function() onCancel;
  final ValueNotifier<String> status; // 'ringing' | 'connecting'

  const OutgoingCallScreen({
    super.key,
    required this.friend,
    required this.video,
    required this.onCancel,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // geri tuşu yerine kırmızı buton
      child: Scaffold(
        backgroundColor: const Color(0xFF1B2430),
        body: SafeArea(
          child: SizedBox.expand(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),
                Avatar(user: friend, radius: 72),
                const SizedBox(height: 24),
                Text(friend.fullName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ValueListenableBuilder(
                  valueListenable: status,
                  builder: (context, s, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(video ? Icons.videocam : Icons.call,
                          color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        s == 'connecting'
                            ? 'Bağlanıyor…'
                            : (video
                                ? 'Görüntülü aranıyor…'
                                : 'Aranıyor…'),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 18),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(color: Colors.white54),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 48),
                  child: FloatingActionButton.large(
                    backgroundColor: Colors.red,
                    onPressed: () async {
                      await onCancel();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: const Icon(Icons.call_end, size: 40),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
