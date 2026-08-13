import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'fx_frame.dart';

/// FxFrame'i video görüntüsünün üstüne çizer (hem yerel hem uzak taraf).
/// Vektörel çizim: paket yok, asset yok, her çözünürlükte keskin.
class EffectPainter extends CustomPainter {
  final FxFrame? frame;
  const EffectPainter(this.frame);

  @override
  void paint(Canvas canvas, Size size) {
    final f = frame;
    if (f == null || f.isOff) return;

    final cx = f.cx * size.width;
    final cy = f.cy * size.height;
    final fw = f.w * size.width;
    final fh = f.h * size.height;
    if (fw < 8) return;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(f.rz);
    canvas.translate(-cx, -cy);

    switch (f.effect) {
      case 'bunny':
        _bunny(canvas, size, f, cx, cy, fw, fh);
      case 'dog':
        _dog(canvas, size, f, cx, cy, fw, fh);
      case 'crown':
        _crown(canvas, cx, cy, fw, fh);
      case 'glasses':
        _glasses(canvas, size, f, fw);
      case 'mustache':
        _mustache(canvas, size, f, fw);
    }
    canvas.restore();
  }

  // ---- Tavşan: beyaz kulaklar + pembe burun + bıyıklar ----
  void _bunny(Canvas c, Size s, FxFrame f, double cx, double cy, double fw, double fh) {
    final white = Paint()..color = Colors.white;
    final pink = Paint()..color = const Color(0xFFF8A8C0);
    final top = cy - fh * 0.55;
    for (final side in [-1, 1]) {
      final ex = cx + side * fw * 0.22;
      final ear = Rect.fromCenter(
          center: Offset(ex, top - fh * 0.35), width: fw * 0.22, height: fh * 0.75);
      c.drawOval(ear, white);
      c.drawOval(ear.deflate(fw * 0.05), pink);
    }
    final nx = f.nx * s.width, ny = f.ny * s.height;
    final nose = Path()
      ..moveTo(nx - fw * 0.07, ny - fh * 0.04)
      ..lineTo(nx + fw * 0.07, ny - fh * 0.04)
      ..lineTo(nx, ny + fh * 0.05)
      ..close();
    c.drawPath(nose, Paint()..color = const Color(0xFFE86A9A));
    _whiskers(c, nx, ny, fw);
  }

  // ---- Köpek: kahve kulaklar + siyah burun + ağız açılınca dil ----
  void _dog(Canvas c, Size s, FxFrame f, double cx, double cy, double fw, double fh) {
    final brown = Paint()..color = const Color(0xFF8B5A2B);
    final top = cy - fh * 0.42;
    for (final side in [-1, 1]) {
      final ex = cx + side * fw * 0.42;
      final ear = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(ex, top + fh * 0.12), width: fw * 0.28, height: fh * 0.62),
        Radius.circular(fw * 0.14),
      );
      c.drawRRect(ear, brown);
    }
    final nx = f.nx * s.width, ny = f.ny * s.height;
    c.drawOval(
      Rect.fromCenter(center: Offset(nx, ny), width: fw * 0.24, height: fh * 0.14),
      Paint()..color = Colors.black87,
    );
    if (f.mouth > 0.25) {
      // Dil: ağız açıklığıyla uzar 👅
      final len = fh * (0.15 + 0.35 * f.mouth);
      final tongue = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(nx, ny + fh * 0.22 + len / 2),
          width: fw * 0.20,
          height: len,
        ),
        Radius.circular(fw * 0.10),
      );
      c.drawRRect(tongue, Paint()..color = const Color(0xFFE86A9A));
      c.drawLine(
        Offset(nx, ny + fh * 0.26),
        Offset(nx, ny + fh * 0.22 + len * 0.85),
        Paint()
          ..color = const Color(0xFFC94F7C)
          ..strokeWidth = fw * 0.015,
      );
    }
  }

  // ---- Taç ----
  void _crown(Canvas c, double cx, double cy, double fw, double fh) {
    final gold = Paint()..color = const Color(0xFFFFC93C);
    final base = cy - fh * 0.62;
    final w = fw * 0.7;
    final path = Path()..moveTo(cx - w / 2, base);
    for (var i = 0; i < 3; i++) {
      final x0 = cx - w / 2 + w * i / 3;
      path
        ..lineTo(x0 + w / 6, base - fh * 0.28)
        ..lineTo(x0 + w / 3, base);
    }
    path
      ..lineTo(cx + w / 2, base + fh * 0.12)
      ..lineTo(cx - w / 2, base + fh * 0.12)
      ..close();
    c.drawPath(path, gold);
    for (var i = 0; i < 3; i++) {
      c.drawCircle(
        Offset(cx - w / 2 + w * i / 3 + w / 6, base - fh * 0.28),
        fw * 0.035,
        Paint()..color = const Color(0xFFE8506E),
      );
    }
  }

  // ---- Kocaman komik gözlük ----
  void _glasses(Canvas c, Size s, FxFrame f, double fw) {
    if (f.lx == 0 && f.rx == 0) return;
    final l = Offset(f.lx * s.width, f.ly * s.height);
    final r = Offset(f.rx * s.width, f.ry * s.height);
    final radius = fw * 0.22;
    final stroke = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = fw * 0.05;
    final lens = Paint()..color = Colors.white.withValues(alpha: 0.25);
    for (final e in [l, r]) {
      c.drawCircle(e, radius, lens);
      c.drawCircle(e, radius, stroke);
    }
    c.drawLine(l.translate(radius, 0), r.translate(-radius, 0), stroke);
  }

  // ---- Pos bıyık ----
  void _mustache(Canvas c, Size s, FxFrame f, double fw) {
    final nx = f.nx * s.width, ny = f.ny * s.height;
    final paint = Paint()..color = const Color(0xFF3E2723);
    for (final side in [-1, 1]) {
      final path = Path()
        ..moveTo(nx, ny + fw * 0.10)
        ..quadraticBezierTo(
          nx + side * fw * 0.25, ny + fw * 0.02,
          nx + side * fw * 0.42, ny + fw * 0.14,
        )
        ..quadraticBezierTo(
          nx + side * fw * 0.28, ny + fw * 0.26,
          nx, ny + fw * 0.18,
        )
        ..close();
      c.drawPath(path, paint);
    }
  }

  void _whiskers(Canvas c, double nx, double ny, double fw) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = fw * 0.012;
    for (final side in [-1, 1]) {
      for (var i = -1; i <= 1; i++) {
        c.drawLine(
          Offset(nx + side * fw * 0.10, ny + i * fw * 0.03),
          Offset(nx + side * fw * 0.45, ny + i * fw * 0.09),
          p,
        );
      }
    }
  }

  @override
  bool shouldRepaint(EffectPainter old) => old.frame != frame;
}

/// Efekt seçici şeridindeki simgeler.
const effectCatalog = [
  (id: 'none', emoji: '🚫', label: 'Yok'),
  (id: 'bunny', emoji: '🐰', label: 'Tavşan'),
  (id: 'dog', emoji: '🐶', label: 'Köpek'),
  (id: 'crown', emoji: '👑', label: 'Taç'),
  (id: 'glasses', emoji: '🤓', label: 'Gözlük'),
  (id: 'mustache', emoji: '🥸', label: 'Bıyık'),
];

double degToRad(double deg) => deg * math.pi / 180;
