import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'fx_frame.dart';
import 'painters_animals.dart';
import 'painters_face.dart';
import 'painters_hats.dart';
import 'painters_magic.dart';

/// Efekt kataloğu — 4 kategori, 45 efekt. Tümü vektörel çizim:
/// paket yok, asset yok, her çözünürlükte keskin, E2EE bozulmaz.
class FxCategory {
  final String id;
  final String label;
  final IconData icon;
  final List<({String id, String label})> effects;
  const FxCategory(this.id, this.label, this.icon, this.effects);
}

const fxCategories = [
  FxCategory('animal', 'Hayvanlar', Icons.pets, [
    (id: 'bunny', label: 'Tavşan'),
    (id: 'dog', label: 'Köpek'),
    (id: 'cat', label: 'Kedi'),
    (id: 'bear', label: 'Ayı'),
    (id: 'fox', label: 'Tilki'),
    (id: 'panda', label: 'Panda'),
    (id: 'koala', label: 'Koala'),
    (id: 'mouse', label: 'Fare'),
    (id: 'tiger', label: 'Kaplan'),
    (id: 'monkey', label: 'Maymun'),
    (id: 'lion', label: 'Aslan'),
    (id: 'frog', label: 'Kurbağa'),
    (id: 'deer', label: 'Geyik'),
    (id: 'chick', label: 'Civciv'),
  ]),
  FxCategory('hat', 'Şapkalar', Icons.celebration, [
    (id: 'crown', label: 'Taç'),
    (id: 'fcrown', label: 'Çiçek taç'),
    (id: 'unicorn', label: 'Tekboynuz'),
    (id: 'party', label: 'Parti'),
    (id: 'wizard', label: 'Büyücü'),
    (id: 'chef', label: 'Aşçı'),
    (id: 'pirate', label: 'Korsan'),
    (id: 'halo', label: 'Melek'),
    (id: 'prop', label: 'Pervane'),
    (id: 'beanie', label: 'Bere'),
    (id: 'cowboy', label: 'Kovboy'),
    (id: 'grad', label: 'Mezun'),
  ]),
  FxCategory('face', 'Yüz', Icons.face_retouching_natural, [
    (id: 'glasses', label: 'Gözlük'),
    (id: 'sun', label: 'Güneş'),
    (id: 'heartgl', label: 'Kalp göz'),
    (id: 'stargl', label: 'Yıldız göz'),
    (id: 'mustache', label: 'Bıyık'),
    (id: 'clown', label: 'Palyaço'),
    (id: 'blush', label: 'Çiller'),
    (id: 'hero', label: 'Kahraman'),
    (id: 'robot', label: 'Robot'),
    (id: 'patch', label: 'Korsan göz'),
  ]),
  FxCategory('magic', 'Sihir', Icons.auto_awesome, [
    (id: 'hearts', label: 'Kalpler'),
    (id: 'stars', label: 'Yıldızlar'),
    (id: 'sparkle', label: 'Pırıltı'),
    (id: 'rainbow', label: 'Gökkuşağı'),
    (id: 'rmouth', label: 'Renkli ağız'),
    (id: 'snow', label: 'Kar'),
    (id: 'bubbles', label: 'Baloncuk'),
    (id: 'confetti', label: 'Konfeti'),
    (id: 'notes', label: 'Notalar'),
  ]),
];

final kAnimalFx = {for (final e in fxCategories[0].effects) e.id};
final kHatFx = {for (final e in fxCategories[1].effects) e.id};
final kFaceFx = {for (final e in fxCategories[2].effects) e.id};

/// Yüz olmasa da çizilen, kafa eğimiyle dönmeyen efektler.
final kMagicFx = {for (final e in fxCategories[3].effects) e.id};

/// Sürekli yeniden çizim (animasyon saati) gerektiren efektler.
final kAnimatedFx = {...kMagicFx, 'prop', 'halo', 'grad'};

/// FxFrame'i video görüntüsünün üstüne çizer (hem yerel hem uzak taraf).
/// [clock] saniye sayacı: animasyonlu efektlerde repaint kaynağı olarak
/// verilir; statik efektlerde null bırakılır (gereksiz 60fps çizim olmaz).
class EffectPainter extends CustomPainter {
  final FxFrame? frame;
  final ValueListenable<double>? clock;
  EffectPainter(this.frame, {this.clock}) : super(repaint: clock);

  @override
  void paint(Canvas canvas, Size size) {
    final f = frame;
    if (f == null || f.effect == 'none') return;
    final t = clock?.value ?? 0.6; // saat yoksa (önizleme) sabit an

    // Sihir: ekran/yüz-çevresi parçacıkları — kafa eğimi uygulanmaz.
    if (kMagicFx.contains(f.effect)) {
      paintMagicFx(f.effect, canvas, size, f, t);
      return;
    }

    final cx = f.cx * size.width;
    final cy = f.cy * size.height;
    final fw = f.w * size.width;
    final fh = f.h * size.height;
    if (fw < 8) return;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(f.rz);
    canvas.translate(-cx, -cy);
    if (kAnimalFx.contains(f.effect)) {
      paintAnimalFx(f.effect, canvas, size, f, cx, cy, fw, fh, t);
    } else if (kHatFx.contains(f.effect)) {
      paintHatFx(f.effect, canvas, size, f, cx, cy, fw, fh, t);
    } else if (kFaceFx.contains(f.effect)) {
      paintFaceFx(f.effect, canvas, size, f, cx, cy, fw, fh, t);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(EffectPainter old) =>
      old.frame != frame || old.clock != clock;
}

/// Efektin kendisini örnek bir yüz üzerinde çizen mini önizleme
/// (emoji yerine — efekt neyse onu gösterir).
class EffectThumb extends StatelessWidget {
  final String effectId;
  final double size;
  const EffectThumb({super.key, required this.effectId, this.size = 36});

  /// Örnek yüz: şapkalar sığsın diye alçak ve küçük tutulur.
  static const sampleFace = FxFrame(
    effect: '',
    cx: 0.5, cy: 0.66, w: 0.5, h: 0.44, rz: 0, mouth: 1,
    lx: 0.40, ly: 0.60, rx: 0.60, ry: 0.60, nx: 0.5, ny: 0.70,
  );

  @override
  Widget build(BuildContext context) {
    if (effectId == 'none') {
      return SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.block, color: Colors.white70, size: size * 0.7),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CustomPaint(painter: _ThumbPainter(effectId)),
      ),
    );
  }
}

class _ThumbPainter extends CustomPainter {
  final String effectId;
  const _ThumbPainter(this.effectId);

  @override
  void paint(Canvas canvas, Size size) {
    // Örnek yüz: ten rengi daire + gözler
    final f = EffectThumb.sampleFace;
    final face = Offset(f.cx * size.width, f.cy * size.height);
    canvas.drawCircle(face, f.w * size.width * 0.5,
        Paint()..color = const Color(0xFFF0C8A0));
    for (final e in [(f.lx, f.ly), (f.rx, f.ry)]) {
      canvas.drawCircle(Offset(e.$1 * size.width, e.$2 * size.height),
          size.width * 0.035, Paint()..color = Colors.black87);
    }
    EffectPainter(FxFrame(
      effect: effectId,
      cx: f.cx, cy: f.cy, w: f.w, h: f.h, rz: 0, mouth: 1,
      lx: f.lx, ly: f.ly, rx: f.rx, ry: f.ry, nx: f.nx, ny: f.ny,
    )).paint(canvas, size);
  }

  @override
  bool shouldRepaint(_ThumbPainter old) => old.effectId != effectId;
}
