import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'fx_frame.dart';

/// Efekt ressamlarının ortak araçları.
///
/// İki çizim uzayı vardır:
/// 1) Görüntü uzayı — kontur noktaları ([FaceGeom.pt]) kafa duruşunu zaten
///    içerir; dudak/göz/yanak gibi yüze oturan efektler doğrudan bu
///    noktalara çizilir, ek dönüşüm UYGULANMAZ.
/// 2) Kafa uzayı — [withHead] içinde çizilen her şey yüz merkezine göre
///    roll ile döner, yaw/pitch ile perspektif eğilir. Kulak, şapka, boynuz
///    gibi yüz kutusundan taşan parçalar burada, dik durran kutu
///    koordinatlarıyla ([FaceGeom.derolled] çapalarıyla) çizilir — kafa
///    dönünce üç boyutluymuş gibi eğilirler.

Paint pf(Color color) => Paint()..color = color;

Paint ps(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round;

/// Dikey doğrusal degrade — hacim hissinin ucuz yolu.
Paint pgrad(Rect r, List<Color> colors,
    {Alignment begin = Alignment.topCenter,
    Alignment end = Alignment.bottomCenter,
    List<double>? stops}) =>
    Paint()
      ..shader = LinearGradient(
              begin: begin, end: end, colors: colors, stops: stops)
          .createShader(r);

/// Merkezden dışa degrade (parlama, yanak allığı, ışık benekleri).
Paint prad(Offset c, double r, List<Color> colors, {List<double>? stops}) =>
    Paint()
      ..shader = RadialGradient(colors: colors, stops: stops)
          .createShader(Rect.fromCircle(center: c, radius: r));

/// Şeklin altına yumuşak gölge — overlay'i videodan "ayıran" derinlik.
void softShadow(Canvas c, Path p, double blur,
    {Offset offset = const Offset(0, 3),
    Color color = const Color(0x59000000)}) {
  c.drawPath(
    p.shift(offset),
    Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
  );
}

/// Üst-sol beyaz parlaklık şeridi — plastik/ışıltı hissi.
void gloss(Canvas c, Offset center, double rx, double ry, {double alpha = .5}) {
  c.drawOval(
    Rect.fromCenter(
        center: Offset(center.dx - rx * 0.25, center.dy - ry * 0.35),
        width: rx * 0.9,
        height: ry * 0.55),
    Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, rx * 0.18),
  );
}

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

/// 5 yapraklı çiçek — yapraklarda hafif degrade.
void drawFlower(Canvas c, Offset center, double r, Color petal, Color mid) {
  for (var i = 0; i < 5; i++) {
    final a = i * 2 * math.pi / 5 - math.pi / 2;
    final pc = Offset(center.dx + r * 0.62 * math.cos(a),
        center.dy + r * 0.62 * math.sin(a));
    c.drawCircle(
        pc,
        r * 0.42,
        prad(pc.translate(-r * 0.1, -r * 0.1), r * 0.5,
            [Color.lerp(petal, Colors.white, 0.35)!, petal]));
  }
  c.drawCircle(center, r * 0.30, pf(mid));
  c.drawCircle(center.translate(-r * 0.07, -r * 0.07), r * 0.10,
      pf(Colors.white.withValues(alpha: 0.7)));
}

/// Noktalardan geçen pürüzsüz kapalı eğri (Catmull-Rom → Bezier).
/// Dudak dolgusu, yüz maskesi gibi kontur izleyen şekiller için.
Path smoothClosed(List<Offset> pts, {double tension = 0.8}) {
  final n = pts.length;
  if (n < 3) return Path();
  final p = Path()..moveTo(pts[0].dx, pts[0].dy);
  for (var i = 0; i < n; i++) {
    final p0 = pts[(i - 1 + n) % n];
    final p1 = pts[i];
    final p2 = pts[(i + 1) % n];
    final p3 = pts[(i + 2) % n];
    final c1 = p1 + (p2 - p0) * (tension / 6);
    final c2 = p2 - (p3 - p1) * (tension / 6);
    p.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  return p..close();
}

/// FxFrame + tuval boyutundan türetilmiş piksel-uzayı yüz geometrisi.
class FaceGeom {
  final FxFrame f;
  final Size s;
  late final Offset center = Offset(f.cx * s.width, f.cy * s.height);
  late final double fw = f.w * s.width;
  late final double fh = f.h * s.height;

  FaceGeom(this.f, this.s);

  /// Kontur noktası, görüntü uzayında (duruş dahil).
  Offset pt(int i) => Offset(f.pts[i * 2] * s.width, f.pts[i * 2 + 1] * s.height);

  /// Kontur noktası, kafa uzayında (roll geri alınmış) — [withHead] içinde
  /// çapa olarak kullanılır.
  Offset derolled(int i) {
    final p = pt(i) - center;
    final cs = math.cos(-f.roll), sn = math.sin(-f.roll);
    return center + Offset(p.dx * cs - p.dy * sn, p.dx * sn + p.dy * cs);
  }

  Offset _avg(int base, int n) {
    var x = 0.0, y = 0.0;
    for (var i = 0; i < n; i++) {
      x += f.pts[(base + i) * 2];
      y += f.pts[(base + i) * 2 + 1];
    }
    return Offset(x / n * s.width, y / n * s.height);
  }

  Offset get eyeLc => _avg(P.eyeL, 4);
  Offset get eyeRc => _avg(P.eyeR, 4);
  Offset get noseTip => pt(P.noseTip);
  Offset get noseC => pt(P.noseBotC);
  Offset get chin => pt(P.chin);
  Offset get mouthC =>
      Offset.lerp(pt(P.lipInT), pt(P.lipInB), 0.5) ?? pt(P.lipInT);
  double get eyeSpan => (eyeRc - eyeLc).distance;

  double get mouth => f.mouth;
  double get smile => f.smile;
  double get blink => 1 - math.min(f.eyeOpenL, f.eyeOpenR); // 0 açık, 1 kapalı
}

/// Kafa uzayı: yüz merkezi etrafında roll + yaw/pitch perspektifi.
///
/// İçeride dik kutu koordinatlarıyla çizilir; kafa dönünce çizim üç
/// boyutluymuş gibi eğilir. [amount] eğilme şiddetini kısar (1 = tam).
void withHead(Canvas c, FaceGeom g, void Function() draw,
    {double amount = 1.0}) {
  final yaw = (g.f.yaw * amount).clamp(-0.6, 0.6);
  final pitch = (g.f.pitch * amount).clamp(-0.5, 0.5);
  final m = Matrix4.identity()
    ..setEntry(3, 2, g.fw > 1 ? -1 / (g.fw * 5) : 0) // perspektif derinliği
    ..rotateY(yaw)
    ..rotateX(-pitch);
  c.save();
  c.translate(g.center.dx, g.center.dy);
  c.transform(m.storage);
  c.rotate(g.f.roll);
  c.translate(-g.center.dx, -g.center.dy);
  draw();
  c.restore();
}
