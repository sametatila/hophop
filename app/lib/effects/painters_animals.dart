import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'fx_frame.dart';
import 'painter_util.dart';

/// Hayvan efektleri — kulaklar kafa uzayında (kafayla döner/eğilir),
/// burun/ağız parçaları kontur çapalarına oturur. Hepsi degrade + yumuşak
/// gölge ile hacimli çizilir; çoğu ağza, bazıları gülümsemeye tepki verir.
void paintAnimalFx(
    String id, Canvas c, Size s, FaceGeom g, double t) {
  withHead(c, g, () {
    switch (id) {
      case 'bunny':
        _bunny(c, g, t);
      case 'dog':
        _dog(c, g, t);
      case 'cat':
        _cat(c, g, t);
      case 'bear':
        _bear(c, g);
      case 'fox':
        _fox(c, g);
      case 'panda':
        _panda(c, g);
      case 'koala':
        _koala(c, g);
      case 'mouse':
        _mouse(c, g, t);
      case 'tiger':
        _tiger(c, g);
      case 'monkey':
        _monkey(c, g);
      case 'lion':
        _lion(c, g, t);
      case 'frog':
        _frog(c, g, t);
      case 'deer':
        _deer(c, g);
      case 'chick':
        _chick(c, g, t);
    }
  });
}

// ---- Ortak parçalar ----

/// Kafanın tepe orta noktası (kafa uzayında).
Offset _headTop(FaceGeom g) => g.derolled(P.oval);

/// Damla biçimli kulak: taban→uç, degrade dolgu + yumuşak gölge + iç kulak.
void _ear(Canvas c, Offset base, Offset tip, double width,
    {required Color light,
    required Color dark,
    Color? inner,
    double innerScale = 0.55}) {
  final dir = tip - base;
  final len = dir.distance;
  if (len < 1) return;
  final u = dir / len;
  final n = Offset(-u.dy, u.dx);
  Path shape(double w, double l) {
    final b = base + u * (len - l);
    final tp = b + u * l;
    return Path()
      ..moveTo(b.dx - n.dx * w, b.dy - n.dy * w)
      ..cubicTo(
          b.dx - n.dx * w * 1.15 + u.dx * l * 0.45,
          b.dy - n.dy * w * 1.15 + u.dy * l * 0.45,
          tp.dx - n.dx * w * 0.35,
          tp.dy - n.dy * w * 0.35,
          tp.dx, tp.dy)
      ..cubicTo(
          tp.dx + n.dx * w * 0.35,
          tp.dy + n.dy * w * 0.35,
          b.dx + n.dx * w * 1.15 + u.dx * l * 0.45,
          b.dy + n.dy * w * 1.15 + u.dy * l * 0.45,
          b.dx + n.dx * w, b.dy + n.dy * w)
      ..close();
  }

  final outer = shape(width, len);
  softShadow(c, outer, width * 0.35);
  c.drawPath(
      outer,
      pgrad(outer.getBounds(), [light, dark],
          begin: Alignment.topCenter, end: Alignment.bottomCenter));
  if (inner != null) {
    final ip = shape(width * innerScale, len * 0.72);
    c.drawPath(
        ip,
        Paint()
          ..color = inner
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.12));
  }
}

/// Yüze karışan yumuşak kenarlı leke (ağız çevresi, göz lekesi).
void _patch(Canvas c, Offset center, double w, double h, Color color) {
  c.drawOval(
    Rect.fromCenter(center: center, width: w, height: h),
    Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.min(w, h) * 0.16),
  );
}

/// Parlak hayvan burnu: gölge + degrade + ışık beneği.
void _snout(Canvas c, Offset n, double w, double h, Color light, Color dark) {
  final r = Rect.fromCenter(center: n, width: w, height: h);
  final p = Path()
    ..moveTo(r.left, r.top + h * 0.18)
    ..quadraticBezierTo(r.center.dx, r.top - h * 0.22, r.right, r.top + h * 0.18)
    ..quadraticBezierTo(r.right, r.center.dy + h * 0.1, r.center.dx, r.bottom)
    ..quadraticBezierTo(r.left, r.center.dy + h * 0.1, r.left, r.top + h * 0.18)
    ..close();
  softShadow(c, p, h * 0.18, offset: Offset(0, h * 0.08));
  c.drawPath(p, pgrad(r, [light, dark]));
  c.drawCircle(Offset(n.dx - w * 0.18, n.dy - h * 0.18), w * 0.10,
      pf(Colors.white.withValues(alpha: 0.85)));
}

void _whiskers(Canvas c, FaceGeom g, Color color) {
  final n = g.derolled(P.noseBotC);
  final fw = g.fw;
  final p = ps(color, fw * 0.010);
  for (final side in [-1, 1]) {
    for (var i = -1; i <= 1; i++) {
      final y0 = n.dy + i * fw * 0.035;
      final path = Path()
        ..moveTo(n.dx + side * fw * 0.10, y0)
        ..quadraticBezierTo(n.dx + side * fw * 0.28, y0 + i * fw * 0.01,
            n.dx + side * fw * 0.46, y0 + i * fw * 0.055);
      c.drawPath(path, p);
    }
  }
}

/// Ağız açılınca dil: degrade + orta çizgi + gölge; ucu hafif sallanır.
void _tongue(Canvas c, FaceGeom g, double t, {double wf = 0.20}) {
  if (g.mouth < 0.2) return;
  final m = g.derolled(P.lipInB);
  final len = g.fh * (0.10 + 0.34 * g.mouth);
  final w = g.fw * wf;
  final sway = math.sin(t * 6) * w * 0.06 * g.mouth;
  final p = Path()
    ..moveTo(m.dx - w / 2, m.dy)
    ..cubicTo(m.dx - w / 2, m.dy + len * 0.7, m.dx - w * 0.42 + sway,
        m.dy + len, m.dx + sway, m.dy + len)
    ..cubicTo(m.dx + w * 0.42 + sway, m.dy + len, m.dx + w / 2,
        m.dy + len * 0.7, m.dx + w / 2, m.dy)
    ..close();
  softShadow(c, p, w * 0.15, offset: Offset(0, w * 0.08));
  c.drawPath(
      p,
      pgrad(p.getBounds(),
          [const Color(0xFFFF8FB3), const Color(0xFFE2557F)]));
  c.drawLine(Offset(m.dx, m.dy + len * 0.15),
      Offset(m.dx + sway * 0.8, m.dy + len * 0.82),
      ps(const Color(0xFFC94F7C), w * 0.07));
  gloss(c, Offset(m.dx - w * 0.15, m.dy + len * 0.3), w * 0.3, len * 0.25,
      alpha: 0.35);
}

// ---- Tavşan ----
void _bunny(Canvas c, FaceGeom g, double t) {
  final top = _headTop(g);
  final fw = g.fw, fh = g.fh;
  final flop = math.sin(t * 2.2) * 0.05; // kulaklar hafif salınır
  for (final side in [-1, 1]) {
    final base = Offset(top.dx + side * fw * 0.22, top.dy + fh * 0.06);
    final tip = Offset(
        top.dx + side * fw * (0.30 + flop * side), top.dy - fh * 0.78);
    _ear(c, base, tip, fw * 0.13,
        light: Colors.white,
        dark: const Color(0xFFE8E0DC),
        inner: const Color(0xFFF8A8C0));
  }
  final n = g.derolled(P.noseBotC);
  final nose = Path()
    ..moveTo(n.dx - fw * 0.07, n.dy - fh * 0.045)
    ..quadraticBezierTo(n.dx, n.dy - fh * 0.06, n.dx + fw * 0.07, n.dy - fh * 0.045)
    ..quadraticBezierTo(n.dx + fw * 0.05, n.dy + fh * 0.02, n.dx, n.dy + fh * 0.05)
    ..quadraticBezierTo(n.dx - fw * 0.05, n.dy + fh * 0.02, n.dx - fw * 0.07, n.dy - fh * 0.045)
    ..close();
  c.drawPath(nose,
      pgrad(nose.getBounds(), [const Color(0xFFFF9EC0), const Color(0xFFE2557F)]));
  // Ön dişler
  if (g.mouth > 0.15) {
    final m = g.derolled(P.lipInT);
    for (final side in [-1, 1]) {
      final tooth = RRect.fromRectAndRadius(
          Rect.fromLTWH(m.dx + (side == -1 ? -fw * 0.055 : 0), m.dy,
              fw * 0.055, fh * 0.07 * g.mouth.clamp(0.3, 1.0)),
          Radius.circular(fw * 0.015));
      c.drawRRect(tooth, pf(Colors.white));
      c.drawRRect(tooth, ps(const Color(0xFFD9D2CC), fw * 0.006));
    }
  }
  _whiskers(c, g, Colors.white.withValues(alpha: 0.9));
}

// ---- Köpek ----
void _dog(Canvas c, FaceGeom g, double t) {
  final fw = g.fw, fh = g.fh;
  final top = _headTop(g);
  // Sarkık kulaklar: tepe yanından aşağı, gülümseyince hafif havalanır.
  final lift = g.smile * fh * 0.06;
  for (final side in [-1, 1]) {
    final base = Offset(top.dx + side * fw * 0.40, top.dy + fh * 0.10);
    final tip = Offset(top.dx + side * fw * 0.52,
        top.dy + fh * 0.62 - lift + math.sin(t * 3 + side) * fh * 0.015);
    _ear(c, base, tip, fw * 0.15,
        light: const Color(0xFFA9764A),
        dark: const Color(0xFF6D4426),
        inner: const Color(0xFF8B5A2B),
        innerScale: 0.45);
  }
  _patch(c, g.derolled(P.noseBotC).translate(0, fh * 0.03), fw * 0.42,
      fh * 0.30, const Color(0xFFD7B899).withValues(alpha: 0.55));
  _snout(c, g.derolled(P.noseBotC), fw * 0.26, fh * 0.16,
      const Color(0xFF4A4A4A), Colors.black);
  _tongue(c, g, t);
}

// ---- Kedi ----
void _cat(Canvas c, FaceGeom g, double t) {
  final fw = g.fw, fh = g.fh;
  final top = _headTop(g);
  for (final side in [-1, 1]) {
    final bx = top.dx + side * fw * 0.30;
    final base = Offset(bx, top.dy + fh * 0.08);
    final tip = Offset(bx + side * fw * 0.10, top.dy - fh * 0.34);
    // Üçgen kulak: degrade gri + pembe iç
    final tri = Path()
      ..moveTo(base.dx - side * fw * 0.16, base.dy)
      ..quadraticBezierTo(base.dx - side * fw * 0.10, base.dy - fh * 0.22,
          tip.dx, tip.dy)
      ..quadraticBezierTo(base.dx + side * fw * 0.17, base.dy - fh * 0.16,
          base.dx + side * fw * 0.18, base.dy)
      ..close();
    softShadow(c, tri, fw * 0.04);
    c.drawPath(
        tri,
        pgrad(tri.getBounds(),
            [const Color(0xFF8D8D8D), const Color(0xFF4F4F4F)]));
    final inner = Path()
      ..moveTo(base.dx - side * fw * 0.08, base.dy - fh * 0.015)
      ..lineTo(tip.dx - side * fw * 0.01, tip.dy + fh * 0.09)
      ..lineTo(base.dx + side * fw * 0.10, base.dy - fh * 0.02)
      ..close();
    c.drawPath(
        inner,
        Paint()
          ..color = const Color(0xFFF8A8C0)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, fw * 0.015));
  }
  final n = g.derolled(P.noseBotC);
  final nose = Path()
    ..moveTo(n.dx - fw * 0.055, n.dy - fh * 0.03)
    ..quadraticBezierTo(n.dx, n.dy - fh * 0.045, n.dx + fw * 0.055, n.dy - fh * 0.03)
    ..quadraticBezierTo(n.dx + fw * 0.04, n.dy + fh * 0.02, n.dx, n.dy + fh * 0.04)
    ..quadraticBezierTo(n.dx - fw * 0.04, n.dy + fh * 0.02, n.dx - fw * 0.055, n.dy - fh * 0.03)
    ..close();
  c.drawPath(nose,
      pgrad(nose.getBounds(), [const Color(0xFFFF9EC0), const Color(0xFFE2557F)]));
  // Ağız: burun altında "w"
  final m = ps(const Color(0xFF424242), fw * 0.014);
  final my = n.dy + fh * 0.055;
  final mouth = Path()
    ..moveTo(n.dx - fw * 0.10, my)
    ..quadraticBezierTo(n.dx - fw * 0.05, my + fh * 0.045, n.dx, my)
    ..quadraticBezierTo(n.dx + fw * 0.05, my + fh * 0.045, n.dx + fw * 0.10, my);
  c.drawPath(mouth, m);
  _whiskers(c, g, Colors.white.withValues(alpha: 0.85));
  _tongue(c, g, t, wf: 0.13);
}

// ---- Ayı ----
void _bear(Canvas c, FaceGeom g) {
  final fw = g.fw, fh = g.fh;
  final top = _headTop(g);
  for (final side in [-1, 1]) {
    final e = Offset(top.dx + side * fw * 0.34, top.dy + fh * 0.02);
    final path = Path()..addOval(Rect.fromCircle(center: e, radius: fw * 0.17));
    softShadow(c, path, fw * 0.05);
    c.drawCircle(
        e,
        fw * 0.17,
        prad(e.translate(-fw * 0.05, -fw * 0.05), fw * 0.22,
            [const Color(0xFF97705C), const Color(0xFF5D4037)]));
    c.drawCircle(e, fw * 0.10,
        prad(e, fw * 0.10, [const Color(0xFFD7CCC8), const Color(0xFFBCAAA4)]));
  }
  _patch(c, g.derolled(P.noseBotC).translate(0, fh * 0.02), fw * 0.36,
      fh * 0.24, const Color(0xFFD7CCC8).withValues(alpha: 0.8));
  _snout(c, g.derolled(P.noseBotC).translate(0, -fh * 0.01), fw * 0.16,
      fh * 0.10, const Color(0xFF4E342E), const Color(0xFF241511));
}

// ---- Tilki ----
void _fox(Canvas c, FaceGeom g) {
  final fw = g.fw, fh = g.fh;
  final top = _headTop(g);
  for (final side in [-1, 1]) {
    final bx = top.dx + side * fw * 0.30;
    final base = Offset(bx, top.dy + fh * 0.08);
    final tip = Offset(bx + side * fw * 0.12, top.dy - fh * 0.44);
    final outer = Path()
      ..moveTo(base.dx - side * fw * 0.18, base.dy)
      ..quadraticBezierTo(base.dx - side * fw * 0.06, base.dy - fh * 0.28,
          tip.dx, tip.dy)
      ..quadraticBezierTo(base.dx + side * fw * 0.20, base.dy - fh * 0.20,
          base.dx + side * fw * 0.20, base.dy)
      ..close();
    softShadow(c, outer, fw * 0.045);
    c.drawPath(
        outer,
        pgrad(outer.getBounds(),
            [const Color(0xFFFB9A3F), const Color(0xFFE0661B)]));
    final inner = Path()
      ..moveTo(base.dx - side * fw * 0.09, base.dy - fh * 0.01)
      ..lineTo(tip.dx - side * fw * 0.015, tip.dy + fh * 0.12)
      ..lineTo(base.dx + side * fw * 0.11, base.dy - fh * 0.015)
      ..close();
    c.drawPath(
        inner,
        Paint()
          ..color = const Color(0xFFFFF3E0)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, fw * 0.012));
    // Koyu uç
    final tipPath = Path()
      ..moveTo(tip.dx - fw * 0.05, tip.dy + fh * 0.10)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(tip.dx + fw * 0.05, tip.dy + fh * 0.10)
      ..close();
    c.drawPath(tipPath, pf(const Color(0xFF4E342E)));
  }
  _patch(c, g.derolled(P.noseBotC).translate(0, fh * 0.02), fw * 0.34,
      fh * 0.22, const Color(0xFFFFF3E0).withValues(alpha: 0.6));
  _snout(c, g.derolled(P.noseBotC), fw * 0.15, fh * 0.10,
      const Color(0xFF4E342E), const Color(0xFF2B1A14));
  _whiskers(c, g, Colors.white.withValues(alpha: 0.75));
}

// ---- Panda ----
void _panda(Canvas c, FaceGeom g) {
  final fw = g.fw, fh = g.fh;
  final top = _headTop(g);
  for (final side in [-1, 1]) {
    final e = Offset(top.dx + side * fw * 0.36, top.dy + fh * 0.02);
    final path = Path()..addOval(Rect.fromCircle(center: e, radius: fw * 0.16));
    softShadow(c, path, fw * 0.05);
    c.drawCircle(
        e,
        fw * 0.16,
        prad(e.translate(-fw * 0.04, -fw * 0.04), fw * 0.2,
            [const Color(0xFF3A3A3A), Colors.black]));
    gloss(c, e, fw * 0.10, fw * 0.08, alpha: 0.18);
  }
  // Göz lekeleri gerçek göz konumuna (kafa uzayında)
  for (final i in [P.eyeL, P.eyeR]) {
    final e = g.derolled(i + 1); // göz üstü
    _patch(c, e.translate(0, fh * 0.03), fw * 0.20, fh * 0.17,
        Colors.black.withValues(alpha: 0.75));
  }
  _snout(c, g.derolled(P.noseBotC), fw * 0.13, fh * 0.08,
      const Color(0xFF3A3A3A), Colors.black);
}

// ---- Koala ----
void _koala(Canvas c, FaceGeom g) {
  final fw = g.fw, fh = g.fh;
  final top = _headTop(g);
  for (final side in [-1, 1]) {
    final e = Offset(top.dx + side * fw * 0.52, top.dy + fh * 0.14);
    final path = Path()..addOval(Rect.fromCircle(center: e, radius: fw * 0.24));
    softShadow(c, path, fw * 0.06);
    c.drawCircle(
        e,
        fw * 0.24,
        prad(e.translate(-fw * 0.06, -fw * 0.06), fw * 0.3,
            [const Color(0xFFB0BEC5), const Color(0xFF78909C)]));
    c.drawCircle(
        e,
        fw * 0.15,
        Paint()
          ..color = const Color(0xFFECEFF1)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, fw * 0.03));
    // Tüy izlenimi
    for (var i = -1; i <= 1; i++) {
      c.drawLine(
        Offset(e.dx - side * fw * 0.10, e.dy + i * fw * 0.07),
        Offset(e.dx - side * fw * 0.22, e.dy + i * fw * 0.11),
        ps(const Color(0xFFECEFF1), fw * 0.02),
      );
    }
  }
  final n = g.derolled(P.noseTip);
  _snout(c, n.translate(0, fh * 0.01), fw * 0.19, fh * 0.20,
      const Color(0xFF4A5A63), const Color(0xFF2A3439));
}

// ---- Fare ----
void _mouse(Canvas c, FaceGeom g, double t) {
  final fw = g.fw, fh = g.fh;
  final top = _headTop(g);
  for (final side in [-1, 1]) {
    final e = Offset(top.dx + side * fw * 0.38, top.dy - fh * 0.02);
    final path = Path()..addOval(Rect.fromCircle(center: e, radius: fw * 0.20));
    softShadow(c, path, fw * 0.05);
    c.drawCircle(
        e,
        fw * 0.20,
        prad(e.translate(-fw * 0.05, -fw * 0.05), fw * 0.25,
            [const Color(0xFFBDBDBD), const Color(0xFF757575)]));
    c.drawCircle(
        e,
        fw * 0.13,
        prad(e, fw * 0.13,
            [const Color(0xFFFCE4EC), const Color(0xFFF48FB1)]));
  }
  final n = g.derolled(P.noseBotC);
  c.drawCircle(
      n,
      fw * 0.05,
      prad(n.translate(-fw * 0.012, -fw * 0.012), fw * 0.06,
          [const Color(0xFFFF9EC0), const Color(0xFFE2557F)]));
  _whiskers(c, g, Colors.white.withValues(alpha: 0.8));
  _tongue(c, g, t, wf: 0.12);
}

// ---- Kaplan ----
void _tiger(Canvas c, FaceGeom g) {
  final fw = g.fw, fh = g.fh;
  final top = _headTop(g);
  for (final side in [-1, 1]) {
    final e = Offset(top.dx + side * fw * 0.34, top.dy + fh * 0.02);
    final path = Path()..addOval(Rect.fromCircle(center: e, radius: fw * 0.15));
    softShadow(c, path, fw * 0.04);
    c.drawCircle(
        e,
        fw * 0.15,
        prad(e.translate(-fw * 0.04, -fw * 0.04), fw * 0.19,
            [const Color(0xFFFB9A3F), const Color(0xFFE0661B)]));
    c.drawCircle(e, fw * 0.09, pf(Colors.white));
  }
  // Yanak çizgileri: yanak çapasından dışa incelen üçgenler
  final black = Paint()
    ..color = Colors.black87
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, fw * 0.004);
  for (final (i, side) in [(P.cheekL, -1), (P.cheekR, 1)]) {
    final ck = g.derolled(i);
    for (var j = 0; j < 3; j++) {
      final y = ck.dy - fh * 0.10 + j * fh * 0.10;
      final x0 = ck.dx + side * fw * 0.22;
      final stripe = Path()
        ..moveTo(x0, y - fh * 0.030)
        ..quadraticBezierTo(x0 - side * fw * 0.12, y - fh * 0.01,
            x0 - side * fw * (0.22 - j * 0.03), y)
        ..quadraticBezierTo(x0 - side * fw * 0.12, y + fh * 0.01, x0,
            y + fh * 0.030)
        ..close();
      c.drawPath(stripe, black);
    }
  }
  // Alın çizgileri
  final fy = top.dy + fh * 0.14;
  for (final dx in [-fw * 0.10, 0.0, fw * 0.10]) {
    final k = dx == 0 ? 1.0 : 0.7;
    final fstripe = Path()
      ..moveTo(top.dx + dx - fw * 0.025 * k, fy - fh * 0.10 * k)
      ..lineTo(top.dx + dx, fy + fh * 0.02 * k)
      ..lineTo(top.dx + dx + fw * 0.025 * k, fy - fh * 0.10 * k)
      ..close();
    c.drawPath(fstripe, black);
  }
  _snout(c, g.derolled(P.noseBotC), fw * 0.15, fh * 0.09,
      const Color(0xFF8D6E63), const Color(0xFF4E342E));
}

// ---- Maymun ----
void _monkey(Canvas c, FaceGeom g) {
  final fw = g.fw, fh = g.fh;
  final top = _headTop(g);
  for (final side in [-1, 1]) {
    final e = Offset(top.dx + side * fw * 0.55, top.dy + fh * 0.34);
    final path = Path()..addOval(Rect.fromCircle(center: e, radius: fw * 0.16));
    softShadow(c, path, fw * 0.05);
    c.drawCircle(
        e,
        fw * 0.16,
        prad(e.translate(-fw * 0.04, -fw * 0.04), fw * 0.2,
            [const Color(0xFF8D6E63), const Color(0xFF5D4037)]));
    c.drawCircle(
        e,
        fw * 0.10,
        prad(e, fw * 0.10,
            [const Color(0xFFEDD9BF), const Color(0xFFD7B899)]));
  }
  // Ağız çevresi
  _patch(c, g.derolled(P.noseBotC).translate(0, fh * 0.05), fw * 0.38,
      fh * 0.28, const Color(0xFFD7B899).withValues(alpha: 0.85));
  final n = g.derolled(P.noseBotC);
  for (final side in [-1, 1]) {
    c.drawCircle(Offset(n.dx + side * fw * 0.045, n.dy - fh * 0.005),
        fw * 0.022, pf(const Color(0xFF5D4037)));
  }
  // Gülümseme genişliği gerçek gülümsemeyle artar
  final sw = fw * (0.08 + 0.06 * g.smile);
  final smilePath = Path()
    ..moveTo(n.dx - sw, n.dy + fh * 0.08)
    ..quadraticBezierTo(
        n.dx, n.dy + fh * (0.13 + 0.03 * g.smile), n.dx + sw, n.dy + fh * 0.08);
  c.drawPath(smilePath, ps(const Color(0xFF5D4037), fw * 0.02));
  // Tepe tutamı
  final tuft = Path()
    ..moveTo(top.dx - fw * 0.05, top.dy + fh * 0.04)
    ..quadraticBezierTo(top.dx, top.dy - fh * 0.14, top.dx + fw * 0.07,
        top.dy + fh * 0.03);
  c.drawPath(tuft, ps(const Color(0xFF6D4C41), fw * 0.035));
}

// ---- Aslan ----
void _lion(Canvas c, FaceGeom g, double t) {
  final fw = g.fw, fh = g.fh;
  final ctr = g.center;
  // Yele: yüz ovalini saran iki katmanlı alev dilimleri, hafif nefes alır.
  final breathe = 1 + math.sin(t * 1.6) * 0.02;
  for (final (scale, color) in [
    (1.30, const Color(0xFFB5651D)),
    (1.12, const Color(0xFFE0862E)),
  ]) {
    const petals = 16;
    final path = Path();
    for (var i = 0; i <= petals; i++) {
      final a = i * 2 * math.pi / petals;
      final wob = 1 + 0.10 * math.sin(a * 3 + t * 0.8);
      final rx = fw * 0.60 * scale * breathe * wob;
      final ry = fh * 0.58 * scale * breathe * wob;
      final o = Offset(ctr.dx + rx * math.cos(a), ctr.dy + ry * math.sin(a));
      final aMid = (i + 0.5) * 2 * math.pi / petals;
      final mid = Offset(ctr.dx + fw * 0.48 * scale * math.cos(aMid),
          ctr.dy + fh * 0.46 * scale * math.sin(aMid));
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.quadraticBezierTo(mid.dx, mid.dy, o.dx, o.dy);
      }
    }
    path.close();
    // Halka: ortadan yüz ovali kadar boşluk — yele yüzü ÖRTMEZ, çevreler.
    path.addOval(Rect.fromCenter(
        center: ctr, width: fw * 0.94, height: fh * 0.92));
    path.fillType = PathFillType.evenOdd;
    c.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.92)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, fw * 0.02));
  }
  final top = _headTop(g);
  for (final side in [-1, 1]) {
    final e = Offset(top.dx + side * fw * 0.32, top.dy + fh * 0.02);
    c.drawCircle(
        e,
        fw * 0.12,
        prad(e.translate(-fw * 0.03, -fw * 0.03), fw * 0.15,
            [const Color(0xFFF2A65A), const Color(0xFFD98A3D)]));
    c.drawCircle(e, fw * 0.07, pf(const Color(0xFFFFE0B2)));
  }
  _snout(c, g.derolled(P.noseBotC), fw * 0.16, fh * 0.09,
      const Color(0xFF8D6E63), const Color(0xFF4E342E));
  _whiskers(c, g, Colors.white.withValues(alpha: 0.6));
}

// ---- Kurbağa ----
void _frog(Canvas c, FaceGeom g, double t) {
  final fw = g.fw, fh = g.fh;
  final top = _headTop(g);
  for (final side in [-1, 1]) {
    final e = Offset(top.dx + side * fw * 0.24, top.dy - fh * 0.04);
    final path = Path()..addOval(Rect.fromCircle(center: e, radius: fw * 0.15));
    softShadow(c, path, fw * 0.045);
    c.drawCircle(
        e,
        fw * 0.15,
        prad(e.translate(-fw * 0.04, -fw * 0.04), fw * 0.19,
            [const Color(0xFF81C784), const Color(0xFF388E3C)]));
    c.drawCircle(Offset(e.dx, e.dy - fh * 0.015), fw * 0.10, pf(Colors.white));
    // Göz bebeği karşıdakinin gözünü takip eder gibi hafif gezinir
    final px = math.sin(t * 0.9 + side) * fw * 0.025;
    c.drawCircle(Offset(e.dx + px, e.dy - fh * 0.015), fw * 0.05,
        pf(Colors.black87));
    c.drawCircle(Offset(e.dx + px - fw * 0.015, e.dy - fh * 0.03), fw * 0.015,
        pf(Colors.white));
  }
  final n = g.derolled(P.noseBotC);
  for (final side in [-1, 1]) {
    c.drawCircle(Offset(n.dx + side * fw * 0.05, n.dy - fh * 0.01), fw * 0.02,
        pf(const Color(0xFF2E7D32)));
  }
  if (g.mouth > 0.2) {
    // İnce uzun kurbağa dili: ağız içinden fırlar, ucu kıvrılır
    final m = g.derolled(P.lipInB);
    final len = fh * (0.18 + 0.42 * g.mouth);
    final curl = math.sin(t * 5) * fw * 0.06 * g.mouth;
    final tip = Offset(m.dx + curl, m.dy + len);
    final tPath = Path()
      ..moveTo(m.dx, m.dy)
      ..quadraticBezierTo(m.dx - curl * 0.6, m.dy + len * 0.6, tip.dx, tip.dy);
    c.drawPath(tPath, ps(const Color(0xFFE57373), fw * 0.065));
    c.drawCircle(tip, fw * 0.06,
        prad(tip, fw * 0.07, [const Color(0xFFEF9A9A), const Color(0xFFD32F2F)]));
  }
}

// ---- Geyik ----
void _deer(Canvas c, FaceGeom g) {
  final fw = g.fw, fh = g.fh;
  final top = _headTop(g);
  final antler = Paint()
    ..color = const Color(0xFF8D6E63)
    ..style = PaintingStyle.stroke
    ..strokeWidth = fw * 0.045
    ..strokeCap = StrokeCap.round;
  final antlerDark = Paint()
    ..color = const Color(0xFF6D4C41)
    ..style = PaintingStyle.stroke
    ..strokeWidth = fw * 0.055
    ..strokeCap = StrokeCap.round;
  for (final side in [-1, 1]) {
    final bx = top.dx + side * fw * 0.26;
    final by = top.dy + fh * 0.02;
    final main = Path()
      ..moveTo(bx, by)
      ..quadraticBezierTo(
          bx + side * fw * 0.10, by - fh * 0.30, bx + side * fw * 0.24,
          by - fh * 0.52);
    c.drawPath(main, antlerDark);
    c.drawPath(main, antler);
    final b1 = Path()
      ..moveTo(bx + side * fw * 0.045, by - fh * 0.17)
      ..quadraticBezierTo(bx - side * fw * 0.02, by - fh * 0.28,
          bx - side * fw * 0.05, by - fh * 0.40);
    c.drawPath(b1, antler);
    final b2 = Path()
      ..moveTo(bx + side * fw * 0.13, by - fh * 0.33)
      ..quadraticBezierTo(bx + side * fw * 0.30, by - fh * 0.42,
          bx + side * fw * 0.37, by - fh * 0.38);
    c.drawPath(b2, antler);
    // Kulak
    final base = Offset(top.dx + side * fw * 0.42, by + fh * 0.12);
    final tip = Offset(top.dx + side * fw * 0.66, by + fh * 0.02);
    _ear(c, base, tip, fw * 0.09,
        light: const Color(0xFFBCAAA4),
        dark: const Color(0xFF8D6E63),
        inner: const Color(0xFFEFDCD5));
  }
  _snout(c, g.derolled(P.noseBotC), fw * 0.13, fh * 0.08,
      const Color(0xFF6D4C41), const Color(0xFF3E2723));
  // Bambi yanak benekleri
  for (final i in [P.cheekL, P.cheekR]) {
    final ck = g.derolled(i);
    for (var j = 0; j < 3; j++) {
      c.drawCircle(
          Offset(ck.dx + (rnd(j, i) - 0.5) * fw * 0.14,
              ck.dy + (rnd(j, i + 9) - 0.5) * fh * 0.10),
          fw * 0.014,
          pf(Colors.white.withValues(alpha: 0.85)));
    }
  }
}

// ---- Civciv ----
void _chick(Canvas c, FaceGeom g, double t) {
  final fw = g.fw, fh = g.fh;
  final top = _headTop(g);
  // Tepe tüyleri: üç yaprak, rüzgârda hafif salınır
  for (var i = -1; i <= 1; i++) {
    final sway = math.sin(t * 2.5 + i) * fw * 0.012;
    final ctr = Offset(top.dx + i * fw * 0.11 + sway,
        top.dy - fh * 0.10 - (1 - i.abs()) * fh * 0.05);
    final r = Rect.fromCenter(center: ctr, width: fw * 0.11, height: fh * 0.20);
    c.drawOval(
        r,
        pgrad(r, [const Color(0xFFFFF176), const Color(0xFFFBC02D)]));
  }
  // Gaga: ağız açılınca alt gaga gerçekten açılır
  final n = g.derolled(P.noseBotC);
  final open = fh * 0.05 * g.mouth;
  final beakTop = Path()
    ..moveTo(n.dx - fw * 0.11, n.dy - fh * 0.02)
    ..quadraticBezierTo(n.dx, n.dy - fh * 0.05, n.dx + fw * 0.11, n.dy - fh * 0.02)
    ..quadraticBezierTo(n.dx + fw * 0.04, n.dy + fh * 0.045, n.dx, n.dy + fh * 0.055)
    ..quadraticBezierTo(n.dx - fw * 0.04, n.dy + fh * 0.045, n.dx - fw * 0.11, n.dy - fh * 0.02)
    ..close();
  softShadow(c, beakTop, fw * 0.02);
  c.drawPath(
      beakTop,
      pgrad(beakTop.getBounds(),
          [const Color(0xFFFFB74D), const Color(0xFFF57C00)]));
  final beakBot = Path()
    ..moveTo(n.dx - fw * 0.065, n.dy + fh * 0.05 + open)
    ..quadraticBezierTo(n.dx, n.dy + fh * 0.11 + open, n.dx + fw * 0.065,
        n.dy + fh * 0.05 + open)
    ..quadraticBezierTo(n.dx, n.dy + fh * 0.07 + open, n.dx - fw * 0.065,
        n.dy + fh * 0.05 + open)
    ..close();
  c.drawPath(beakBot, pf(const Color(0xFFEF6C00)));
  // Pembe yanaklar gerçek yanak çapasında
  for (final i in [P.cheekL, P.cheekR]) {
    final ck = g.derolled(i);
    c.drawCircle(
        ck,
        fw * 0.08,
        prad(ck, fw * 0.09, [
          const Color(0xFFF8BBD0).withValues(alpha: 0.85),
          const Color(0xFFF8BBD0).withValues(alpha: 0)
        ]));
  }
}
