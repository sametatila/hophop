import 'package:flutter/material.dart';
import 'fx_frame.dart';
import 'painter_util.dart';

/// Yüz aksesuarları: gözlükler, maskeler, burunlar.
void paintFaceFx(String id, Canvas c, Size s, FxFrame f, double cx, double cy,
    double fw, double fh, double t) {
  final lm = landmarks(f, s);
  switch (id) {
    case 'glasses':
      _glasses(c, lm, fw);
    case 'sun':
      _sunglasses(c, lm, fw);
    case 'heartgl':
      _heartGlasses(c, lm, fw);
    case 'stargl':
      _starGlasses(c, lm, fw);
    case 'mustache':
      _mustache(c, lm.n, fw);
    case 'clown':
      _clown(c, lm.n, cx, cy, fw, fh);
    case 'blush':
      _blush(c, lm.n, cx, cy, fw, fh);
    case 'hero':
      _heroMask(c, lm, fw, fh);
    case 'robot':
      _robot(c, lm, cx, cy, fw, fh);
    case 'patch':
      _piratePatch(c, lm, cx, fw, fh);
  }
}

// ---- Kocaman komik gözlük ----
void _glasses(Canvas c, ({Offset l, Offset r, Offset n}) lm, double fw) {
  final radius = fw * 0.22;
  final stroke = ps(Colors.black, fw * 0.05);
  final lens = pf(Colors.white.withValues(alpha: 0.25));
  for (final e in [lm.l, lm.r]) {
    c.drawCircle(e, radius, lens);
    c.drawCircle(e, radius, stroke);
  }
  c.drawLine(lm.l.translate(radius, 0), lm.r.translate(-radius, 0), stroke);
}

// ---- Güneş gözlüğü ----
void _sunglasses(Canvas c, ({Offset l, Offset r, Offset n}) lm, double fw) {
  final dark = pf(Colors.black.withValues(alpha: 0.88));
  for (final e in [lm.l, lm.r]) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: e, width: fw * 0.36, height: fw * 0.26),
      Radius.circular(fw * 0.08),
    );
    c.drawRRect(rect, dark);
    // Parlama
    c.drawLine(
      Offset(e.dx - fw * 0.10, e.dy - fw * 0.06),
      Offset(e.dx - fw * 0.02, e.dy + fw * 0.06),
      ps(Colors.white.withValues(alpha: 0.45), fw * 0.03),
    );
  }
  final bridge = ps(Colors.black.withValues(alpha: 0.88), fw * 0.04);
  c.drawLine(lm.l.translate(fw * 0.18, -fw * 0.04),
      lm.r.translate(-fw * 0.18, -fw * 0.04), bridge);
  // Saplar
  c.drawLine(lm.l.translate(-fw * 0.18, -fw * 0.04),
      lm.l.translate(-fw * 0.34, -fw * 0.08), bridge);
  c.drawLine(lm.r.translate(fw * 0.18, -fw * 0.04),
      lm.r.translate(fw * 0.34, -fw * 0.08), bridge);
}

// ---- Kalp gözlük ----
void _heartGlasses(Canvas c, ({Offset l, Offset r, Offset n}) lm, double fw) {
  for (final e in [lm.l, lm.r]) {
    c.drawPath(heartPath(e, fw * 0.20),
        pf(const Color(0xFFFF4081).withValues(alpha: 0.85)));
    c.drawCircle(Offset(e.dx - fw * 0.06, e.dy - fw * 0.06), fw * 0.03,
        pf(Colors.white.withValues(alpha: 0.7)));
  }
  c.drawLine(lm.l.translate(fw * 0.14, 0), lm.r.translate(-fw * 0.14, 0),
      ps(const Color(0xFFFF4081), fw * 0.035));
}

// ---- Yıldız gözlük ----
void _starGlasses(Canvas c, ({Offset l, Offset r, Offset n}) lm, double fw) {
  for (final e in [lm.l, lm.r]) {
    final star = starPath(e, fw * 0.24);
    c.drawPath(star, pf(const Color(0xFFFFD54F).withValues(alpha: 0.9)));
    c.drawPath(star, ps(const Color(0xFFF9A825), fw * 0.02));
  }
  c.drawLine(lm.l.translate(fw * 0.16, 0), lm.r.translate(-fw * 0.16, 0),
      ps(const Color(0xFFF9A825), fw * 0.035));
}

// ---- Pos bıyık ----
void _mustache(Canvas c, Offset n, double fw) {
  final paint = pf(const Color(0xFF3E2723));
  for (final side in [-1, 1]) {
    final path = Path()
      ..moveTo(n.dx, n.dy + fw * 0.10)
      ..quadraticBezierTo(
        n.dx + side * fw * 0.25, n.dy + fw * 0.02,
        n.dx + side * fw * 0.42, n.dy + fw * 0.14,
      )
      ..quadraticBezierTo(
        n.dx + side * fw * 0.28, n.dy + fw * 0.26,
        n.dx, n.dy + fw * 0.18,
      )
      ..close();
    c.drawPath(path, paint);
  }
}

// ---- Palyaço: kırmızı burun + pembe yanaklar ----
void _clown(Canvas c, Offset n, double cx, double cy, double fw, double fh) {
  for (final side in [-1, 1]) {
    c.drawCircle(Offset(cx + side * fw * 0.30, cy + fh * 0.06), fw * 0.09,
        pf(const Color(0xFFF48FB1).withValues(alpha: 0.6)));
  }
  c.drawCircle(n, fw * 0.13, pf(const Color(0xFFE53935)));
  c.drawCircle(Offset(n.dx - fw * 0.04, n.dy - fw * 0.04), fw * 0.035,
      pf(Colors.white.withValues(alpha: 0.7)));
}

// ---- Çiller + pembe yanaklar ----
void _blush(Canvas c, Offset n, double cx, double cy, double fw, double fh) {
  final freckle = pf(const Color(0xFF8D6E63).withValues(alpha: 0.75));
  for (final side in [-1, 1]) {
    final cheek = Offset(cx + side * fw * 0.28, cy + fh * 0.05);
    c.drawCircle(cheek, fw * 0.10,
        pf(const Color(0xFFF8BBD0).withValues(alpha: 0.5)));
    for (final (dx, dy) in [(-0.03, -0.02), (0.03, -0.03), (0.0, 0.03)]) {
      c.drawCircle(Offset(cheek.dx + fw * dx, cheek.dy + fw * dy), fw * 0.013,
          freckle);
    }
  }
  // Burun köprüsünde iki çil
  c.drawCircle(Offset(n.dx - fw * 0.05, n.dy - fh * 0.06), fw * 0.012, freckle);
  c.drawCircle(Offset(n.dx + fw * 0.05, n.dy - fh * 0.065), fw * 0.012, freckle);
}

// ---- Kahraman maskesi ----
void _heroMask(Canvas c, ({Offset l, Offset r, Offset n}) lm, double fw,
    double fh) {
  final midY = (lm.l.dy + lm.r.dy) / 2;
  final midX = (lm.l.dx + lm.r.dx) / 2;
  final mask = Path()
    ..moveTo(midX - fw * 0.52, midY - fw * 0.02)
    ..quadraticBezierTo(midX - fw * 0.30, midY - fw * 0.20, midX, midY - fw * 0.14)
    ..quadraticBezierTo(midX + fw * 0.30, midY - fw * 0.20, midX + fw * 0.52, midY - fw * 0.02)
    ..quadraticBezierTo(midX + fw * 0.34, midY + fw * 0.16, midX, midY + fw * 0.12)
    ..quadraticBezierTo(midX - fw * 0.34, midY + fw * 0.16, midX - fw * 0.52, midY - fw * 0.02)
    ..close()
    // Göz delikleri (evenOdd: içinden video görünür)
    ..addOval(Rect.fromCenter(center: lm.l, width: fw * 0.17, height: fw * 0.11))
    ..addOval(Rect.fromCenter(center: lm.r, width: fw * 0.17, height: fw * 0.11));
  mask.fillType = PathFillType.evenOdd;
  c.drawPath(mask, pf(const Color(0xFFE53935).withValues(alpha: 0.92)));
  c.drawPath(mask, ps(const Color(0xFFB71C1C), fw * 0.02));
}

// ---- Robot: vizör + anten ----
void _robot(Canvas c, ({Offset l, Offset r, Offset n}) lm, double cx,
    double cy, double fw, double fh) {
  final midY = (lm.l.dy + lm.r.dy) / 2;
  final visor = RRect.fromRectAndRadius(
    Rect.fromCenter(
        center: Offset(cx, midY), width: fw * 1.02, height: fw * 0.30),
    Radius.circular(fw * 0.10),
  );
  c.drawRRect(visor, pf(const Color(0xFF90A4AE).withValues(alpha: 0.92)));
  // Işıklı yarık
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(cx, midY), width: fw * 0.88, height: fw * 0.10),
      Radius.circular(fw * 0.05),
    ),
    pf(const Color(0xFF00E5FF)),
  );
  // Yan cıvatalar
  for (final side in [-1, 1]) {
    c.drawCircle(Offset(cx + side * fw * 0.51, midY), fw * 0.05,
        pf(const Color(0xFF546E7A)));
  }
  // Anten
  final top = cy - fh * 0.50;
  c.drawLine(Offset(cx, top), Offset(cx, top - fh * 0.20),
      ps(const Color(0xFF78909C), fw * 0.03));
  c.drawCircle(Offset(cx, top - fh * 0.23), fw * 0.05,
      pf(const Color(0xFFE53935)));
}

// ---- Korsan göz bandı ----
void _piratePatch(Canvas c, ({Offset l, Offset r, Offset n}) lm, double cx,
    double fw, double fh) {
  final black = pf(const Color(0xFF212121));
  final strap = ps(const Color(0xFF212121), fw * 0.045);
  final eye = lm.r; // sağ göz (aynalamada otomatik değişir)
  // Bant: gözden yüz kenarlarına
  c.drawLine(Offset(eye.dx - fw * 0.14, eye.dy - fw * 0.05),
      Offset(cx - fw * 0.52, eye.dy - fw * 0.14), strap);
  c.drawLine(Offset(eye.dx + fw * 0.13, eye.dy - fw * 0.06),
      Offset(cx + fw * 0.52, eye.dy - fw * 0.18), strap);
  c.drawOval(
    Rect.fromCenter(
        center: Offset(eye.dx, eye.dy + fw * 0.01),
        width: fw * 0.30,
        height: fw * 0.26),
    black,
  );
}
