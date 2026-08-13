import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'fx_frame.dart';
import 'painter_util.dart';

/// Şapka/taç efektleri — başın üstüne oturur; birkaçı zamanla oynar
/// (pervane döner, melek halkası ışıldar, mezuniyet püskülü sallanır).
void paintHatFx(String id, Canvas c, Size s, FxFrame f, double cx, double cy,
    double fw, double fh, double t) {
  switch (id) {
    case 'crown':
      _crown(c, cx, cy, fw, fh);
    case 'fcrown':
      _flowerCrown(c, cx, cy, fw, fh);
    case 'party':
      _party(c, cx, cy, fw, fh);
    case 'wizard':
      _wizard(c, cx, cy, fw, fh);
    case 'chef':
      _chef(c, cx, cy, fw, fh);
    case 'pirate':
      _pirate(c, cx, cy, fw, fh);
    case 'halo':
      _halo(c, cx, cy, fw, fh, t);
    case 'grad':
      _grad(c, cx, cy, fw, fh, t);
    case 'cowboy':
      _cowboy(c, cx, cy, fw, fh);
    case 'prop':
      _propeller(c, cx, cy, fw, fh, t);
    case 'beanie':
      _beanie(c, cx, cy, fw, fh);
    case 'unicorn':
      _unicorn(c, cx, cy, fw, fh);
  }
}

// ---- Altın taç ----
void _crown(Canvas c, double cx, double cy, double fw, double fh) {
  final gold = pf(const Color(0xFFFFC93C));
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
      pf(const Color(0xFFE8506E)),
    );
  }
}

// ---- Çiçek taç ----
void _flowerCrown(Canvas c, double cx, double cy, double fw, double fh) {
  final base = cy - fh * 0.46;
  const colors = [
    Color(0xFFF48FB1),
    Color(0xFFFFF59D),
    Color(0xFFFFFFFF),
    Color(0xFFFFF59D),
    Color(0xFFF48FB1),
  ];
  // Yapraklar: çiçeklerin arasına yeşil elipsler
  for (var i = 0; i < 4; i++) {
    final x = cx + (i - 1.5) * fw * 0.19;
    c.drawOval(
      Rect.fromCenter(
          center: Offset(x, base - fh * 0.02),
          width: fw * 0.12,
          height: fw * 0.05),
      pf(const Color(0xFF81C784)),
    );
  }
  for (var i = 0; i < 5; i++) {
    final k = i - 2;
    final x = cx + k * fw * 0.19;
    final y = base - fh * 0.055 * (1 - (k * k) / 5.0);
    drawFlower(c, Offset(x, y), fw * 0.085, colors[i],
        const Color(0xFFFFB300));
  }
}

// ---- Parti şapkası ----
void _party(Canvas c, double cx, double cy, double fw, double fh) {
  final base = cy - fh * 0.52;
  final apex = Offset(cx, cy - fh * 1.02);
  final cone = Path()
    ..moveTo(cx - fw * 0.26, base)
    ..lineTo(apex.dx, apex.dy)
    ..lineTo(cx + fw * 0.26, base)
    ..close();
  c.drawPath(cone, pf(const Color(0xFFFF6FA5)));
  // Puanlar
  c.save();
  c.clipPath(cone);
  for (final (dx, dy) in [(-0.10, 0.10), (0.08, 0.22), (-0.03, 0.34), (0.12, 0.42), (-0.14, 0.44)]) {
    c.drawCircle(Offset(cx + fw * dx, apex.dy + fh * dy), fw * 0.035,
        pf(Colors.white.withValues(alpha: 0.9)));
  }
  c.restore();
  c.drawCircle(apex, fw * 0.06, pf(const Color(0xFFFFC93C)));
}

// ---- Büyücü şapkası ----
void _wizard(Canvas c, double cx, double cy, double fw, double fh) {
  final purple = pf(const Color(0xFF7C4DFF));
  final base = cy - fh * 0.52;
  // Kenar
  c.drawOval(
    Rect.fromCenter(
        center: Offset(cx, base), width: fw * 0.88, height: fh * 0.16),
    purple,
  );
  // Hafif kıvrık koni
  final cone = Path()
    ..moveTo(cx - fw * 0.28, base)
    ..quadraticBezierTo(cx - fw * 0.16, cy - fh * 0.85, cx + fw * 0.04,
        cy - fh * 1.12)
    ..quadraticBezierTo(cx + fw * 0.10, cy - fh * 0.82, cx + fw * 0.28, base)
    ..close();
  c.drawPath(cone, purple);
  // Bant
  c.drawRect(
    Rect.fromCenter(
        center: Offset(cx, base - fh * 0.05), width: fw * 0.52, height: fh * 0.07),
    pf(const Color(0xFFFFC93C)),
  );
  // Yıldızlar + ay
  c.drawPath(starPath(Offset(cx - fw * 0.07, base - fh * 0.24), fw * 0.045),
      pf(const Color(0xFFFFF59D)));
  c.drawPath(starPath(Offset(cx + fw * 0.09, base - fh * 0.38), fw * 0.035),
      pf(const Color(0xFFFFF59D)));
  final moon = Path()
    ..addOval(Rect.fromCircle(
        center: Offset(cx - fw * 0.01, base - fh * 0.50), radius: fw * 0.045))
    ..addOval(Rect.fromCircle(
        center: Offset(cx + fw * 0.015, base - fh * 0.515), radius: fw * 0.038));
  moon.fillType = PathFillType.evenOdd;
  c.drawPath(moon, pf(const Color(0xFFFFF59D)));
}

// ---- Aşçı şapkası ----
void _chef(Canvas c, double cx, double cy, double fw, double fh) {
  final white = pf(Colors.white);
  final shade = pf(const Color(0xFFE0E0E0));
  final base = cy - fh * 0.50;
  // Kabarık üst: üç top
  for (final (dx, dy, r) in [(-0.20, 0.16, 0.16), (0.20, 0.16, 0.16), (0.0, 0.26, 0.20)]) {
    c.drawCircle(Offset(cx + fw * dx, base - fh * dy), fw * r, white);
  }
  // Bant
  final band = RRect.fromRectAndRadius(
    Rect.fromCenter(
        center: Offset(cx, base), width: fw * 0.62, height: fh * 0.14),
    Radius.circular(fw * 0.03),
  );
  c.drawRRect(band, white);
  c.drawLine(Offset(cx - fw * 0.31, base + fh * 0.07),
      Offset(cx + fw * 0.31, base + fh * 0.07), ps(shade.color, fw * 0.015));
}

// ---- Korsan şapkası ----
void _pirate(Canvas c, double cx, double cy, double fw, double fh) {
  final black = pf(const Color(0xFF263238));
  final base = cy - fh * 0.50;
  final hat = Path()
    ..moveTo(cx - fw * 0.58, base)
    ..quadraticBezierTo(cx - fw * 0.42, base - fh * 0.40, cx, base - fh * 0.46)
    ..quadraticBezierTo(cx + fw * 0.42, base - fh * 0.40, cx + fw * 0.58, base)
    ..quadraticBezierTo(cx + fw * 0.30, base - fh * 0.10, cx, base - fh * 0.08)
    ..quadraticBezierTo(cx - fw * 0.30, base - fh * 0.10, cx - fw * 0.58, base)
    ..close();
  c.drawPath(hat, black);
  // Kırmızı şerit kenar
  c.drawPath(
      Path()
        ..moveTo(cx - fw * 0.58, base)
        ..quadraticBezierTo(cx - fw * 0.30, base - fh * 0.10, cx, base - fh * 0.08)
        ..quadraticBezierTo(cx + fw * 0.30, base - fh * 0.10, cx + fw * 0.58, base),
      ps(const Color(0xFFC62839), fw * 0.025));
  // Kurukafa (sevimli)
  final skull = Offset(cx, base - fh * 0.24);
  c.drawCircle(skull, fw * 0.075, pf(Colors.white));
  c.drawCircle(Offset(skull.dx - fw * 0.028, skull.dy - fh * 0.008),
      fw * 0.018, black);
  c.drawCircle(Offset(skull.dx + fw * 0.028, skull.dy - fh * 0.008),
      fw * 0.018, black);
  // Çapraz kemikler
  final bone = ps(Colors.white, fw * 0.02);
  c.drawLine(Offset(skull.dx - fw * 0.09, skull.dy + fh * 0.06),
      Offset(skull.dx + fw * 0.09, skull.dy - fh * 0.005), bone);
  c.drawLine(Offset(skull.dx + fw * 0.09, skull.dy + fh * 0.06),
      Offset(skull.dx - fw * 0.09, skull.dy - fh * 0.005), bone);
}

// ---- Melek halkası (ışıldar) ----
void _halo(Canvas c, double cx, double cy, double fw, double fh, double t) {
  final center = Offset(cx, cy - fh * 0.80);
  final rect = Rect.fromCenter(
      center: center, width: fw * 0.56, height: fh * 0.14);
  final pulse = 0.35 + 0.25 * math.sin(t * 3);
  // Işıma
  c.drawOval(
      rect.inflate(fw * 0.04),
      Paint()
        ..color = const Color(0xFFFFF176).withValues(alpha: pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = fw * 0.09
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, fw * 0.05));
  c.drawOval(rect, ps(const Color(0xFFFFD54F), fw * 0.045));
}

// ---- Mezuniyet kepi (püskül sallanır) ----
void _grad(Canvas c, double cx, double cy, double fw, double fh, double t) {
  final black = pf(const Color(0xFF212121));
  final base = cy - fh * 0.54;
  // Kafa bandı
  c.drawOval(
    Rect.fromCenter(
        center: Offset(cx, base), width: fw * 0.60, height: fh * 0.18),
    pf(const Color(0xFF37474F)),
  );
  // Tabla (elmas)
  final board = Path()
    ..moveTo(cx - fw * 0.56, base - fh * 0.10)
    ..lineTo(cx, base - fh * 0.26)
    ..lineTo(cx + fw * 0.56, base - fh * 0.10)
    ..lineTo(cx, base + fh * 0.02)
    ..close();
  c.drawPath(board, black);
  // Düğme + püskül
  final knob = Offset(cx, base - fh * 0.12);
  c.drawCircle(knob, fw * 0.025, pf(const Color(0xFFFFC93C)));
  final sway = math.sin(t * 2.2) * fw * 0.04;
  final tip = Offset(cx + fw * 0.46 + sway, base + fh * 0.10);
  final cord = Path()
    ..moveTo(knob.dx, knob.dy)
    ..quadraticBezierTo(cx + fw * 0.30, base - fh * 0.16, tip.dx, tip.dy);
  c.drawPath(cord, ps(const Color(0xFFFFC93C), fw * 0.02));
  for (var i = -1; i <= 1; i++) {
    c.drawLine(tip, Offset(tip.dx + i * fw * 0.025, tip.dy + fh * 0.08),
        ps(const Color(0xFFFFC93C), fw * 0.018));
  }
}

// ---- Kovboy şapkası ----
void _cowboy(Canvas c, double cx, double cy, double fw, double fh) {
  final brown = pf(const Color(0xFFA0662B));
  final dark = pf(const Color(0xFF6D4419));
  final base = cy - fh * 0.52;
  // Kenar: uçları kıvrık geniş elips
  final brim = Path()
    ..moveTo(cx - fw * 0.60, base - fh * 0.06)
    ..quadraticBezierTo(cx - fw * 0.55, base + fh * 0.10, cx - fw * 0.25, base + fh * 0.08)
    ..quadraticBezierTo(cx, base + fh * 0.12, cx + fw * 0.25, base + fh * 0.08)
    ..quadraticBezierTo(cx + fw * 0.55, base + fh * 0.10, cx + fw * 0.60, base - fh * 0.06)
    ..quadraticBezierTo(cx + fw * 0.35, base - fh * 0.02, cx, base - fh * 0.02)
    ..quadraticBezierTo(cx - fw * 0.35, base - fh * 0.02, cx - fw * 0.60, base - fh * 0.06)
    ..close();
  c.drawPath(brim, brown);
  // Tepe
  final dome = Path()
    ..moveTo(cx - fw * 0.26, base)
    ..quadraticBezierTo(cx - fw * 0.28, base - fh * 0.36, cx - fw * 0.08, base - fh * 0.38)
    ..quadraticBezierTo(cx, base - fh * 0.32, cx + fw * 0.08, base - fh * 0.38)
    ..quadraticBezierTo(cx + fw * 0.28, base - fh * 0.36, cx + fw * 0.26, base)
    ..close();
  c.drawPath(dome, brown);
  // Bant
  c.drawRect(
    Rect.fromCenter(
        center: Offset(cx, base - fh * 0.045), width: fw * 0.50, height: fh * 0.06),
    dark,
  );
}

// ---- Pervaneli şapka (pervane döner) ----
void _propeller(Canvas c, double cx, double cy, double fw, double fh, double t) {
  final base = cy - fh * 0.50;
  final dome = Path()
    ..moveTo(cx - fw * 0.34, base)
    ..arcToPoint(Offset(cx + fw * 0.34, base),
        radius: Radius.circular(fw * 0.36))
    ..close();
  // Renkli dilimler
  c.save();
  c.clipPath(dome);
  const cols = [Color(0xFFE85D5D), Color(0xFFFFC93C), Color(0xFF4FC3F7), Color(0xFF69F0AE)];
  for (var i = 0; i < 4; i++) {
    c.drawRect(
      Rect.fromLTWH(cx - fw * 0.34 + i * fw * 0.17, base - fh * 0.40,
          fw * 0.17, fh * 0.40),
      pf(cols[i]),
    );
  }
  c.restore();
  // Sap + göbek
  final hub = Offset(cx, base - fh * 0.42);
  c.drawLine(Offset(cx, base - fh * 0.33), hub, ps(const Color(0xFF616161), fw * 0.03));
  // Dönen kanatlar
  final a = t * 9;
  for (final (angle, color) in [(a, const Color(0xFFFFD54F)), (a + math.pi / 2, const Color(0xFF4FC3F7))]) {
    c.save();
    c.translate(hub.dx, hub.dy);
    c.rotate(angle);
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: fw * 0.52, height: fw * 0.09),
      pf(color.withValues(alpha: 0.95)),
    );
    c.restore();
  }
  c.drawCircle(hub, fw * 0.035, pf(const Color(0xFF616161)));
}

// ---- Ponponlu bere ----
void _beanie(Canvas c, double cx, double cy, double fw, double fh) {
  final base = cy - fh * 0.46;
  final orange = pf(const Color(0xFFFF7043));
  final dome = Path()
    ..moveTo(cx - fw * 0.38, base)
    ..arcToPoint(Offset(cx + fw * 0.38, base),
        radius: Radius.circular(fw * 0.40))
    ..close();
  c.drawPath(dome, orange);
  // Örgü izleri
  c.save();
  c.clipPath(dome);
  for (var i = -2; i <= 2; i++) {
    final x = cx + i * fw * 0.14;
    c.drawLine(Offset(x, base), Offset(cx + i * fw * 0.05, base - fh * 0.42),
        ps(const Color(0xFFE64A19), fw * 0.02));
  }
  c.restore();
  // Katlama bandı
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(cx, base), width: fw * 0.80, height: fh * 0.14),
      Radius.circular(fw * 0.05),
    ),
    pf(const Color(0xFFFF8A65)),
  );
  // Ponpon
  c.drawCircle(Offset(cx, base - fh * 0.44), fw * 0.08, pf(Colors.white));
}

// ---- Tek boynuz ----
void _unicorn(Canvas c, double cx, double cy, double fw, double fh) {
  final base = cy - fh * 0.50;
  // Kulaklar
  for (final side in [-1, 1]) {
    final bx = cx + side * fw * 0.26;
    final ear = Path()
      ..moveTo(bx - fw * 0.09, base + fh * 0.02)
      ..lineTo(bx + side * fw * 0.03, base - fh * 0.20)
      ..lineTo(bx + fw * 0.09, base + fh * 0.02)
      ..close();
    c.drawPath(ear, pf(Colors.white));
    final inner = Path()
      ..moveTo(bx - fw * 0.045, base + fh * 0.01)
      ..lineTo(bx + side * fw * 0.02, base - fh * 0.13)
      ..lineTo(bx + fw * 0.045, base + fh * 0.01)
      ..close();
    c.drawPath(inner, pf(const Color(0xFFF8BBD0)));
  }
  // Boynuz
  final horn = Path()
    ..moveTo(cx - fw * 0.065, base)
    ..lineTo(cx, base - fh * 0.52)
    ..lineTo(cx + fw * 0.065, base)
    ..close();
  c.drawPath(horn, pf(const Color(0xFFFFD54F)));
  // Spiral çizgiler
  c.save();
  c.clipPath(horn);
  for (var i = 1; i <= 3; i++) {
    final y = base - fh * 0.13 * i;
    c.drawLine(Offset(cx - fw * 0.07, y + fh * 0.03),
        Offset(cx + fw * 0.07, y - fh * 0.02), ps(const Color(0xFFF9A825), fw * 0.018));
  }
  c.restore();
  // Boynuz dibinde minik çiçekler
  drawFlower(c, Offset(cx - fw * 0.12, base + fh * 0.015), fw * 0.05,
      const Color(0xFFF48FB1), const Color(0xFFFFB300));
  drawFlower(c, Offset(cx + fw * 0.12, base + fh * 0.015), fw * 0.05,
      const Color(0xFF90CAF9), const Color(0xFFFFB300));
}
