// Geçici görsel doğrulama aracı: her efekti örnek yüz üzerinde PNG'ye çizer.
// `flutter test test/render_preview_test.dart` sonrası çıktı FX_OUT dizinine
// düşer. Kalıcı test değildir; incelemeden sonra silinebilir.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hophop/effects/effect_painter.dart';
import 'package:hophop/effects/fx_frame.dart';

void main() {
  final out = Platform.environment['FX_OUT'];

  test('efekt önizlemeleri PNG olarak yazılır', () async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    const size = Size(300, 400);
    for (final cat in fxCategories) {
      for (final e in cat.effects) {
        for (final (suffix, pitch, yaw, roll) in [
          ('front', 0.0, 0.0, 0.0),
          ('posed', 0.15, -0.35, 0.12),
        ]) {
          final base = FxFrame.fromBox(
              effect: e.id, cx: 0.5, cy: 0.55, w: 0.5, h: 0.44,
              roll: roll, mouth: 0.8, smile: 0.8);
          final f = FxFrame(
            effect: e.id, hasFace: true,
            cx: base.cx, cy: base.cy, w: base.w, h: base.h,
            pitch: pitch, yaw: yaw, roll: roll,
            mouth: 0.8, smile: 0.8, eyeOpenL: 1, eyeOpenR: 1,
            pts: base.pts,
          );
          final rec = ui.PictureRecorder();
          final canvas = Canvas(rec);
          _drawSampleFace(canvas, size, f);
          EffectPainter(f).paint(canvas, size);
          final img = await rec
              .endRecording()
              .toImage(size.width.toInt(), size.height.toInt());
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/${cat.id}_${e.id}_$suffix.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
        }
      }
    }
  });
}

void _drawSampleFace(Canvas c, Size s, FxFrame f) {
  c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF2E3B4E));
  final face = Offset(f.cx * s.width, f.cy * s.height);
  c.drawOval(
      Rect.fromCenter(
          center: face, width: f.w * s.width, height: f.h * s.height * 1.15),
      Paint()..color = const Color(0xFFF0C8A0));
  for (final i in [P.eyeL, P.eyeR]) {
    final e = Offset((f.pts[i * 2] + f.pts[(i + 2) * 2]) / 2 * s.width,
        (f.pts[i * 2 + 1] + f.pts[(i + 2) * 2 + 1]) / 2 * s.height);
    c.drawCircle(e, s.width * 0.02, Paint()..color = Colors.black87);
  }
  final m = Offset(f.pt(P.lipInT).dx * s.width, f.pt(P.lipInT).dy * s.height);
  c.drawOval(Rect.fromCenter(center: m, width: s.width * 0.09, height: s.width * 0.05),
      Paint()..color = const Color(0xFF9C5B4B));
}
