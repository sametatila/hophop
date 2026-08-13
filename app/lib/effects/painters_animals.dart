import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'fx_frame.dart';
import 'painter_util.dart';

/// Hayvan efektleri: kulaklar + burun; bazıları ağız açıklığına tepki verir.
void paintAnimalFx(String id, Canvas c, Size s, FxFrame f, double cx,
    double cy, double fw, double fh, double t) {
  final lm = landmarks(f, s);
  switch (id) {
    case 'bunny':
      _bunny(c, f, lm.n, cx, cy, fw, fh);
    case 'dog':
      _dog(c, f, lm.n, cx, cy, fw, fh);
    case 'cat':
      _cat(c, lm.n, cx, cy, fw, fh);
    case 'bear':
      _bear(c, lm.n, cx, cy, fw, fh);
    case 'fox':
      _fox(c, lm.n, cx, cy, fw, fh);
    case 'panda':
      _panda(c, lm, cx, cy, fw, fh);
    case 'koala':
      _koala(c, lm.n, cx, cy, fw, fh);
    case 'mouse':
      _mouse(c, lm.n, cx, cy, fw, fh);
    case 'tiger':
      _tiger(c, lm.n, cx, cy, fw, fh);
    case 'monkey':
      _monkey(c, lm.n, cx, cy, fw, fh);
    case 'lion':
      _lion(c, lm.n, cx, cy, fw, fh);
    case 'frog':
      _frog(c, f, lm.n, cx, cy, fw, fh);
    case 'deer':
      _deer(c, lm.n, cx, cy, fw, fh);
    case 'chick':
      _chick(c, lm.n, cx, cy, fw, fh);
  }
}

void _whiskers(Canvas c, Offset n, double fw, Color color) {
  final p = ps(color, fw * 0.012);
  for (final side in [-1, 1]) {
    for (var i = -1; i <= 1; i++) {
      c.drawLine(
        Offset(n.dx + side * fw * 0.10, n.dy + i * fw * 0.03),
        Offset(n.dx + side * fw * 0.45, n.dy + i * fw * 0.09),
        p,
      );
    }
  }
}

// ---- Tavşan: beyaz kulaklar + pembe burun + bıyıklar ----
void _bunny(Canvas c, FxFrame f, Offset n, double cx, double cy, double fw,
    double fh) {
  final top = cy - fh * 0.55;
  for (final side in [-1, 1]) {
    final ex = cx + side * fw * 0.22;
    final ear = Rect.fromCenter(
        center: Offset(ex, top - fh * 0.35),
        width: fw * 0.22,
        height: fh * 0.75);
    c.drawOval(ear, pf(Colors.white));
    c.drawOval(ear.deflate(fw * 0.05), pf(const Color(0xFFF8A8C0)));
  }
  final nose = Path()
    ..moveTo(n.dx - fw * 0.07, n.dy - fh * 0.04)
    ..lineTo(n.dx + fw * 0.07, n.dy - fh * 0.04)
    ..lineTo(n.dx, n.dy + fh * 0.05)
    ..close();
  c.drawPath(nose, pf(const Color(0xFFE86A9A)));
  _whiskers(c, n, fw, Colors.white.withValues(alpha: 0.9));
}

// ---- Köpek: kahve kulaklar + siyah burun + ağız açılınca dil ----
void _dog(Canvas c, FxFrame f, Offset n, double cx, double cy, double fw,
    double fh) {
  final brown = pf(const Color(0xFF8B5A2B));
  final top = cy - fh * 0.42;
  for (final side in [-1, 1]) {
    final ear = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(cx + side * fw * 0.42, top + fh * 0.12),
          width: fw * 0.28,
          height: fh * 0.62),
      Radius.circular(fw * 0.14),
    );
    c.drawRRect(ear, brown);
  }
  c.drawOval(
    Rect.fromCenter(center: n, width: fw * 0.24, height: fh * 0.14),
    pf(Colors.black87),
  );
  if (f.mouth > 0.25) {
    final len = fh * (0.15 + 0.35 * f.mouth);
    final tongue = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(n.dx, n.dy + fh * 0.22 + len / 2),
        width: fw * 0.20,
        height: len,
      ),
      Radius.circular(fw * 0.10),
    );
    c.drawRRect(tongue, pf(const Color(0xFFE86A9A)));
    c.drawLine(
      Offset(n.dx, n.dy + fh * 0.26),
      Offset(n.dx, n.dy + fh * 0.22 + len * 0.85),
      ps(const Color(0xFFC94F7C), fw * 0.015),
    );
  }
}

// ---- Kedi: üçgen kulaklar + pembe burun + bıyıklar ----
void _cat(Canvas c, Offset n, double cx, double cy, double fw, double fh) {
  final grey = pf(const Color(0xFF616161));
  final pink = pf(const Color(0xFFF8A8C0));
  final top = cy - fh * 0.42;
  for (final side in [-1, 1]) {
    final bx = cx + side * fw * 0.30;
    Path tri(double inset) => Path()
      ..moveTo(bx - (fw * 0.16 - inset), top + inset * 0.6)
      ..lineTo(bx + side * fw * 0.06, top - fh * 0.30 + inset * 1.6)
      ..lineTo(bx + (fw * 0.16 - inset), top + inset * 0.6)
      ..close();
    c.drawPath(tri(0), grey);
    c.drawPath(tri(fw * 0.05), pink);
  }
  final nose = Path()
    ..moveTo(n.dx - fw * 0.06, n.dy - fh * 0.03)
    ..lineTo(n.dx + fw * 0.06, n.dy - fh * 0.03)
    ..lineTo(n.dx, n.dy + fh * 0.045)
    ..close();
  c.drawPath(nose, pf(const Color(0xFFE86A9A)));
  // Ağız: burnun altında küçük "w"
  final m = ps(const Color(0xFF424242), fw * 0.015);
  final my = n.dy + fh * 0.06;
  final mouth = Path()
    ..moveTo(n.dx - fw * 0.10, my)
    ..quadraticBezierTo(n.dx - fw * 0.05, my + fh * 0.045, n.dx, my)
    ..quadraticBezierTo(n.dx + fw * 0.05, my + fh * 0.045, n.dx + fw * 0.10, my);
  c.drawPath(mouth, m..style = PaintingStyle.stroke);
  _whiskers(c, n, fw, Colors.white.withValues(alpha: 0.85));
}

// ---- Ayı: yuvarlak kulaklar + açık burun çevresi + siyah burun ----
void _bear(Canvas c, Offset n, double cx, double cy, double fw, double fh) {
  final brown = pf(const Color(0xFF795548));
  final light = pf(const Color(0xFFBCAAA4));
  final top = cy - fh * 0.46;
  for (final side in [-1, 1]) {
    final e = Offset(cx + side * fw * 0.34, top);
    c.drawCircle(e, fw * 0.17, brown);
    c.drawCircle(e, fw * 0.10, light);
  }
  c.drawOval(
    Rect.fromCenter(
        center: Offset(n.dx, n.dy + fh * 0.02),
        width: fw * 0.34,
        height: fh * 0.22),
    pf(const Color(0xFFD7CCC8).withValues(alpha: 0.9)),
  );
  c.drawOval(
    Rect.fromCenter(
        center: Offset(n.dx, n.dy - fh * 0.01),
        width: fw * 0.15,
        height: fh * 0.09),
    pf(const Color(0xFF3E2723)),
  );
}

// ---- Tilki: sivri turuncu kulaklar (beyaz iç, koyu uç) + burun ----
void _fox(Canvas c, Offset n, double cx, double cy, double fw, double fh) {
  final orange = pf(const Color(0xFFF57C00));
  final cream = pf(const Color(0xFFFFF3E0));
  final dark = pf(const Color(0xFF4E342E));
  final top = cy - fh * 0.42;
  for (final side in [-1, 1]) {
    final bx = cx + side * fw * 0.30;
    final tip = Offset(bx + side * fw * 0.10, top - fh * 0.42);
    final outer = Path()
      ..moveTo(bx - fw * 0.18, top)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(bx + fw * 0.18, top)
      ..close();
    c.drawPath(outer, orange);
    final innerPath = Path()
      ..moveTo(bx - fw * 0.10, top - fh * 0.01)
      ..lineTo(bx + side * fw * 0.08, top - fh * 0.30)
      ..lineTo(bx + fw * 0.10, top - fh * 0.01)
      ..close();
    c.drawPath(innerPath, cream);
    // Koyu kulak ucu
    final tipPath = Path()
      ..moveTo(tip.dx - fw * 0.055, tip.dy + fh * 0.11)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(tip.dx + fw * 0.055, tip.dy + fh * 0.11)
      ..close();
    c.drawPath(tipPath, dark);
  }
  final nose = Path()
    ..moveTo(n.dx - fw * 0.07, n.dy - fh * 0.035)
    ..lineTo(n.dx + fw * 0.07, n.dy - fh * 0.035)
    ..lineTo(n.dx, n.dy + fh * 0.05)
    ..close();
  c.drawPath(nose, dark);
  _whiskers(c, n, fw, Colors.white.withValues(alpha: 0.75));
}

// ---- Panda: siyah kulaklar + göz lekeleri + burun ----
void _panda(Canvas c, ({Offset l, Offset r, Offset n}) lm, double cx,
    double cy, double fw, double fh) {
  final black = pf(Colors.black87);
  final top = cy - fh * 0.46;
  for (final side in [-1, 1]) {
    c.drawCircle(Offset(cx + side * fw * 0.36, top), fw * 0.16, black);
  }
  for (final e in [lm.l, lm.r]) {
    c.drawOval(
      Rect.fromCenter(
          center: Offset(e.dx, e.dy + fh * 0.01),
          width: fw * 0.20,
          height: fh * 0.16),
      pf(Colors.black.withValues(alpha: 0.72)),
    );
    c.drawCircle(e, fw * 0.035, pf(Colors.white));
  }
  c.drawOval(
    Rect.fromCenter(center: lm.n, width: fw * 0.14, height: fh * 0.08),
    black,
  );
}

// ---- Koala: kocaman gri tüylü kulaklar + iri burun ----
void _koala(Canvas c, Offset n, double cx, double cy, double fw, double fh) {
  final grey = pf(const Color(0xFF90A4AE));
  final light = pf(const Color(0xFFECEFF1));
  final top = cy - fh * 0.34;
  for (final side in [-1, 1]) {
    final e = Offset(cx + side * fw * 0.52, top);
    c.drawCircle(e, fw * 0.24, grey);
    c.drawCircle(e, fw * 0.15, light);
    // Tüy izlenimi: iç kenarda kısa çizgiler
    for (var i = -1; i <= 1; i++) {
      c.drawLine(
        Offset(e.dx - side * fw * 0.10, e.dy + i * fw * 0.07),
        Offset(e.dx - side * fw * 0.20, e.dy + i * fw * 0.10),
        ps(light.color, fw * 0.02),
      );
    }
  }
  c.drawOval(
    Rect.fromCenter(
        center: Offset(n.dx, n.dy - fh * 0.01),
        width: fw * 0.18,
        height: fh * 0.20),
    pf(const Color(0xFF37474F)),
  );
}

// ---- Fare: iri yuvarlak kulaklar (pembe iç) + minik burun ----
void _mouse(Canvas c, Offset n, double cx, double cy, double fw, double fh) {
  final grey = pf(const Color(0xFF9E9E9E));
  final pink = pf(const Color(0xFFF8BBD0));
  final top = cy - fh * 0.52;
  for (final side in [-1, 1]) {
    final e = Offset(cx + side * fw * 0.38, top);
    c.drawCircle(e, fw * 0.20, grey);
    c.drawCircle(e, fw * 0.13, pink);
  }
  c.drawCircle(Offset(n.dx, n.dy), fw * 0.05, pf(const Color(0xFFE86A9A)));
  _whiskers(c, n, fw, Colors.white.withValues(alpha: 0.8));
}

// ---- Kaplan: turuncu kulaklar + yanak çizgileri + burun ----
void _tiger(Canvas c, Offset n, double cx, double cy, double fw, double fh) {
  final orange = pf(const Color(0xFFF57C00));
  final white = pf(Colors.white);
  final black = pf(Colors.black87);
  final top = cy - fh * 0.46;
  for (final side in [-1, 1]) {
    final e = Offset(cx + side * fw * 0.34, top);
    c.drawCircle(e, fw * 0.15, orange);
    c.drawCircle(e, fw * 0.09, white);
  }
  // Yanak çizgileri: her yanda üç incelen üçgen
  for (final side in [-1, 1]) {
    for (var i = 0; i < 3; i++) {
      final y = cy - fh * 0.06 + i * fh * 0.11;
      final x0 = cx + side * fw * 0.50;
      final stripe = Path()
        ..moveTo(x0, y - fh * 0.030)
        ..lineTo(x0 - side * fw * (0.20 - i * 0.03), y)
        ..lineTo(x0, y + fh * 0.030)
        ..close();
      c.drawPath(stripe, black);
    }
  }
  // Alın çizgisi
  final fy = cy - fh * 0.34;
  final fstripe = Path()
    ..moveTo(cx - fw * 0.03, fy - fh * 0.09)
    ..lineTo(cx, fy + fh * 0.05)
    ..lineTo(cx + fw * 0.03, fy - fh * 0.09)
    ..close();
  c.drawPath(fstripe, black);
  final nose = Path()
    ..moveTo(n.dx - fw * 0.07, n.dy - fh * 0.035)
    ..lineTo(n.dx + fw * 0.07, n.dy - fh * 0.035)
    ..lineTo(n.dx, n.dy + fh * 0.05)
    ..close();
  c.drawPath(nose, pf(const Color(0xFF6D4C41)));
}

// ---- Maymun: yandan iri ten rengi kulaklar + ağız çevresi ----
void _monkey(Canvas c, Offset n, double cx, double cy, double fw, double fh) {
  final brown = pf(const Color(0xFF6D4C41));
  final tan = pf(const Color(0xFFD7B899));
  for (final side in [-1, 1]) {
    final e = Offset(cx + side * fw * 0.55, cy - fh * 0.10);
    c.drawCircle(e, fw * 0.16, brown);
    c.drawCircle(e, fw * 0.10, tan);
  }
  c.drawOval(
    Rect.fromCenter(
        center: Offset(n.dx, n.dy + fh * 0.05),
        width: fw * 0.36,
        height: fh * 0.26),
    pf(const Color(0xFFD7B899).withValues(alpha: 0.9)),
  );
  for (final side in [-1, 1]) {
    c.drawCircle(Offset(n.dx + side * fw * 0.045, n.dy - fh * 0.005),
        fw * 0.022, brown);
  }
  final smile = Path()
    ..moveTo(n.dx - fw * 0.10, n.dy + fh * 0.09)
    ..quadraticBezierTo(
        n.dx, n.dy + fh * 0.15, n.dx + fw * 0.10, n.dy + fh * 0.09);
  c.drawPath(smile, ps(const Color(0xFF5D4037), fw * 0.02));
  // Tepe tutamı
  final tuft = Path()
    ..moveTo(cx - fw * 0.05, cy - fh * 0.46)
    ..quadraticBezierTo(cx, cy - fh * 0.62, cx + fw * 0.07, cy - fh * 0.47);
  c.drawPath(tuft, ps(const Color(0xFF6D4C41), fw * 0.035));
}

// ---- Aslan: yele halkası + kulaklar + burun ----
void _lion(Canvas c, Offset n, double cx, double cy, double fw, double fh) {
  final mane = pf(const Color(0xFFE0862E).withValues(alpha: 0.92));
  // Yele: yüzü çevreleyen yaprak dilimleri
  const petals = 14;
  for (var i = 0; i < petals; i++) {
    final a = i * 2 * 3.14159 / petals;
    final rx = fw * 0.62, ry = fh * 0.60;
    final base =
        Offset(cx + rx * 0.92 * math.cos(a), cy + ry * 0.92 * math.sin(a));
    final tip =
        Offset(cx + rx * 1.24 * math.cos(a), cy + ry * 1.24 * math.sin(a));
    final perp = Offset(-math.sin(a), math.cos(a));
    final w = fw * 0.11;
    final petal = Path()
      ..moveTo(base.dx + perp.dx * w, base.dy + perp.dy * w)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(base.dx - perp.dx * w, base.dy - perp.dy * w)
      ..close();
    c.drawPath(petal, mane);
  }
  final gold = pf(const Color(0xFFF2A65A));
  final top = cy - fh * 0.48;
  for (final side in [-1, 1]) {
    final e = Offset(cx + side * fw * 0.32, top);
    c.drawCircle(e, fw * 0.12, gold);
    c.drawCircle(e, fw * 0.07, pf(const Color(0xFFFFE0B2)));
  }
  final nose = Path()
    ..moveTo(n.dx - fw * 0.08, n.dy - fh * 0.04)
    ..lineTo(n.dx + fw * 0.08, n.dy - fh * 0.04)
    ..lineTo(n.dx, n.dy + fh * 0.05)
    ..close();
  c.drawPath(nose, pf(const Color(0xFF5D4037)));
  _whiskers(c, n, fw, Colors.white.withValues(alpha: 0.6));
}

// ---- Kurbağa: tepede patlak gözler + ağız açılınca uzun dil ----
void _frog(Canvas c, FxFrame f, Offset n, double cx, double cy, double fw,
    double fh) {
  final green = pf(const Color(0xFF66BB6A));
  final top = cy - fh * 0.52;
  for (final side in [-1, 1]) {
    final e = Offset(cx + side * fw * 0.24, top);
    c.drawCircle(e, fw * 0.15, green);
    c.drawCircle(Offset(e.dx, e.dy - fh * 0.015), fw * 0.10, pf(Colors.white));
    c.drawCircle(Offset(e.dx, e.dy - fh * 0.015), fw * 0.05, pf(Colors.black87));
  }
  // Burun delikleri
  for (final side in [-1, 1]) {
    c.drawCircle(Offset(n.dx + side * fw * 0.05, n.dy), fw * 0.02,
        pf(const Color(0xFF2E7D32)));
  }
  if (f.mouth > 0.25) {
    // İnce uzun kurbağa dili + uçta topak
    final len = fh * (0.25 + 0.45 * f.mouth);
    final tipY = n.dy + fh * 0.22 + len;
    c.drawLine(Offset(n.dx, n.dy + fh * 0.20), Offset(n.dx, tipY),
        ps(const Color(0xFFE57373), fw * 0.07));
    c.drawCircle(Offset(n.dx, tipY), fw * 0.065, pf(const Color(0xFFE57373)));
  }
}

// ---- Geyik: dallı boynuzlar + kulaklar + burun ----
void _deer(Canvas c, Offset n, double cx, double cy, double fw, double fh) {
  final antler = ps(const Color(0xFF8D6E63), fw * 0.045);
  final top = cy - fh * 0.48;
  for (final side in [-1, 1]) {
    final bx = cx + side * fw * 0.26;
    final main = Path()
      ..moveTo(bx, top)
      ..quadraticBezierTo(bx + side * fw * 0.10, top - fh * 0.30,
          bx + side * fw * 0.24, top - fh * 0.50);
    c.drawPath(main, antler);
    // Dallar
    final b1 = Path()
      ..moveTo(bx + side * fw * 0.045, top - fh * 0.17)
      ..quadraticBezierTo(bx - side * fw * 0.02, top - fh * 0.28,
          bx - side * fw * 0.045, top - fh * 0.38);
    c.drawPath(b1, antler);
    final b2 = Path()
      ..moveTo(bx + side * fw * 0.13, top - fh * 0.33)
      ..quadraticBezierTo(bx + side * fw * 0.30, top - fh * 0.40,
          bx + side * fw * 0.36, top - fh * 0.36);
    c.drawPath(b2, antler);
    // Kulak
    c.drawOval(
      Rect.fromCenter(
          center: Offset(cx + side * fw * 0.46, top + fh * 0.10),
          width: fw * 0.20,
          height: fh * 0.13),
      pf(const Color(0xFFA1887F)),
    );
  }
  c.drawOval(
    Rect.fromCenter(center: n, width: fw * 0.13, height: fh * 0.08),
    pf(const Color(0xFF4E342E)),
  );
}

// ---- Civciv: sarı tüy sorgucu + turuncu gaga + pembe yanaklar ----
void _chick(Canvas c, Offset n, double cx, double cy, double fw, double fh) {
  final yellow = pf(const Color(0xFFFFEB3B));
  final top = cy - fh * 0.50;
  // Tepe tüyleri: üç yaprak
  for (var i = -1; i <= 1; i++) {
    c.drawOval(
      Rect.fromCenter(
          center: Offset(cx + i * fw * 0.11, top - fh * 0.06 - (1 - i.abs()) * fh * 0.05),
          width: fw * 0.11,
          height: fh * 0.20),
      yellow,
    );
  }
  // Gaga: üst + alt üçgen
  final beakTop = Path()
    ..moveTo(n.dx - fw * 0.10, n.dy - fh * 0.02)
    ..lineTo(n.dx + fw * 0.10, n.dy - fh * 0.02)
    ..lineTo(n.dx, n.dy + fh * 0.06)
    ..close();
  c.drawPath(beakTop, pf(const Color(0xFFFF9800)));
  final beakBottom = Path()
    ..moveTo(n.dx - fw * 0.06, n.dy + fh * 0.055)
    ..lineTo(n.dx + fw * 0.06, n.dy + fh * 0.055)
    ..lineTo(n.dx, n.dy + fh * 0.10)
    ..close();
  c.drawPath(beakBottom, pf(const Color(0xFFF57C00)));
  // Pembe yanaklar
  for (final side in [-1, 1]) {
    c.drawCircle(Offset(cx + side * fw * 0.30, cy + fh * 0.06), fw * 0.075,
        pf(const Color(0xFFF8BBD0).withValues(alpha: 0.75)));
  }
}
