import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:livekit_client/livekit_client.dart';

import '../services/preview_camera.dart';

/// Arama ekranlarının arka planındaki kendi kamera görüntün.
///
/// Görüntü hazır değilken (izin yok, kamera meşgul, henüz açılmadı) hiçbir şey
/// çizmez — altındaki degrade/avatar düzeni olduğu gibi kalır. Üstüne koyu bir
/// perde iner: yoksa beyaz duvara bakan biri için isim ve düğmeler okunmuyor.
class PreviewLayer extends StatelessWidget {
  /// Görüntülü aramalarda true; sesli aramada önizleme gösterilmez.
  final bool enabled;

  const PreviewLayer({super.key, required this.enabled});

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    return ValueListenableBuilder<LocalVideoTrack?>(
      valueListenable: PreviewCamera.track,
      builder: (context, track, _) {
        if (track == null) return const SizedBox.shrink();
        return Stack(
          fit: StackFit.expand,
          children: [
            VideoTrackRenderer(
              track,
              fit: VideoViewFit.cover,
              // Kendi görüntün aynadaki gibi olmalı; ham kare ters geliyor.
              mirrorMode: VideoViewMirrorMode.mirror,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.black26, Colors.black87],
                ),
              ),
            ),
          ],
        ).animate().fadeIn(duration: const Duration(milliseconds: 350));
      },
    );
  }
}
