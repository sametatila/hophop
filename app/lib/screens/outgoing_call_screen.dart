import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/hop_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/hop_ui.dart';

/// Giden arama ekranı. Gelen arama ekranıyla aynı görsel dil:
/// çalarken nabız halkaları, bağlanırken halkalar durur + spinner gelir
/// ve aksiyon butonu gizlenir.
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
            const BlobBackground(dark: true),
            SafeArea(
              child: ValueListenableBuilder(
                valueListenable: status,
                builder: (context, s, _) {
                  final connecting = s == 'connecting';
                  return SizedBox.expand(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Spacer(),
                        if (connecting)
                          Avatar(user: friend, radius: 72)
                        else
                          PulseRing(
                            radius: 78,
                            child: Avatar(user: friend, radius: 72),
                          ),
                        const SizedBox(height: 24),
                        Text(friend.fullName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(video ? Icons.videocam : Icons.call,
                                color: Colors.white70, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              connecting
                                  ? 'Bağlanıyor…'
                                  : (video
                                      ? 'Görüntülü aranıyor…'
                                      : 'Aranıyor…'),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 18),
                            ),
                          ],
                        ),
                        if (connecting) ...[
                          const SizedBox(height: 24),
                          const CircularProgressIndicator(
                              color: Colors.white54),
                        ],
                        const Spacer(),
                        if (!connecting)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 48),
                            child: GradientOrb(
                              icon: Icons.call_end,
                              size: 76,
                              colors: const [
                                Color(0xFFE85D5D),
                                Color(0xFFC62839)
                              ],
                              onTap: () async {
                                await onCancel();
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                            ),
                          )
                        else
                          const SizedBox(height: 124),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
