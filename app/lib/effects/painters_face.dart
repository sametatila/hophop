import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'fx_frame.dart';
import 'painter_util.dart';

/// Yüz aksesuarları — kontur çapalarına oturur: gözlükler gerçek göz
/// köşelerine, ruj gerçek dudak hattına, allık gerçek yanaklara. Kontur
/// noktaları kafa duruşunu zaten taşıdığı için görüntü uzayında çizilir;
/// yaw yalnızca hafif asimetri (yakın cam büyük, uzak cam küçük) için
/// kullanılır.
void paintFaceFx(String id, Canvas c, Size s, FaceGeom g, double t) {
  switch (id) {
    case 'glasses':
      _glasses(c, g);
    case 'sun':
      _sunglasses(c, g);
    case 'heartgl':
      _heartGlasses(c, g, t);
    case 'stargl':
      _starGlasses(c, g, t);
    case 'mustache':
      _mustache(c, g);
    case 'clown':
      _clown(c, g);
    case 'blush':
      _blush(c, g);
    case 'hero':
      _heroMask(c, g);
    case 'robot':
      _robot(c, g, t);
    case 'patch':
      _piratePatch(c, g);
    case 'lipstick':
      _lipstick(c, g);
    case 'butterfly':
      _butterfly(c, g, t);
  }
}

/// Yaw'a göre cam ölçekleri: kafa dönünce uzak cam küçülür — üç boyut hissi.
(double, double) _lensScales(FaceGeom g) {
  final k = (g.f.yaw * 0.55).clamp(-0.28, 0.28);
  return (1 - k, 1 + k);
}

/// Gözlük sapları: cam kenarından yüz ovalinin şakak noktasına.
void _temples(Canvas c, FaceGeom g, Offset l, Offset r, double lw, double rw,
    Paint stroke) {
  final tl = g.pt(P.oval + 15);
  final tr = g.pt(P.oval + 3);
  c.drawLine(l.translate(-lw, 0), Offset(tl.dx, tl.dy - g.fh * 0.02), stroke);
  c.drawLine(r.translate(rw, 0), Offset(tr.dx, tr.dy - g.fh * 0.02), stroke);
}

// ---- Kocaman komik gözlük ----
void _glasses(Canvas c, FaceGeom g) {
  final fw = g.fw;
  final l = g.eyeLc, r = g.eyeRc;
  final (sl, sr) = _lensScales(g);
  final radius = math.max(g.eyeSpan * 0.34, fw * 0.16);
  final stroke = ps(const Color(0xFF1A1A1A), fw * 0.045);
  for (final (e, sc) in [(l, sl), (r, sr)]) {
    final rr = radius * sc;
    // Cam: hafif mavi yansımalı
    c.drawCircle(
        e,
        rr,
        prad(e.translate(-rr * 0.3, -rr * 0.3), rr * 1.4, [
          Colors.white.withValues(alpha: 0.35),
          const Color(0xFFB3E5FC).withValues(alpha: 0.12)
        ]));
    c.drawCircle(e, rr, stroke);
    c.drawCircle(e, rr - fw * 0.02,
        ps(Colors.white.withValues(alpha: 0.25), fw * 0.012));
    // Parlama şeridi
    c.drawArc(Rect.fromCircle(center: e, radius: rr * 0.7), -2.4, 0.9, false,
        ps(Colors.white.withValues(alpha: 0.55), fw * 0.025));
  }
  // Köprü: burun köprüsü üstünden
  final nb = g.pt(P.noseTop);
  final bridge = Path()
    ..moveTo(l.dx + radius * sl, l.dy)
    ..quadraticBezierTo(nb.dx, nb.dy - fw * 0.03, r.dx - radius * sr, r.dy);
  c.drawPath(bridge, stroke..style = PaintingStyle.stroke);
  _temples(c, g, l, r, radius * sl, radius * sr, stroke);
}

// ---- Güneş gözlüğü ----
void _sunglasses(Canvas c, FaceGeom g) {
  final fw = g.fw;
  final l = g.eyeLc, r = g.eyeRc;
  final (sl, sr) = _lensScales(g);
  final w = math.max(g.eyeSpan * 0.52, fw * 0.26);
  final frame = ps(const Color(0xFF1A1A1A), fw * 0.03);
  for (final (e, sc) in [(l, sl), (r, sr)]) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: e, width: w * sc, height: w * 0.72 * sc),
      Radius.circular(fw * 0.08),
    );
    softShadow(c, Path()..addRRect(rect), fw * 0.02,
        offset: Offset(0, fw * 0.015));
    // Cam: koyu degrade + gökyüzü yansıması
    c.drawRRect(
        rect,
        pgrad(rect.outerRect,
            [const Color(0xFF37474F), const Color(0xFF0D1418)]));
    c.save();
    c.clipRRect(rect);
    c.drawLine(
        Offset(e.dx - w * 0.28 * sc, e.dy - w * 0.20 * sc),
        Offset(e.dx + w * 0.05 * sc, e.dy + w * 0.28 * sc),
        ps(Colors.white.withValues(alpha: 0.35), fw * 0.05));
    c.drawLine(
        Offset(e.dx - w * 0.16 * sc, e.dy - w * 0.24 * sc),
        Offset(e.dx + w * 0.16 * sc, e.dy + w * 0.24 * sc),
        ps(Colors.white.withValues(alpha: 0.18), fw * 0.10));
    c.restore();
    c.drawRRect(rect, frame);
  }
  final nb = g.pt(P.noseTop);
  final bridge = Path()
    ..moveTo(l.dx + w * sl * 0.5, l.dy - fw * 0.03)
    ..quadraticBezierTo(
        nb.dx, nb.dy - fw * 0.05, r.dx - w * sr * 0.5, r.dy - fw * 0.03);
  c.drawPath(bridge, ps(const Color(0xFF1A1A1A), fw * 0.035));
  _temples(c, g, l.translate(0, -fw * 0.03), r.translate(0, -fw * 0.03),
      w * sl * 0.5, w * sr * 0.5, ps(const Color(0xFF1A1A1A), fw * 0.035));
}

// ---- Kalp gözlük ----
void _heartGlasses(Canvas c, FaceGeom g, double t) {
  final fw = g.fw;
  final l = g.eyeLc, r = g.eyeRc;
  final (sl, sr) = _lensScales(g);
  // Gülümseyince kalpler hafif büyür + atar
  final beat = 1 + 0.05 * g.smile * math.sin(t * 8);
  final base = math.max(g.eyeSpan * 0.36, fw * 0.17);
  for (final (e, sc) in [(l, sl), (r, sr)]) {
    final rr = base * sc * beat;
    final h = heartPath(e, rr);
    softShadow(c, h, fw * 0.02, offset: Offset(0, fw * 0.015));
    c.drawPath(
        h,
        pgrad(h.getBounds(),
            [const Color(0xFFFF6FA5), const Color(0xFFE91E63)]));
    c.drawPath(h, ps(Colors.white.withValues(alpha: 0.5), fw * 0.012));
    c.drawCircle(Offset(e.dx - rr * 0.35, e.dy - rr * 0.35), rr * 0.16,
        pf(Colors.white.withValues(alpha: 0.75)));
  }
  c.drawLine(l.translate(base * sl * 0.7, 0), r.translate(-base * sr * 0.7, 0),
      ps(const Color(0xFFE91E63), fw * 0.035));
}

// ---- Yıldız gözlük ----
void _starGlasses(Canvas c, FaceGeom g, double t) {
  final fw = g.fw;
  final l = g.eyeLc, r = g.eyeRc;
  final (sl, sr) = _lensScales(g);
  final base = math.max(g.eyeSpan * 0.42, fw * 0.20);
  for (final (i, (e, sc)) in [(0, (l, sl)), (1, (r, sr))]) {
    final star = starPath(e, base * sc, rot: -math.pi / 2 + math.sin(t + i) * 0.06);
    softShadow(c, star, fw * 0.02, offset: Offset(0, fw * 0.015));
    c.drawPath(
        star,
        pgrad(star.getBounds(),
            [const Color(0xFFFFE082), const Color(0xFFF9A825)]));
    c.drawPath(star, ps(const Color(0xFFF57F17), fw * 0.018));
    // Dönen ışıltı beneği
    final a = t * 2 + i * math.pi;
    c.drawCircle(
        Offset(e.dx + math.cos(a) * base * 0.3, e.dy + math.sin(a) * base * 0.3),
        fw * 0.02,
        pf(Colors.white.withValues(alpha: 0.8)));
  }
  c.drawLine(l.translate(base * sl * 0.6, 0), r.translate(-base * sr * 0.6, 0),
      ps(const Color(0xFFF9A825), fw * 0.035));
}

// ---- Pos bıyık ----
void _mustache(Canvas c, FaceGeom g) {
  final fw = g.fw;
  // Burun altı ile üst dudak arasına oturur; gülümseyince uçlar kalkar.
  final n = g.pt(P.noseBotC);
  final lift = fw * 0.05 * g.smile;
  final path = Path();
  for (final side in [-1, 1]) {
    path
      ..moveTo(n.dx, n.dy + fw * 0.09)
      ..quadraticBezierTo(
        n.dx + side * fw * 0.25, n.dy + fw * 0.01,
        n.dx + side * fw * 0.42, n.dy + fw * 0.13 - lift,
      )
      ..quadraticBezierTo(
        n.dx + side * fw * 0.28, n.dy + fw * 0.25,
        n.dx, n.dy + fw * 0.17,
      )
      ..close();
  }
  softShadow(c, path, fw * 0.02, offset: Offset(0, fw * 0.015));
  c.drawPath(
      path,
      pgrad(path.getBounds(), [const Color(0xFF5D4037), const Color(0xFF2B1A14)]));
  // Tarama izleri
  final comb = ps(const Color(0xFF6D4C41).withValues(alpha: 0.6), fw * 0.008);
  for (final side in [-1, 1]) {
    for (var i = 1; i <= 3; i++) {
      final x = n.dx + side * fw * 0.10 * i;
      c.drawLine(Offset(x, n.dy + fw * 0.10),
          Offset(x + side * fw * 0.05, n.dy + fw * 0.16), comb);
    }
  }
}

// ---- Palyaço: kırmızı burun + pembe yanaklar ----
void _clown(Canvas c, FaceGeom g) {
  final fw = g.fw;
  for (final i in [P.cheekL, P.cheekR]) {
    final ck = g.pt(i);
    c.drawCircle(
        ck,
        fw * 0.10,
        prad(ck, fw * 0.11, [
          const Color(0xFFF48FB1).withValues(alpha: 0.7),
          const Color(0xFFF48FB1).withValues(alpha: 0)
        ]));
  }
  final n = g.pt(P.noseTip);
  final nose = Path()..addOval(Rect.fromCircle(center: n, radius: fw * 0.13));
  softShadow(c, nose, fw * 0.03, offset: Offset(0, fw * 0.02));
  c.drawCircle(
      n,
      fw * 0.13,
      prad(n.translate(-fw * 0.04, -fw * 0.04), fw * 0.16,
          [const Color(0xFFFF6659), const Color(0xFFC62828)]));
  c.drawCircle(Offset(n.dx - fw * 0.045, n.dy - fw * 0.045), fw * 0.035,
      pf(Colors.white.withValues(alpha: 0.8)));
}

// ---- Çiller + pembe yanaklar ----
void _blush(Canvas c, FaceGeom g) {
  final fw = g.fw;
  final freckle = pf(const Color(0xFF8D6E63).withValues(alpha: 0.75));
  // Allık: gülümseyince koyulaşır — gerçek yanak çapasında
  final blushAlpha = 0.35 + 0.3 * g.smile;
  for (final i in [P.cheekL, P.cheekR]) {
    final ck = g.pt(i);
    c.drawCircle(
        ck,
        fw * 0.11,
        prad(ck, fw * 0.12, [
          const Color(0xFFF8BBD0).withValues(alpha: blushAlpha),
          const Color(0xFFF8BBD0).withValues(alpha: 0)
        ]));
    for (final (dx, dy) in [(-0.03, -0.02), (0.03, -0.03), (0.0, 0.03)]) {
      c.drawCircle(
          Offset(ck.dx + fw * dx, ck.dy + fw * dy), fw * 0.013, freckle);
    }
  }
  // Burun köprüsünde çil serpintisi
  final nb = g.pt(P.noseTop);
  for (var i = 0; i < 5; i++) {
    c.drawCircle(
        Offset(nb.dx + (rnd(i) - 0.5) * fw * 0.22,
            nb.dy + fw * 0.05 + (rnd(i, 7) - 0.5) * fw * 0.06),
        fw * 0.011,
        freckle);
  }
}

// ---- Kahraman maskesi ----
void _heroMask(Canvas c, FaceGeom g) {
  final fw = g.fw, fh = g.fh;
  final l = g.eyeLc, r = g.eyeRc;
  final mid = Offset.lerp(l, r, 0.5)!;
  // Maske yüz kenarlarına uzanır (oval şakak noktaları)
  final tl = g.pt(P.oval + 15), tr = g.pt(P.oval + 3);
  final mask = Path()
    ..moveTo(tl.dx, tl.dy)
    ..quadraticBezierTo(
        mid.dx - fw * 0.30, mid.dy - fw * 0.22, mid.dx, mid.dy - fw * 0.15)
    ..quadraticBezierTo(mid.dx + fw * 0.30, mid.dy - fw * 0.22, tr.dx, tr.dy)
    ..quadraticBezierTo(
        mid.dx + fw * 0.34, mid.dy + fw * 0.17, mid.dx, mid.dy + fw * 0.13)
    ..quadraticBezierTo(mid.dx - fw * 0.34, mid.dy + fw * 0.17, tl.dx, tl.dy)
    ..close();
  // Göz delikleri gerçek göz boyutundan (evenOdd: içinden video görünür)
  for (final e in [l, r]) {
    mask.addOval(Rect.fromCenter(
        center: e,
        width: math.max(g.eyeSpan * 0.34, fw * 0.15),
        height: math.max(fh * 0.09, fw * 0.10)));
  }
  mask.fillType = PathFillType.evenOdd;
  softShadow(c, mask, fw * 0.02, offset: Offset(0, fw * 0.015));
  c.drawPath(
      mask,
      pgrad(mask.getBounds(), [const Color(0xFFEF5350), const Color(0xFFB71C1C)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter));
  c.drawPath(mask, ps(const Color(0xFF8E1414), fw * 0.018));
  gloss(c, mid.translate(0, -fw * 0.10), fw * 0.35, fw * 0.08, alpha: 0.18);
}

// ---- Robot: vizör + anten ----
void _robot(Canvas c, FaceGeom g, double t) {
  final fw = g.fw, fh = g.fh;
  final l = g.eyeLc, r = g.eyeRc;
  final mid = Offset.lerp(l, r, 0.5)!;
  final tl = g.pt(P.oval + 15), tr = g.pt(P.oval + 3);
  final width = (tr.dx - tl.dx).abs() + fw * 0.08;
  final visor = RRect.fromRectAndRadius(
    Rect.fromCenter(center: mid, width: width, height: fw * 0.30),
    Radius.circular(fw * 0.10),
  );
  softShadow(c, Path()..addRRect(visor), fw * 0.025);
  c.drawRRect(
      visor,
      pgrad(visor.outerRect,
          [const Color(0xFFB0BEC5), const Color(0xFF78909C)]));
  // Işıklı yarık + kayan tarama çizgisi
  final slit = RRect.fromRectAndRadius(
    Rect.fromCenter(center: mid, width: width * 0.86, height: fw * 0.10),
    Radius.circular(fw * 0.05),
  );
  c.drawRRect(slit, pf(const Color(0xFF002A30)));
  c.save();
  c.clipRRect(slit);
  final scanX = mid.dx + (frac(t * 0.5) * 2 - 1) * width * 0.43;
  c.drawCircle(
      Offset(scanX, mid.dy),
      fw * 0.06,
      prad(Offset(scanX, mid.dy), fw * 0.07,
          [const Color(0xFF00E5FF), const Color(0xFF00E5FF).withValues(alpha: 0)]));
  c.drawLine(Offset(scanX, mid.dy - fw * 0.05), Offset(scanX, mid.dy + fw * 0.05),
      ps(const Color(0xFF84FFFF), fw * 0.02));
  c.restore();
  // Yan cıvatalar
  for (final e in [Offset(tl.dx, mid.dy), Offset(tr.dx, mid.dy)]) {
    c.drawCircle(e, fw * 0.05,
        prad(e.translate(-fw * 0.012, -fw * 0.012), fw * 0.06,
            [const Color(0xFF90A4AE), const Color(0xFF455A64)]));
    c.drawCircle(e, fw * 0.02, pf(const Color(0xFF37474F)));
  }
  // Anten: tepe noktasından, ucu yanıp söner
  final top = g.pt(P.oval);
  c.drawLine(top, Offset(top.dx, top.dy - fh * 0.20),
      ps(const Color(0xFF78909C), fw * 0.03));
  final blink = 0.5 + 0.5 * math.sin(t * 6);
  final bulb = Offset(top.dx, top.dy - fh * 0.23);
  c.drawCircle(
      bulb,
      fw * 0.05 + fw * 0.012 * blink,
      prad(bulb, fw * 0.08, [
        Color.lerp(const Color(0xFF8E1414), const Color(0xFFFF5252), blink)!,
        Color.lerp(const Color(0xFF8E1414), const Color(0xFFFF5252), blink)!
            .withValues(alpha: 0.2)
      ]));
}

// ---- Korsan göz bandı ----
void _piratePatch(Canvas c, FaceGeom g) {
  final fw = g.fw;
  final eye = g.eyeRc;
  final tl = g.pt(P.oval + 15), tr = g.pt(P.oval + 3);
  final strap = ps(const Color(0xFF212121), fw * 0.045);
  // Bant: gözden yüz kenarlarına
  c.drawLine(Offset(eye.dx - fw * 0.14, eye.dy - fw * 0.05),
      Offset(tl.dx, tl.dy - fw * 0.10), strap);
  c.drawLine(Offset(eye.dx + fw * 0.13, eye.dy - fw * 0.06),
      Offset(tr.dx, tr.dy - fw * 0.14), strap);
  final patchRect = Rect.fromCenter(
      center: Offset(eye.dx, eye.dy + fw * 0.01),
      width: fw * 0.30,
      height: fw * 0.26);
  final patch = Path()..addOval(patchRect);
  softShadow(c, patch, fw * 0.02, offset: Offset(0, fw * 0.015));
  c.drawOval(patchRect,
      pgrad(patchRect, [const Color(0xFF37474F), const Color(0xFF111111)]));
  // Deri dokusu izi
  c.drawArc(patchRect.deflate(fw * 0.04), -2.6, 1.2, false,
      ps(Colors.white.withValues(alpha: 0.12), fw * 0.02));
}

// ---- Ruj: gerçek dudak hattını doldurur ----
void _lipstick(Canvas c, FaceGeom g) {
  final fw = g.fw;
  final cl = g.pt(P.lipT); // sol köşe
  final cupid = g.pt(P.lipT + 1);
  final cr = g.pt(P.lipT + 2);
  final bl = g.pt(P.lipB), bm = g.pt(P.lipB + 1), br = g.pt(P.lipB + 2);
  final inT = g.pt(P.lipInT), inB = g.pt(P.lipInB);
  // Dış hat: köşeler + kupidon + alt orta noktalardan pürüzsüz eğri
  final outer = smoothClosed([
    cl,
    Offset.lerp(cl, cupid, 0.5)!.translate(0, -fw * 0.015),
    cupid.translate(0, -fw * 0.005),
    Offset.lerp(cupid, cr, 0.5)!.translate(0, -fw * 0.015),
    cr,
    br,
    bm.translate(0, fw * 0.01),
    bl,
  ]);
  c.drawPath(
      outer,
      pgrad(outer.getBounds(), [const Color(0xFFE5397A), const Color(0xFFB4124E)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter));
  // Ağız açıksa iç boşluğu koyult
  if (g.mouth > 0.1) {
    final inner = smoothClosed([
      Offset.lerp(cl, inT, 0.6)!,
      inT,
      Offset.lerp(cr, inT, 0.6)!,
      Offset.lerp(cr, inB, 0.6)!,
      inB,
      Offset.lerp(cl, inB, 0.6)!,
    ]);
    c.drawPath(inner, pf(const Color(0xFF4A0A20).withValues(alpha: 0.85)));
  }
  // Parlaklık: alt dudakta ışık
  final glossC = Offset.lerp(inB, bm, 0.45)!;
  c.drawOval(
      Rect.fromCenter(
          center: glossC, width: fw * 0.16, height: fw * 0.045),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, fw * 0.02));
}

// ---- Kelebek yüz boyaması: kanatlar yanaklarda, gövde burun köprüsünde ----
void _butterfly(Canvas c, FaceGeom g, double t) {
  final fw = g.fw, fh = g.fh;
  final nb = g.pt(P.noseTop);
  // Kanat çırpma: yatay ölçek nefes alır
  final flap = 0.88 + 0.12 * math.sin(t * 3).abs();
  for (final (side, cheekI, browI) in [(-1, P.cheekL, P.browL), (1, P.cheekR, P.browR)]) {
    final cheek = g.pt(cheekI);
    final brow = g.pt(browI + 1);
    // Üst kanat: kaş üstünden yanağa
    final upper = Path()
      ..moveTo(nb.dx, nb.dy)
      ..cubicTo(
          nb.dx + side * fw * 0.30 * flap, brow.dy - fh * 0.16,
          nb.dx + side * fw * 0.52 * flap, brow.dy - fh * 0.04,
          nb.dx + side * fw * 0.40 * flap, cheek.dy - fh * 0.06)
      ..quadraticBezierTo(
          nb.dx + side * fw * 0.22 * flap, cheek.dy - fh * 0.04,
          nb.dx, nb.dy + fh * 0.06)
      ..close();
    // Alt kanat: yanak
    final lower = Path()
      ..moveTo(nb.dx, nb.dy + fh * 0.05)
      ..cubicTo(
          nb.dx + side * fw * 0.34 * flap, cheek.dy - fh * 0.02,
          nb.dx + side * fw * 0.30 * flap, cheek.dy + fh * 0.14,
          nb.dx + side * fw * 0.10 * flap, cheek.dy + fh * 0.10)
      ..quadraticBezierTo(
          nb.dx + side * fw * 0.04, cheek.dy + fh * 0.02, nb.dx, nb.dy + fh * 0.07)
      ..close();
    for (final (wing, colors) in [
      (upper, [const Color(0xFF7C4DFF), const Color(0xFFE040FB)]),
      (lower, [const Color(0xFFE040FB), const Color(0xFFFF80AB)]),
    ]) {
      c.drawPath(
          wing,
          Paint()
            ..shader = LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                  colors[0].withValues(alpha: 0.75),
                  colors[1].withValues(alpha: 0.60)
                ]).createShader(wing.getBounds())
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, fw * 0.008));
      c.drawPath(wing, ps(Colors.white.withValues(alpha: 0.45), fw * 0.012));
    }
    // Kanat benekleri
    c.drawCircle(
        Offset(nb.dx + side * fw * 0.30 * flap, brow.dy + fh * 0.01),
        fw * 0.030,
        pf(Colors.white.withValues(alpha: 0.55)));
    c.drawCircle(
        Offset(nb.dx + side * fw * 0.20 * flap, cheek.dy + fh * 0.05),
        fw * 0.020,
        pf(Colors.white.withValues(alpha: 0.45)));
  }
  // Gövde + antenler
  final body = Rect.fromCenter(
      center: Offset(nb.dx, nb.dy + fh * 0.03),
      width: fw * 0.045,
      height: fh * 0.16);
  c.drawRRect(RRect.fromRectAndRadius(body, Radius.circular(fw * 0.02)),
      pgrad(body, [const Color(0xFF4A148C), const Color(0xFF7B1FA2)]));
  for (final side in [-1, 1]) {
    final ant = Path()
      ..moveTo(nb.dx, nb.dy - fh * 0.05)
      ..quadraticBezierTo(nb.dx + side * fw * 0.05, nb.dy - fh * 0.10,
          nb.dx + side * fw * 0.08, nb.dy - fh * 0.12);
    c.drawPath(ant, ps(const Color(0xFF4A148C), fw * 0.012));
    c.drawCircle(Offset(nb.dx + side * fw * 0.08, nb.dy - fh * 0.12),
        fw * 0.014, pf(const Color(0xFFE040FB)));
  }
}
