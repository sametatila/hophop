import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/hop_theme.dart';

/// Basınca hafifçe küçülüp bırakınca yaylanan sarmalayıcı —
/// uygulamadaki tüm dokunulabilir kartlar bunu kullanır.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const Pressable({super.key, required this.child, this.onTap});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: Hop.fast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Yarı saydam, buzlu cam panel (arama kontrolleri, üst rozetler).
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color tint;
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = 24,
    this.tint = Colors.black26,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Yavaşça süzülen degrade ışık kürecikleri — "gelecekten gelmiş" zemin.
/// Giriş, sihirbaz ve arama ekranlarının arkasında yaşar.
class BlobBackground extends StatefulWidget {
  final List<Color>? colors;
  final bool dark;
  const BlobBackground({super.key, this.colors, this.dark = false});

  @override
  State<BlobBackground> createState() => _BlobBackgroundState();
}

class _BlobBackgroundState extends State<BlobBackground>
    with SingleTickerProviderStateMixin {
  late final _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 18))
        ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors ?? Hop.gradient;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _BlobPainter(_controller.value, colors, widget.dark),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  final double t;
  final List<Color> colors;
  final bool dark;
  _BlobPainter(this.t, this.colors, this.dark);

  @override
  void paint(Canvas canvas, Size size) {
    final phase = t * 2 * math.pi;
    for (var i = 0; i < colors.length; i++) {
      final angle = phase + i * 2 * math.pi / colors.length;
      final cx = size.width * (0.5 + 0.34 * math.cos(angle + i));
      final cy = size.height * (0.42 + 0.3 * math.sin(angle * 0.8 + i * 2));
      final r = size.shortestSide * (0.34 + 0.06 * math.sin(phase + i));
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..color = colors[i].withValues(alpha: dark ? 0.22 : 0.16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
      );
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.t != t;
}

/// Çalarken avatarın arkasında genişleyip sönen nabız halkaları.
class PulseRing extends StatefulWidget {
  final double radius;
  final Color color;
  final Widget child;
  const PulseRing({
    super.key,
    required this.radius,
    required this.child,
    this.color = Colors.white,
  });

  @override
  State<PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<PulseRing>
    with SingleTickerProviderStateMixin {
  late final _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            for (final offset in [0.0, 0.5])
              _ring((_controller.value + offset) % 1),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }

  Widget _ring(double p) {
    final size = widget.radius * 2 * (1 + p * 0.9);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.color.withValues(alpha: (1 - p) * 0.35),
          width: 2 + (1 - p) * 2,
        ),
      ),
    );
  }
}

/// Boş durumlar için ortak görsel dil.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors:
                      Hop.gradient.map((c) => c.withValues(alpha: 0.15)).toList(),
                ),
              ),
              child: Icon(icon, size: 56, color: scheme.primary),
            ),
            const SizedBox(height: 20),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.outline, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

/// Degrade dolgulu yuvarlak aksiyon butonu (arama kontrolleri vb.).
class GradientOrb extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final List<Color>? colors;
  final String? tooltip;
  const GradientOrb({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 56,
    this.colors,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors ?? Hop.gradient;
    final button = Pressable(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight, colors: c),
          boxShadow: [
            BoxShadow(
                color: c.last.withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.46),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
