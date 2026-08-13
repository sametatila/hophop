import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'fx_frame.dart';

/// Efekt ressamlarının ortak araçları.

Paint pf(Color color) => Paint()..color = color;

Paint ps(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round;

/// Deterministik sözde-rastgele [0,1) — parçacıklar her karede aynı
/// tohumla üretilir, animasyon yalnızca zamana bağlıdır.
double rnd(int i, [int salt = 0]) {
  final v = math.sin(i * 127.1 + salt * 311.7 + 13.7) * 43758.5453;
  return v - v.floorToDouble();
}

double frac(double v) => v - v.floorToDouble();

Path heartPath(Offset c, double r) => Path()
  ..moveTo(c.dx, c.dy + r * 0.95)
  ..cubicTo(c.dx - r * 1.35, c.dy + r * 0.10, c.dx - r * 0.85,
      c.dy - r * 0.95, c.dx, c.dy - r * 0.30)
  ..cubicTo(c.dx + r * 0.85, c.dy - r * 0.95, c.dx + r * 1.35,
      c.dy + r * 0.10, c.dx, c.dy + r * 0.95)
  ..close();

Path starPath(Offset c, double r,
    {int points = 5, double inner = 0.45, double rot = -math.pi / 2}) {
  final p = Path();
  for (var i = 0; i < points * 2; i++) {
    final rad = i.isEven ? r : r * inner;
    final a = rot + i * math.pi / points;
    final o = Offset(c.dx + rad * math.cos(a), c.dy + rad * math.sin(a));
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  return p..close();
}

/// 5 yapraklı basit çiçek.
void drawFlower(Canvas c, Offset center, double r, Color petal, Color mid) {
  for (var i = 0; i < 5; i++) {
    final a = i * 2 * math.pi / 5 - math.pi / 2;
    c.drawCircle(
      Offset(center.dx + r * 0.62 * math.cos(a),
          center.dy + r * 0.62 * math.sin(a)),
      r * 0.42,
      pf(petal),
    );
  }
  c.drawCircle(center, r * 0.30, pf(mid));
}

/// Göz/burun konumları — ML Kit işaret noktası yoksa yüz kutusundan türetilir.
({Offset l, Offset r, Offset n}) landmarks(FxFrame f, Size s) {
  final cx = f.cx * s.width, cy = f.cy * s.height;
  final fw = f.w * s.width, fh = f.h * s.height;
  final hasEyes = !(f.lx == 0 && f.ly == 0) || !(f.rx == 0 && f.ry == 0);
  final l = hasEyes
      ? Offset(f.lx * s.width, f.ly * s.height)
      : Offset(cx - fw * 0.19, cy - fh * 0.08);
  final r = hasEyes
      ? Offset(f.rx * s.width, f.ry * s.height)
      : Offset(cx + fw * 0.19, cy - fh * 0.08);
  final n = f.nx == 0 && f.ny == 0
      ? Offset(cx, cy + fh * 0.10)
      : Offset(f.nx * s.width, f.ny * s.height);
  return (l: l, r: r, n: n);
}
