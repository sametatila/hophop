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
  /// 'ringing' (bildirim yollandı) · 'ringing_ok' (karşı cihaz çaldığını
  /// doğruladı) · 'unreachable' (hiçbir cihaza teslim edilemedi) · 'connecting'
  final ValueNotifier<String> status;

  const OutgoingCallScreen({
    super.key,
    required this.friend,
    required this.video,
    required this.onCancel,
    required this.status,
  });

  /// Arayan taraf ne olup bittiğini bu satırdan anlar.
  static String _statusText(String status, bool video) => switch (status) {
        'connecting' => 'Bağlanıyor…',
        // Karşı cihaz "çaldım" dedi — artık tahmin değil, bilgi.
        'ringing_ok' => 'Telefonu çalıyor…',
        'unreachable' => 'Telefonuna ulaşılamıyor',
        _ => video ? 'Görüntülü aranıyor…' : 'Aranıyor…',
      };

  /// Ulaşılamama hâlinde tek satır açıklama — kullanıcı neden beklediğini bilsin.
  static String? _statusHint(String status) => switch (status) {
        'unreachable' =>
          'Telefonu kapalı ya da internete bağlı değil. Yine de birkaç saniye '
              'deneyeceğiz; açılırsa çalacak.',
        'ringing' => 'Bildirim gönderildi, cihazından yanıt bekleniyor…',
        _ => null,
      };

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
                              _statusText(s, video),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 18),
                            ),
                          ],
                        ),
                        if (_statusHint(s) != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(32, 10, 32, 0),
                            child: Text(
                              _statusHint(s)!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: s == 'unreachable'
                                      ? Colors.orangeAccent
                                      : Colors.white54,
                                  fontSize: 14),
                            ),
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
