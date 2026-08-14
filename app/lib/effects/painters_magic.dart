import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'fx_frame.dart';
import 'painter_util.dart';

/// Sihir efektleri: zamana bağlı parçacıklar. Yüz algılanamasa da çalışır
/// (yüz merkezine sabitlenenler ekran ortasına düşer); kafa eğimiyle DÖNMEZ.
void paintMagicFx(String id, Canvas c, Size s, FxFrame f, double t) {
  final hasFace = f.hasFace && f.w > 0.01;
  final cx = (hasFace ? f.cx : 0.5) * s.width;
  final cy = (hasFace ? f.cy : 0.45) * s.height;
  final fw = (hasFace ? f.w : 0.45) * s.width;
  final fh = (hasFace ? f.h : 0.40) * s.height;
  switch (id) {
    case 'hearts':
      _hearts(c, s, cx, cy, fw, fh, t);
    case 'stars':
      _stars(c, cx, cy, fw, fh, t);
    case 'sparkle':
      _sparkle(c, cx, cy, fw, fh, t);
    case 'rainbow':
      _rainbow(c, cx, cy, fw, fh);
    case 'rmouth':
      _rainbowMouth(c, s, f, fw, fh, t, hasFace);
    case 'snow':
      _snow(c, s, t);
    case 'bubbles':
      _bubbles(c, s, t);
    case 'confetti':
      _confetti(c, s, t);
    case 'notes':
      _notes(c, s, cx, cy, fw, fh, t);
  }
}

const _heartColors = [
  Color(0xFFFF4081),
  Color(0xFFF06292),
  Color(0xFFFF8A80),
  Color(0xFFE91E63),
];

// ---- Yüzün çevresinden süzülen kalpler ----
void _hearts(Canvas c, Size s, double cx, double cy, double fw, double fh,
    double t) {
  for (var i = 0; i < 12; i++) {
    final cycle = frac(t * 0.22 + rnd(i));
    final x = cx +
        (rnd(i, 1) - 0.5) * fw * 2.2 +
        math.sin((t + i) * 1.3) * fw * 0.06;
    final y = cy + fh * 0.55 - cycle * fh * 1.9;
    final r = fw * (0.05 + 0.05 * rnd(i, 2)) * (0.6 + 0.4 * cycle);
    final alpha = (1 - cycle) * 0.9;
    final color = _heartColors[i % _heartColors.length];
    final ctr = Offset(x, y);
    // Işıma + degrade dolgu + minik parlama: hacimli kalp
    c.drawCircle(
        ctr,
        r * 1.6,
        prad(ctr, r * 1.6, [
          color.withValues(alpha: alpha * 0.25),
          color.withValues(alpha: 0)
        ]));
    final h = heartPath(ctr, r);
    c.drawPath(
        h,
        Paint()
          ..shader = RadialGradient(colors: [
            Color.lerp(color, Colors.white, 0.35)!.withValues(alpha: alpha),
            color.withValues(alpha: alpha)
          ]).createShader(
              Rect.fromCircle(center: ctr.translate(-r * 0.3, -r * 0.4), radius: r * 1.6)));
    c.drawCircle(ctr.translate(-r * 0.35, -r * 0.35), r * 0.15,
        pf(Colors.white.withValues(alpha: alpha * 0.8)));
  }
}

// ---- Başın üstünde göz kırpan yıldızlar ----
void _stars(Canvas c, double cx, double cy, double fw, double fh, double t) {
  for (var i = 0; i < 8; i++) {
    final a = math.pi * (1.08 + 0.84 * i / 7); // üst yay
    final pos = Offset(
        cx + fw * 0.85 * math.cos(a), cy + fh * 0.75 * math.sin(a));
    final tw = 0.35 + 0.65 * math.sin(t * 2.4 + i * 1.7).abs();
    final r = fw * (0.055 + 0.03 * rnd(i));
    c.drawCircle(
        pos,
        r * 1.8 * tw,
        prad(pos, r * 1.8 * tw, [
          const Color(0xFFFFF59D).withValues(alpha: 0.35 * tw),
          const Color(0xFFFFF59D).withValues(alpha: 0)
        ]));
    c.drawPath(
      starPath(pos, r, rot: -math.pi / 2 + math.sin(t + i) * 0.3),
      pf(const Color(0xFFFFD54F).withValues(alpha: tw)),
    );
    c.drawPath(
      starPath(pos, r * 0.45, rot: -math.pi / 2 + math.sin(t + i) * 0.3),
      pf(Colors.white.withValues(alpha: tw * 0.7)),
    );
  }
}

// ---- Yüzün çevresinde parıltılar ----
void _sparkle(Canvas c, double cx, double cy, double fw, double fh, double t) {
  for (var i = 0; i < 14; i++) {
    final phase = frac(t * 0.8 + rnd(i));
    if (phase > 0.55) continue; // parıltı kısa yaşar
    final scale = math.sin(math.pi * phase / 0.55);
    final pos = Offset(
      cx + (rnd(i, 1) - 0.5) * fw * 2.4,
      cy + (rnd(i, 2) - 0.5) * fh * 2.0,
    );
    final r = fw * (0.04 + 0.05 * rnd(i, 3)) * scale;
    final color = i.isEven ? Colors.white : const Color(0xFFFFF59D);
    // Çekirdek + çapraz ışın: kamera parıltısı hissi
    c.drawCircle(
        pos,
        r * 1.5,
        prad(pos, r * 1.5, [
          color.withValues(alpha: 0.4 * scale),
          color.withValues(alpha: 0)
        ]));
    c.drawPath(starPath(pos, r, points: 4, inner: 0.18),
        pf(color.withValues(alpha: 0.9 * scale)));
    c.drawPath(
        starPath(pos, r * 0.55, points: 4, inner: 0.18,
            rot: -math.pi / 4),
        pf(color.withValues(alpha: 0.5 * scale)));
  }
}

const _rainbowColors = [
  Color(0xFFE53935),
  Color(0xFFFB8C00),
  Color(0xFFFDD835),
  Color(0xFF43A047),
  Color(0xFF1E88E5),
  Color(0xFF8E24AA),
];

// ---- Başın üstünde gökkuşağı kemeri ----
void _rainbow(Canvas c, double cx, double cy, double fw, double fh) {
  final center = Offset(cx, cy + fh * 0.05);
  final band = fw * 0.055;
  for (var i = 0; i < _rainbowColors.length; i++) {
    final r = fw * 1.06 - i * band;
    c.drawArc(
      Rect.fromCircle(center: center, radius: r),
      math.pi,
      math.pi,
      false,
      ps(_rainbowColors[i].withValues(alpha: 0.85), band),
    );
  }
  // Uçlarda yumuşak bulutlar
  for (final side in [-1, 1]) {
    final base = Offset(cx + side * fw * 0.92, cy + fh * 0.05);
    for (final (dx, dy, r) in [
      (0.0, 0.0, 0.10),
      (-0.06, 0.03, 0.075),
      (0.06, 0.03, 0.075)
    ]) {
      final ctr = base.translate(fw * dx, fw * dy);
      c.drawCircle(
          ctr,
          fw * r,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.9)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, fw * 0.02));
    }
  }
}

// ---- Ağız açılınca gökkuşağı akar (Snapchat klasiği) ----
void _rainbowMouth(Canvas c, Size s, FxFrame f, double fw, double fh,
    double t, bool hasFace) {
  if (!hasFace || f.mouth < 0.2) return;
  // Akış gerçek ağız boşluğundan başlar, genişliği ağız köşelerinden.
  final inB = f.pt(P.lipInB);
  final cl = f.pt(P.lipT), cr = f.pt(P.lipT + 2);
  final mx = inB.dx * s.width;
  final my = inB.dy * s.height;
  final mouthW = ((cr.dx - cl.dx).abs() * s.width).clamp(fw * 0.2, fw * 0.8);
  const steps = 8;
  // Akışın omurgası: aşağı indikçe genişler ve dalgalanır
  final centers = List.generate(steps + 1, (k) {
    final p = k / steps;
    final y = my + (s.height - my) * p;
    final x = mx + math.sin(t * 3.5 + p * 4) * fw * 0.06 * p;
    final half = mouthW * 0.42 * f.mouth + fw * 0.34 * p;
    return (x: x, y: y, half: half);
  });
  final n = _rainbowColors.length;
  for (var i = 0; i < n; i++) {
    final lFrac = i / n * 2 - 1; // -1..1
    final rFrac = (i + 1) / n * 2 - 1;
    final path = Path()
      ..moveTo(centers.first.x + centers.first.half * lFrac, centers.first.y);
    for (final p in centers.skip(1)) {
      path.lineTo(p.x + p.half * lFrac, p.y);
    }
    for (final p in centers.reversed) {
      path.lineTo(p.x + p.half * rFrac, p.y);
    }
    path.close();
    c.drawPath(path, pf(_rainbowColors[i].withValues(alpha: 0.88)));
  }
  // Akışın üstünde hafif parlama
  c.drawLine(
      Offset(centers.first.x - centers.first.half, my),
      Offset(centers.first.x + centers.first.half, my),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = fh * 0.01
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, fh * 0.008));
}

// ---- Kar ----
void _snow(Canvas c, Size s, double t) {
  final unit = s.shortestSide;
  for (var i = 0; i < 36; i++) {
    final fall = frac(rnd(i, 1) + t * (0.05 + 0.06 * rnd(i, 2)));
    final x = frac(rnd(i)) * s.width + math.sin(t * 1.2 + i) * unit * 0.02;
    final y = fall * (s.height + unit * 0.05) - unit * 0.025;
    final r = unit * (0.006 + 0.008 * rnd(i, 3));
    // Derinlik: küçük taneler soluk (arkada), büyükler parlak (önde)
    final depth = 0.5 + 0.5 * rnd(i, 3);
    final white = Colors.white.withValues(alpha: 0.45 + 0.4 * depth);
    if (i % 3 == 0) {
      // Altı kollu tanecik
      final p = ps(white, r * 0.4);
      for (var a = 0; a < 3; a++) {
        final ang = a * math.pi / 3 + t * 0.5;
        c.drawLine(
          Offset(x - r * 1.6 * math.cos(ang), y - r * 1.6 * math.sin(ang)),
          Offset(x + r * 1.6 * math.cos(ang), y + r * 1.6 * math.sin(ang)),
          p,
        );
      }
    } else {
      c.drawCircle(Offset(x, y), r, pf(white));
    }
  }
}

// ---- Baloncuklar ----
void _bubbles(Canvas c, Size s, double t) {
  final unit = s.shortestSide;
  for (var i = 0; i < 16; i++) {
    final rise = frac(rnd(i, 1) + t * (0.05 + 0.05 * rnd(i, 2)));
    final x = frac(rnd(i)) * s.width + math.sin(t * 1.5 + i * 2) * unit * 0.03;
    final y = (1 - rise) * (s.height + unit * 0.08) - unit * 0.04;
    final r = unit * (0.015 + 0.030 * rnd(i, 3));
    final alpha = rise > 0.85 ? (1 - rise) / 0.15 : 1.0;
    final ctr = Offset(x, y);
    // Sabun zarı: kenara doğru gökkuşağı yansıması
    c.drawCircle(
        ctr,
        r,
        Paint()
          ..shader = RadialGradient(stops: const [
            0.0, 0.75, 0.9, 1.0
          ], colors: [
            Colors.white.withValues(alpha: 0.04 * alpha),
            Colors.white.withValues(alpha: 0.08 * alpha),
            const Color(0xFF80DEEA).withValues(alpha: 0.30 * alpha),
            const Color(0xFFF48FB1).withValues(alpha: 0.35 * alpha),
          ]).createShader(Rect.fromCircle(center: ctr, radius: r)));
    c.drawCircle(ctr, r, ps(Colors.white.withValues(alpha: 0.65 * alpha), r * 0.10));
    c.drawArc(Rect.fromCircle(center: ctr, radius: r * 0.7), -2.6, 1.1, false,
        ps(Colors.white.withValues(alpha: 0.8 * alpha), r * 0.14));
  }
}

const _confettiColors = [
  Color(0xFFFF5252),
  Color(0xFFFFD740),
  Color(0xFF40C4FF),
  Color(0xFF69F0AE),
  Color(0xFFFF80AB),
  Color(0xFFB388FF),
];

// ---- Konfeti ----
void _confetti(Canvas c, Size s, double t) {
  final unit = s.shortestSide;
  for (var i = 0; i < 28; i++) {
    final fall = frac(rnd(i, 1) + t * (0.09 + 0.09 * rnd(i, 2)));
    final x = frac(rnd(i)) * s.width + math.sin(t * 2 + i) * unit * 0.03;
    final y = fall * (s.height + unit * 0.06) - unit * 0.03;
    final angle = t * (2 + 3 * rnd(i, 3)) + i;
    c.save();
    c.translate(x, y);
    c.rotate(angle);
    // Dönerken daralıp genişler: 3B takla izlenimi; kenarı koyu ton
    final wobble = 0.3 + 0.7 * math.sin(t * 4 + i * 2).abs();
    final color = _confettiColors[i % _confettiColors.length];
    final rect = Rect.fromCenter(
        center: Offset.zero,
        width: unit * 0.022,
        height: unit * 0.012 * wobble);
    c.drawRect(
        rect,
        pgrad(rect, [color, Color.lerp(color, Colors.black, 0.30)!],
            begin: Alignment.topCenter, end: Alignment.bottomCenter));
    c.restore();
  }
}

// ---- Süzülen notalar ----
void _notes(Canvas c, Size s, double cx, double cy, double fw, double fh,
    double t) {
  for (var i = 0; i < 8; i++) {
    final cycle = frac(t * 0.16 + rnd(i));
    final side = i.isEven ? -1 : 1;
    final x = cx +
        side * fw * (0.75 + 0.45 * rnd(i, 1)) +
        math.sin((t + i) * 1.6) * fw * 0.08;
    final y = cy + fh * 0.45 - cycle * fh * 1.9;
    final r = fw * (0.045 + 0.02 * rnd(i, 2));
    final alpha = (1 - cycle) * 0.92;
    final color = Colors.white.withValues(alpha: alpha);
    c.save();
    c.translate(x, y);
    c.rotate(math.sin(t * 1.2 + i) * 0.15);
    // Gövde (eğik elips) + sap + bayrak
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 2.1, height: r * 1.5),
      pf(color),
    );
    final stemTop = Offset(r * 0.95, -r * 3.2);
    c.drawLine(Offset(r * 0.95, -r * 0.2), stemTop, ps(color, r * 0.35));
    if (i % 2 == 0) {
      final flag = Path()
        ..moveTo(stemTop.dx, stemTop.dy)
        ..quadraticBezierTo(
            stemTop.dx + r * 1.4, stemTop.dy + r * 0.6,
            stemTop.dx + r * 0.9, stemTop.dy + r * 1.8);
      c.drawPath(flag, ps(color, r * 0.32));
    }
    c.restore();
  }
}
