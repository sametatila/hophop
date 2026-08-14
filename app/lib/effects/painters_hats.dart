import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'fx_frame.dart';
import 'painter_util.dart';

/// Şapka/taç efektleri — kafa uzayında çizilir: başın tepe noktasına
/// (yüz ovalinin tepesine) oturur, kafayla döner ve yaw/pitch ile eğilir.
/// Hepsi degrade + gölge ile hacimli; birkaçı zamanla oynar (pervane döner,
/// melek halkası süzülür, mezuniyet püskülü sallanır).
void paintHatFx(String id, Canvas c, Size s, FaceGeom g, double t) {
  withHead(c, g, () {
    final top = g.derolled(P.oval);
    switch (id) {
      case 'crown':
        _crown(c, g, top, t);
      case 'fcrown':
        _flowerCrown(c, g, top);
      case 'party':
        _party(c, g, top, t);
      case 'wizard':
        _wizard(c, g, top, t);
      case 'chef':
        _chef(c, g, top);
      case 'pirate':
        _pirate(c, g, top);
      case 'halo':
        _halo(c, g, top, t);
      case 'grad':
        _grad(c, g, top, t);
      case 'cowboy':
        _cowboy(c, g, top);
      case 'prop':
        _propeller(c, g, top, t);
      case 'beanie':
        _beanie(c, g, top);
      case 'unicorn':
        _unicorn(c, g, top, t);
    }
  });
}

const _gold = Color(0xFFFFC93C);
const _goldDark = Color(0xFFE09E14);

// ---- Altın taç ----
void _crown(Canvas c, FaceGeom g, Offset top, double t) {
  final fw = g.fw, fh = g.fh;
  final cx = top.dx;
  final base = top.dy - fh * 0.06;
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
  softShadow(c, path, fw * 0.03);
  c.drawPath(
      path,
      pgrad(path.getBounds(), [const Color(0xFFFFE082), _gold, _goldDark],
          stops: const [0, 0.55, 1]));
  // Bant + perçin
  c.drawRect(
      Rect.fromCenter(
          center: Offset(cx, base + fh * 0.06), width: w, height: fh * 0.025),
      pf(_goldDark.withValues(alpha: 0.6)));
  // Mücevherler: sivri uçlarda parlayan taşlar
  const gems = [Color(0xFFE8506E), Color(0xFF42A5F5), Color(0xFF66BB6A)];
  for (var i = 0; i < 3; i++) {
    final p = Offset(cx - w / 2 + w * i / 3 + w / 6, base - fh * 0.28);
    c.drawCircle(p, fw * 0.040,
        prad(p.translate(-fw * 0.01, -fw * 0.01), fw * 0.05,
            [Color.lerp(gems[i], Colors.white, 0.5)!, gems[i]]));
    c.drawCircle(p.translate(-fw * 0.012, -fw * 0.012), fw * 0.010,
        pf(Colors.white.withValues(alpha: 0.9)));
  }
  // Ön taş + ışıltı
  final front = Offset(cx, base + fh * 0.045);
  c.drawPath(
      heartPath(front, fw * 0.030), pf(const Color(0xFFE8506E)));
  final tw = frac(t * 0.7);
  if (tw < 0.35) {
    final a = (1 - (tw / 0.35 - 0.5).abs() * 2).clamp(0.0, 1.0);
    final sp = Offset(cx + w * 0.38, base - fh * 0.20);
    c.drawPath(starPath(sp, fw * 0.045 * a, inner: 0.25),
        pf(Colors.white.withValues(alpha: 0.9 * a)));
  }
}

// ---- Çiçek taç ----
void _flowerCrown(Canvas c, FaceGeom g, Offset top) {
  final fw = g.fw, fh = g.fh;
  final cx = top.dx;
  final base = top.dy + fh * 0.10;
  const colors = [
    Color(0xFFF48FB1),
    Color(0xFFFFF59D),
    Color(0xFFFFFFFF),
    Color(0xFFFFF59D),
    Color(0xFFF48FB1),
  ];
  // Alın kavisini izleyen taç yayı
  double yAt(int k) => base - fh * 0.055 * (1 - (k * k) / 5.0);
  // Yapraklar: çiçeklerin arasına yeşil elipsler (hafif açılı)
  for (var i = 0; i < 4; i++) {
    final x = cx + (i - 1.5) * fw * 0.19;
    c.save();
    c.translate(x, base - fh * 0.02);
    c.rotate((i - 1.5) * 0.25);
    final r = Rect.fromCenter(
        center: Offset.zero, width: fw * 0.13, height: fw * 0.055);
    c.drawOval(
        r, pgrad(r, [const Color(0xFFA5D6A7), const Color(0xFF66BB6A)]));
    c.restore();
  }
  for (var i = 0; i < 5; i++) {
    final k = i - 2;
    drawFlower(c, Offset(cx + k * fw * 0.19, yAt(k)),
        fw * (k.abs() == 2 ? 0.075 : 0.09), colors[i],
        const Color(0xFFFFB300));
  }
}

// ---- Parti şapkası ----
void _party(Canvas c, FaceGeom g, Offset top, double t) {
  final fw = g.fw, fh = g.fh;
  final cx = top.dx;
  final base = top.dy + fh * 0.04;
  final apex = Offset(cx, base - fh * 0.52);
  final cone = Path()
    ..moveTo(cx - fw * 0.26, base)
    ..quadraticBezierTo(cx, base + fh * 0.05, cx + fw * 0.26, base)
    ..lineTo(apex.dx, apex.dy)
    ..close();
  softShadow(c, cone, fw * 0.03);
  c.drawPath(
      cone,
      pgrad(cone.getBounds(), [const Color(0xFFFF8FB8), const Color(0xFFE64A8B)],
          begin: Alignment.topLeft, end: Alignment.bottomRight));
  // Puanlar
  c.save();
  c.clipPath(cone);
  for (final (dx, dy) in [
    (-0.10, 0.10), (0.08, 0.22), (-0.03, 0.34), (0.12, 0.42), (-0.14, 0.44)
  ]) {
    c.drawCircle(Offset(cx + fw * dx, apex.dy + fh * dy), fw * 0.035,
        pf(Colors.white.withValues(alpha: 0.9)));
  }
  gloss(c, Offset(cx - fw * 0.08, base - fh * 0.22), fw * 0.10, fh * 0.30,
      alpha: 0.22);
  c.restore();
  // Tepede zıplayan ponpon + ışıltılar
  final bob = math.sin(t * 5) * fh * 0.012;
  final knobC = apex.translate(0, -fh * 0.015 + bob);
  c.drawCircle(knobC, fw * 0.06,
      prad(knobC.translate(-fw * 0.015, -fw * 0.015), fw * 0.07,
          [const Color(0xFFFFE082), _gold]));
  for (var i = 0; i < 3; i++) {
    final a = t * 2 + i * 2.1;
    final r = fw * (0.12 + 0.03 * math.sin(t * 3 + i));
    final sp = knobC + Offset(math.cos(a) * r, math.sin(a) * r * 0.6);
    c.drawPath(starPath(sp, fw * 0.022, inner: 0.3),
        pf(Colors.white.withValues(alpha: 0.8)));
  }
}

// ---- Büyücü şapkası ----
void _wizard(Canvas c, FaceGeom g, Offset top, double t) {
  final fw = g.fw, fh = g.fh;
  final cx = top.dx;
  final base = top.dy + fh * 0.02;
  // Kenar
  final brimRect = Rect.fromCenter(
      center: Offset(cx, base), width: fw * 0.88, height: fh * 0.16);
  final brim = Path()..addOval(brimRect);
  softShadow(c, brim, fw * 0.04);
  c.drawOval(brimRect,
      pgrad(brimRect, [const Color(0xFF9575CD), const Color(0xFF5E35B1)]));
  // Hafif kıvrık koni
  final cone = Path()
    ..moveTo(cx - fw * 0.28, base)
    ..quadraticBezierTo(
        cx - fw * 0.16, base - fh * 0.34, cx + fw * 0.04, base - fh * 0.60)
    ..quadraticBezierTo(cx + fw * 0.10, base - fh * 0.30, cx + fw * 0.28, base)
    ..close();
  c.drawPath(
      cone,
      pgrad(cone.getBounds(), [const Color(0xFF9575CD), const Color(0xFF512DA8)],
          begin: Alignment.topRight, end: Alignment.bottomLeft));
  // Bant + toka
  c.drawRect(
      Rect.fromCenter(
          center: Offset(cx, base - fh * 0.045),
          width: fw * 0.50,
          height: fh * 0.065),
      pgrad(
          Rect.fromCenter(
              center: Offset(cx, base - fh * 0.045),
              width: fw * 0.50,
              height: fh * 0.065),
          [const Color(0xFFFFE082), _goldDark]));
  // Yıldızlar + ay — sırayla göz kırpar
  final blink1 = 0.6 + 0.4 * math.sin(t * 2.5);
  final blink2 = 0.6 + 0.4 * math.sin(t * 2.5 + 2);
  c.drawPath(starPath(Offset(cx - fw * 0.07, base - fh * 0.22), fw * 0.045),
      pf(const Color(0xFFFFF59D).withValues(alpha: blink1)));
  c.drawPath(starPath(Offset(cx + fw * 0.10, base - fh * 0.36), fw * 0.035),
      pf(const Color(0xFFFFF59D).withValues(alpha: blink2)));
  final moon = Path()
    ..addOval(Rect.fromCircle(
        center: Offset(cx - fw * 0.01, base - fh * 0.46), radius: fw * 0.045))
    ..addOval(Rect.fromCircle(
        center: Offset(cx + fw * 0.015, base - fh * 0.472), radius: fw * 0.038));
  moon.fillType = PathFillType.evenOdd;
  c.drawPath(moon, pf(const Color(0xFFFFF59D)));
}

// ---- Aşçı şapkası ----
void _chef(Canvas c, FaceGeom g, Offset top) {
  final fw = g.fw, fh = g.fh;
  final cx = top.dx;
  final base = top.dy + fh * 0.04;
  // Kabarık üst: üç top, her biri hacimli
  for (final (dx, dy, r) in [
    (-0.20, 0.16, 0.16),
    (0.20, 0.16, 0.16),
    (0.0, 0.26, 0.20)
  ]) {
    final ctr = Offset(cx + fw * dx, base - fh * dy);
    final path = Path()..addOval(Rect.fromCircle(center: ctr, radius: fw * r));
    softShadow(c, path, fw * 0.03, offset: Offset(0, fw * 0.02));
    c.drawCircle(
        ctr,
        fw * r,
        prad(ctr.translate(-fw * r * 0.3, -fw * r * 0.3), fw * r * 1.3,
            [Colors.white, const Color(0xFFDADADA)]));
  }
  // Bant
  final band = RRect.fromRectAndRadius(
    Rect.fromCenter(
        center: Offset(cx, base), width: fw * 0.62, height: fh * 0.14),
    Radius.circular(fw * 0.03),
  );
  c.drawRRect(band,
      pgrad(band.outerRect, [Colors.white, const Color(0xFFE0E0E0)]));
  c.drawLine(Offset(cx - fw * 0.31, base + fh * 0.07),
      Offset(cx + fw * 0.31, base + fh * 0.07),
      ps(const Color(0xFFBDBDBD), fw * 0.015));
}

// ---- Korsan şapkası ----
void _pirate(Canvas c, FaceGeom g, Offset top) {
  final fw = g.fw, fh = g.fh;
  final cx = top.dx;
  final base = top.dy + fh * 0.06;
  final hat = Path()
    ..moveTo(cx - fw * 0.58, base)
    ..quadraticBezierTo(cx - fw * 0.42, base - fh * 0.40, cx, base - fh * 0.46)
    ..quadraticBezierTo(cx + fw * 0.42, base - fh * 0.40, cx + fw * 0.58, base)
    ..quadraticBezierTo(cx + fw * 0.30, base - fh * 0.10, cx, base - fh * 0.08)
    ..quadraticBezierTo(cx - fw * 0.30, base - fh * 0.10, cx - fw * 0.58, base)
    ..close();
  softShadow(c, hat, fw * 0.04);
  c.drawPath(
      hat,
      pgrad(hat.getBounds(), [const Color(0xFF455A64), const Color(0xFF1C262B)]));
  // Altın şerit kenar
  c.drawPath(
      Path()
        ..moveTo(cx - fw * 0.58, base)
        ..quadraticBezierTo(cx - fw * 0.30, base - fh * 0.10, cx, base - fh * 0.08)
        ..quadraticBezierTo(cx + fw * 0.30, base - fh * 0.10, cx + fw * 0.58, base),
      ps(_gold, fw * 0.022));
  // Kurukafa (sevimli)
  final skull = Offset(cx, base - fh * 0.24);
  c.drawCircle(
      skull,
      fw * 0.075,
      prad(skull.translate(-fw * 0.02, -fw * 0.02), fw * 0.09,
          [Colors.white, const Color(0xFFD5D5D5)]));
  final eye = pf(const Color(0xFF1C262B));
  c.drawCircle(
      Offset(skull.dx - fw * 0.028, skull.dy - fh * 0.008), fw * 0.018, eye);
  c.drawCircle(
      Offset(skull.dx + fw * 0.028, skull.dy - fh * 0.008), fw * 0.018, eye);
  // Çapraz kemikler
  final bone = ps(Colors.white, fw * 0.02);
  c.drawLine(Offset(skull.dx - fw * 0.09, skull.dy + fh * 0.06),
      Offset(skull.dx + fw * 0.09, skull.dy - fh * 0.005), bone);
  c.drawLine(Offset(skull.dx + fw * 0.09, skull.dy + fh * 0.06),
      Offset(skull.dx - fw * 0.09, skull.dy - fh * 0.005), bone);
}

// ---- Melek halkası (süzülür + ışıldar) ----
void _halo(Canvas c, FaceGeom g, Offset top, double t) {
  final fw = g.fw, fh = g.fh;
  final bob = math.sin(t * 1.8) * fh * 0.02;
  final center = Offset(top.dx, top.dy - fh * 0.26 + bob);
  final rect =
      Rect.fromCenter(center: center, width: fw * 0.56, height: fh * 0.14);
  final pulse = 0.35 + 0.25 * math.sin(t * 3);
  // Işıma
  c.drawOval(
      rect.inflate(fw * 0.04),
      Paint()
        ..color = const Color(0xFFFFF176).withValues(alpha: pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = fw * 0.09
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, fw * 0.05));
  // Halkanın kendisi: metalik degrade izlenimi için çift çizgi
  c.drawOval(rect, ps(const Color(0xFFFFD54F), fw * 0.045));
  c.drawOval(rect.deflate(fw * 0.012),
      ps(Colors.white.withValues(alpha: 0.55), fw * 0.012));
}

// ---- Mezuniyet kepi (püskül sallanır) ----
void _grad(Canvas c, FaceGeom g, Offset top, double t) {
  final fw = g.fw, fh = g.fh;
  final cx = top.dx;
  final base = top.dy + fh * 0.02;
  // Kafa bandı
  c.drawOval(
      Rect.fromCenter(
          center: Offset(cx, base), width: fw * 0.60, height: fh * 0.18),
      pf(const Color(0xFF37474F)));
  // Tabla (elmas) — degrade ile hacim
  final board = Path()
    ..moveTo(cx - fw * 0.56, base - fh * 0.10)
    ..lineTo(cx, base - fh * 0.26)
    ..lineTo(cx + fw * 0.56, base - fh * 0.10)
    ..lineTo(cx, base + fh * 0.02)
    ..close();
  softShadow(c, board, fw * 0.035);
  c.drawPath(
      board,
      pgrad(board.getBounds(), [const Color(0xFF37474F), const Color(0xFF12181B)],
          begin: Alignment.topLeft, end: Alignment.bottomRight));
  // Düğme + püskül
  final knob = Offset(cx, base - fh * 0.12);
  c.drawCircle(knob, fw * 0.025, pf(_gold));
  final sway = math.sin(t * 2.2) * fw * 0.05;
  final tip = Offset(cx + fw * 0.46 + sway, base + fh * 0.10);
  final cord = Path()
    ..moveTo(knob.dx, knob.dy)
    ..quadraticBezierTo(cx + fw * 0.30, base - fh * 0.16, tip.dx, tip.dy);
  c.drawPath(cord, ps(_gold, fw * 0.02));
  for (var i = -1; i <= 1; i++) {
    c.drawLine(
        tip,
        Offset(tip.dx + i * fw * 0.025 + sway * 0.3, tip.dy + fh * 0.08),
        ps(_gold, fw * 0.018));
  }
}

// ---- Kovboy şapkası ----
void _cowboy(Canvas c, FaceGeom g, Offset top) {
  final fw = g.fw, fh = g.fh;
  final cx = top.dx;
  final base = top.dy + fh * 0.04;
  // Kenar: uçları kıvrık geniş elips
  final brim = Path()
    ..moveTo(cx - fw * 0.60, base - fh * 0.06)
    ..quadraticBezierTo(
        cx - fw * 0.55, base + fh * 0.10, cx - fw * 0.25, base + fh * 0.08)
    ..quadraticBezierTo(cx, base + fh * 0.12, cx + fw * 0.25, base + fh * 0.08)
    ..quadraticBezierTo(
        cx + fw * 0.55, base + fh * 0.10, cx + fw * 0.60, base - fh * 0.06)
    ..quadraticBezierTo(cx + fw * 0.35, base - fh * 0.02, cx, base - fh * 0.02)
    ..quadraticBezierTo(cx - fw * 0.35, base - fh * 0.02, cx - fw * 0.60, base - fh * 0.06)
    ..close();
  softShadow(c, brim, fw * 0.04);
  c.drawPath(
      brim,
      pgrad(brim.getBounds(), [const Color(0xFFB57834), const Color(0xFF7A4C1E)]));
  // Tepe
  final dome = Path()
    ..moveTo(cx - fw * 0.26, base)
    ..quadraticBezierTo(
        cx - fw * 0.28, base - fh * 0.36, cx - fw * 0.08, base - fh * 0.38)
    ..quadraticBezierTo(cx, base - fh * 0.32, cx + fw * 0.08, base - fh * 0.38)
    ..quadraticBezierTo(cx + fw * 0.28, base - fh * 0.36, cx + fw * 0.26, base)
    ..close();
  c.drawPath(
      dome,
      pgrad(dome.getBounds(), [const Color(0xFFB57834), const Color(0xFF8A5A24)]));
  gloss(c, Offset(cx - fw * 0.06, base - fh * 0.26), fw * 0.12, fh * 0.10,
      alpha: 0.15);
  // Bant + dikiş
  c.drawRect(
      Rect.fromCenter(
          center: Offset(cx, base - fh * 0.045),
          width: fw * 0.50,
          height: fh * 0.06),
      pf(const Color(0xFF5D3A13)));
  final stitch = ps(const Color(0xFFD7B899), fw * 0.008);
  for (var i = -3; i <= 3; i++) {
    final x = cx + i * fw * 0.07;
    c.drawLine(Offset(x - fw * 0.015, base - fh * 0.045),
        Offset(x + fw * 0.015, base - fh * 0.045), stitch);
  }
}

// ---- Pervaneli şapka (pervane döner) ----
void _propeller(Canvas c, FaceGeom g, Offset top, double t) {
  final fw = g.fw, fh = g.fh;
  final cx = top.dx;
  final base = top.dy + fh * 0.06;
  final dome = Path()
    ..moveTo(cx - fw * 0.34, base)
    ..arcToPoint(Offset(cx + fw * 0.34, base),
        radius: Radius.circular(fw * 0.36))
    ..close();
  // Renkli dilimler
  softShadow(c, dome, fw * 0.03);
  c.save();
  c.clipPath(dome);
  const cols = [
    Color(0xFFE85D5D),
    Color(0xFFFFC93C),
    Color(0xFF4FC3F7),
    Color(0xFF69F0AE)
  ];
  for (var i = 0; i < 4; i++) {
    c.drawRect(
        Rect.fromLTWH(cx - fw * 0.34 + i * fw * 0.17, base - fh * 0.40,
            fw * 0.17, fh * 0.40),
        pf(cols[i]));
  }
  // Dilim ayrımları + parlama
  for (var i = 1; i < 4; i++) {
    c.drawLine(
        Offset(cx - fw * 0.34 + i * fw * 0.17, base - fh * 0.40),
        Offset(cx - fw * 0.34 + i * fw * 0.17, base),
        ps(Colors.black.withValues(alpha: 0.12), fw * 0.008));
  }
  gloss(c, Offset(cx - fw * 0.10, base - fh * 0.22), fw * 0.16, fh * 0.14,
      alpha: 0.25);
  c.restore();
  // Sap + göbek
  final hub = Offset(cx, base - fh * 0.42);
  c.drawLine(Offset(cx, base - fh * 0.33), hub,
      ps(const Color(0xFF616161), fw * 0.03));
  // Dönen kanatlar: hareket bulanıklığı yayı + kanatlar
  final a = t * 9;
  c.drawCircle(
      hub,
      fw * 0.26,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = fw * 0.08);
  for (final (angle, color) in [
    (a, const Color(0xFFFFD54F)),
    (a + math.pi / 2, const Color(0xFF4FC3F7))
  ]) {
    c.save();
    c.translate(hub.dx, hub.dy);
    c.rotate(angle);
    final r = Rect.fromCenter(
        center: Offset.zero, width: fw * 0.52, height: fw * 0.09);
    c.drawOval(r, pgrad(r, [color, Color.lerp(color, Colors.black, 0.25)!]));
    c.restore();
  }
  c.drawCircle(hub, fw * 0.035,
      prad(hub.translate(-fw * 0.01, -fw * 0.01), fw * 0.04,
          [const Color(0xFF9E9E9E), const Color(0xFF515151)]));
}

// ---- Ponponlu bere ----
void _beanie(Canvas c, FaceGeom g, Offset top) {
  final fw = g.fw, fh = g.fh;
  final cx = top.dx;
  final base = top.dy + fh * 0.10;
  final dome = Path()
    ..moveTo(cx - fw * 0.38, base)
    ..arcToPoint(Offset(cx + fw * 0.38, base),
        radius: Radius.circular(fw * 0.40))
    ..close();
  softShadow(c, dome, fw * 0.035);
  c.drawPath(
      dome,
      pgrad(dome.getBounds(), [const Color(0xFFFF8A65), const Color(0xFFE64A19)]));
  // Örgü izleri
  c.save();
  c.clipPath(dome);
  for (var i = -2; i <= 2; i++) {
    final x = cx + i * fw * 0.14;
    c.drawLine(Offset(x, base), Offset(cx + i * fw * 0.05, base - fh * 0.42),
        ps(const Color(0xFFD84315).withValues(alpha: 0.7), fw * 0.02));
  }
  gloss(c, Offset(cx - fw * 0.10, base - fh * 0.26), fw * 0.16, fh * 0.12,
      alpha: 0.18);
  c.restore();
  // Katlama bandı
  final band = RRect.fromRectAndRadius(
    Rect.fromCenter(
        center: Offset(cx, base), width: fw * 0.80, height: fh * 0.14),
    Radius.circular(fw * 0.05),
  );
  c.drawRRect(band,
      pgrad(band.outerRect, [const Color(0xFFFFAB91), const Color(0xFFFF7043)]));
  // Ponpon: tüylü görünüm için iç içe iki doku
  final pom = Offset(cx, base - fh * 0.44);
  c.drawCircle(
      pom,
      fw * 0.085,
      Paint()
        ..color = Colors.white
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, fw * 0.02));
  c.drawCircle(pom.translate(-fw * 0.02, -fw * 0.02), fw * 0.04,
      pf(Colors.white));
}

// ---- Tek boynuz ----
void _unicorn(Canvas c, FaceGeom g, Offset top, double t) {
  final fw = g.fw, fh = g.fh;
  final cx = top.dx;
  final base = top.dy + fh * 0.04;
  // Kulaklar
  for (final side in [-1, 1]) {
    final bx = cx + side * fw * 0.26;
    final ear = Path()
      ..moveTo(bx - fw * 0.09, base + fh * 0.02)
      ..quadraticBezierTo(bx + side * fw * 0.01, base - fh * 0.12,
          bx + side * fw * 0.03, base - fh * 0.20)
      ..quadraticBezierTo(bx + side * fw * 0.06, base - fh * 0.10,
          bx + fw * 0.09, base + fh * 0.02)
      ..close();
    softShadow(c, ear, fw * 0.02);
    c.drawPath(
        ear, pgrad(ear.getBounds(), [Colors.white, const Color(0xFFE8E0DC)]));
    final inner = Path()
      ..moveTo(bx - fw * 0.045, base + fh * 0.01)
      ..lineTo(bx + side * fw * 0.02, base - fh * 0.13)
      ..lineTo(bx + fw * 0.045, base + fh * 0.01)
      ..close();
    c.drawPath(
        inner,
        Paint()
          ..color = const Color(0xFFF8BBD0)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, fw * 0.01));
  }
  // Boynuz: altın degrade + spiral
  final horn = Path()
    ..moveTo(cx - fw * 0.065, base)
    ..lineTo(cx, base - fh * 0.54)
    ..lineTo(cx + fw * 0.065, base)
    ..close();
  softShadow(c, horn, fw * 0.025);
  c.drawPath(
      horn,
      pgrad(horn.getBounds(),
          [const Color(0xFFFFE082), const Color(0xFFF9A825)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter));
  c.save();
  c.clipPath(horn);
  for (var i = 1; i <= 4; i++) {
    final y = base - fh * 0.105 * i;
    c.drawLine(
        Offset(cx - fw * 0.07, y + fh * 0.03),
        Offset(cx + fw * 0.07, y - fh * 0.02),
        ps(const Color(0xFFE09E14), fw * 0.016));
  }
  c.restore();
  // Boynuz ucunda dönen ışıltı
  final tw = 0.5 + 0.5 * math.sin(t * 4);
  c.drawPath(
      starPath(Offset(cx, base - fh * 0.56), fw * (0.02 + 0.025 * tw),
          inner: 0.3),
      pf(Colors.white.withValues(alpha: 0.6 + 0.4 * tw)));
  // Boynuz dibinde minik çiçekler
  drawFlower(c, Offset(cx - fw * 0.12, base + fh * 0.015), fw * 0.05,
      const Color(0xFFF48FB1), const Color(0xFFFFB300));
  drawFlower(c, Offset(cx + fw * 0.12, base + fh * 0.015), fw * 0.05,
      const Color(0xFF90CAF9), const Color(0xFFFFB300));
}
