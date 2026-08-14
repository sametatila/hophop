import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hophop/effects/effect_painter.dart';
import 'package:hophop/effects/fx_frame.dart';
import 'package:hophop/effects/fx_smoother.dart';

void main() {
  test('katalog: 4 kategori, 47 efekt, kimlikler benzersiz', () {
    final ids = [
      for (final cat in fxCategories) ...[for (final e in cat.effects) e.id]
    ];
    expect(fxCategories.length, 4);
    expect(ids.length, 47);
    expect(ids.toSet().length, ids.length, reason: 'çift efekt kimliği var');
    expect(ids.contains('none'), isFalse);
  });

  test('her efekt örnek yüzle hatasız çizilir (duruşlu, animasyon anlı)', () {
    for (final cat in fxCategories) {
      for (final e in cat.effects) {
        final frame = FxFrame.fromBox(
            effect: e.id, cx: 0.5, cy: 0.55, w: 0.5, h: 0.44,
            roll: 0.1, mouth: 1, smile: 1);
        // Duruş açılarıyla da çizilebilmeli (perspektif dönüşümü).
        final posed = FxFrame(
          effect: e.id, hasFace: true,
          cx: frame.cx, cy: frame.cy, w: frame.w, h: frame.h,
          pitch: 0.2, yaw: -0.3, roll: 0.1,
          mouth: 1, smile: 1, eyeOpenL: 0.2, eyeOpenR: 1,
          pts: frame.pts,
        );
        for (final f in [frame, posed]) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          EffectPainter(f).paint(canvas, const Size(300, 400));
          recorder.endRecording();
        }
      }
    }
  });

  test('sihir efektleri yüz algılanmadan da çizilir', () {
    for (final e in fxCategories.last.effects) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      EffectPainter(FxFrame.faceless(e.id)).paint(canvas, const Size(300, 400));
      recorder.endRecording();
    }
  });

  test('binary tel formatı: encode/decode kayıpsıza yakın döner', () {
    final f = FxFrame.fromBox(
        effect: 'bunny', cx: 0.43, cy: 0.51, w: 0.38, h: 0.42,
        roll: -0.21, mouth: 0.7, smile: 0.9);
    final decoded = FxFrame.decode(f.encode());
    expect(decoded, isNotNull);
    expect(decoded!.effect, 'bunny');
    expect(decoded.hasFace, isTrue);
    expect(decoded.cx, closeTo(f.cx, 1e-3));
    expect(decoded.cy, closeTo(f.cy, 1e-3));
    expect(decoded.w, closeTo(f.w, 1e-3));
    expect(decoded.roll, closeTo(f.roll, 1e-3));
    expect(decoded.mouth, closeTo(f.mouth, 5e-3));
    expect(decoded.smile, closeTo(f.smile, 5e-3));
    for (var i = 0; i < P.count * 2; i++) {
      expect(decoded.pts[i], closeTo(f.pts[i], 1e-3));
    }
    // Kompakt kalmalı: lossy data channel için ~kB altı şart.
    expect(f.encode().length, lessThan(260));
  });

  test('yüzsüz kare ve kapalı efekt telde doğru taşınır', () {
    final off = FxFrame.decode(FxFrame.off.encode());
    expect(off, isNotNull);
    expect(off!.isOff, isTrue);
    final faceless = FxFrame.decode(FxFrame.faceless('snow').encode());
    expect(faceless, isNotNull);
    expect(faceless!.effect, 'snow');
    expect(faceless.hasFace, isFalse);
  });

  test('v1 (JSON) kareler geriye dönük çözülür', () {
    const legacy =
        '{"e":"dog","f":[0.5,0.4,0.3,0.35,0.1,0.8,0.44,0.35,0.56,0.35,0.5,0.45]}';
    final decoded = FxFrame.decode(legacy.codeUnits);
    expect(decoded, isNotNull);
    expect(decoded!.effect, 'dog');
    expect(decoded.hasFace, isTrue);
    expect(decoded.cx, closeTo(0.5, 1e-6));
    expect(decoded.mouth, closeTo(0.8, 1e-6));
    // Sentezlenen nokta takımı tam olmalı — ressamlar noktasız çalışmaz.
    expect(decoded.pt(P.chin).dy, greaterThan(decoded.cy));
  });

  test('aynalama: sol/sağ gruplar anlamlarıyla takas olur, iki kez = özdeş', () {
    final f = FxFrame.fromBox(
        effect: 'glasses', cx: 0.42, cy: 0.5, w: 0.4, h: 0.44,
        roll: 0.2, mouth: 0.3);
    final m = f.mirrored();
    expect(m.cx, closeTo(1 - f.cx, 1e-6));
    expect(m.roll, closeTo(-f.roll, 1e-6));
    // Sol göz aynada da izleyenin solunda kalmalı.
    expect(m.pt(P.eyeL).dx, lessThan(m.pt(P.eyeR).dx));
    final mm = m.mirrored();
    for (var i = 0; i < P.count * 2; i++) {
      expect(mm.pts[i], closeTo(f.pts[i], 1e-5));
    }
  });

  test('yumuşatıcı: hedefe yakınsar, efekt değişince sıçrar', () async {
    final s = FxSmoother();
    final a = FxFrame.fromBox(
        effect: 'bunny', cx: 0.3, cy: 0.5, w: 0.4, h: 0.44);
    s.feed(a);
    expect(s.sample()!.cx, closeTo(0.3, 1e-6), reason: 'ilk kare sıçramalı');
    // Yeni hedef: örnekler hedefe tekdüze yaklaşmalı.
    final b = FxFrame.fromBox(
        effect: 'bunny', cx: 0.7, cy: 0.5, w: 0.4, h: 0.44);
    s.feed(b);
    var last = 0.3;
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      final v = s.sample()!.cx;
      expect(v, greaterThanOrEqualTo(last - 1e-6));
      expect(v, lessThanOrEqualTo(0.7 + 1e-6));
      last = v;
    }
    expect(last, greaterThan(0.5), reason: 'yarım saniyede hedefe yaklaşmalı');
    // Efekt değişimi: yumuşatma sıfırlanır, yeni konuma anında oturur.
    final c = FxFrame.fromBox(
        effect: 'dog', cx: 0.2, cy: 0.5, w: 0.4, h: 0.44);
    s.feed(c);
    expect(s.sample()!.cx, closeTo(0.2, 1e-6));
    // Kapatınca örnek null döner.
    s.feed(null);
    expect(s.sample(), isNull);
  });

  test('küçük resim örnek yüzü tüm nokta takımını taşır', () {
    final f = EffectThumb.sampleFace;
    expect(f.pts.length, P.count * 2);
    expect(f.pt(P.eyeL).dx, lessThan(f.pt(P.eyeR).dx));
    expect(f.pt(P.oval).dy, lessThan(f.pt(P.chin).dy));
  });
}
