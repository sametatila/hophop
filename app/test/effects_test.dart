import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hophop/effects/effect_painter.dart';
import 'package:hophop/effects/fx_frame.dart';

void main() {
  test('katalog: 4 kategori, 45 efekt, kimlikler benzersiz', () {
    final ids = [
      for (final cat in fxCategories) ...[for (final e in cat.effects) e.id]
    ];
    expect(fxCategories.length, 4);
    expect(ids.length, 45);
    expect(ids.toSet().length, ids.length, reason: 'çift efekt kimliği var');
    expect(ids.contains('none'), isFalse);
  });

  test('her efekt örnek yüzle hatasız çizilir', () {
    final f = EffectThumb.sampleFace;
    for (final cat in fxCategories) {
      for (final e in cat.effects) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        EffectPainter(FxFrame(
          effect: e.id,
          cx: f.cx, cy: f.cy, w: f.w, h: f.h, rz: 0.1, mouth: 1,
          lx: f.lx, ly: f.ly, rx: f.rx, ry: f.ry, nx: f.nx, ny: f.ny,
        )).paint(canvas, const Size(300, 400));
        recorder.endRecording();
      }
    }
  });

  test('sihir efektleri yüz algılanmadan da çizilir', () {
    for (final e in fxCategories.last.effects) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      EffectPainter(FxFrame(
        effect: e.id,
        cx: 0.5, cy: 0.45, w: 0, h: 0, rz: 0, mouth: 0,
        lx: 0, ly: 0, rx: 0, ry: 0, nx: 0, ny: 0,
      )).paint(canvas, const Size(300, 400));
      recorder.endRecording();
    }
  });
}
