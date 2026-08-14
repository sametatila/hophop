import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'fx_frame.dart';
import 'fx_smoother.dart';
import 'painter_util.dart';
import 'painters_animals.dart';
import 'painters_face.dart';
import 'painters_hats.dart';
import 'painters_magic.dart';

/// Efekt kataloğu — 4 kategori, 47 efekt. Tümü vektörel çizim:
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
    (id: 'lipstick', label: 'Ruj'),
    (id: 'butterfly', label: 'Kelebek'),
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

/// Yüz olmasa da çizilen, kafa duruşuyla dönmeyen efektler.
final kMagicFx = {for (final e in fxCategories[3].effects) e.id};

/// FxFrame'i video görüntüsünün üstüne çizer (hem yerel hem uzak taraf).
///
/// Canlı kullanım: [smoother] + [clock] verilir — her tikte yumuşatıcıdan
/// ara kare örneklenir; algılama 2-8 fps olsa da overlay 60 fps kayar ve
/// tüm efektler animasyon saatine erişir. Statik kullanım (küçük resimler):
/// yalnız [frame] verilir.
class EffectPainter extends CustomPainter {
  final FxFrame? frame;
  final FxSmoother? smoother;
  final ValueListenable<double>? clock;
  EffectPainter(this.frame, {this.smoother, this.clock})
      : super(repaint: clock);

  @override
  void paint(Canvas canvas, Size size) {
    // Yumuşatıcı verildiyse tek gerçek kaynak odur: ham kareye düşmek
    // yumuşatmanın amacını bozar (titrek kare araya sızardı).
    final f = smoother != null ? smoother!.sample() : frame;
    if (f == null || f.effect == 'none') return;
    final t = clock?.value ?? 0.6; // saat yoksa (önizleme) sabit an

    // Sihir: ekran/yüz-çevresi parçacıkları — kafa duruşu uygulanmaz.
    if (kMagicFx.contains(f.effect)) {
      paintMagicFx(f.effect, canvas, size, f, t);
      return;
    }

    if (!f.hasFace) return;
    final g = FaceGeom(f, size);
    if (g.fw < 8) return;

    if (kAnimalFx.contains(f.effect)) {
      paintAnimalFx(f.effect, canvas, size, g, t);
    } else if (kHatFx.contains(f.effect)) {
      paintHatFx(f.effect, canvas, size, g, t);
    } else if (kFaceFx.contains(f.effect)) {
      paintFaceFx(f.effect, canvas, size, g, t);
    }
  }

  @override
  bool shouldRepaint(EffectPainter old) =>
      old.frame != frame || old.smoother != smoother || old.clock != clock;
}

/// Efektin kendisini örnek bir yüz üzerinde çizen mini önizleme
/// (emoji yerine — efekt neyse onu gösterir).
class EffectThumb extends StatelessWidget {
  final String effectId;
  final double size;
  const EffectThumb({super.key, required this.effectId, this.size = 36});

  /// Örnek yüz: şapkalar sığsın diye alçak ve küçük tutulur.
  static final FxFrame sampleFace = FxFrame.fromBox(
      effect: '', cx: 0.5, cy: 0.66, w: 0.5, h: 0.44, mouth: 1, smile: 1);

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
    for (final i in [P.eyeL, P.eyeR]) {
      final e = Offset(
          (f.pts[i * 2] + f.pts[(i + 2) * 2]) / 2 * size.width,
          (f.pts[i * 2 + 1] + f.pts[(i + 2) * 2 + 1]) / 2 * size.height);
      canvas.drawCircle(e, size.width * 0.035, Paint()..color = Colors.black87);
    }
    EffectPainter(FxFrame.fromBox(
      effect: effectId,
      cx: f.cx, cy: f.cy, w: f.w, h: f.h, mouth: 1, smile: 1,
    )).paint(canvas, size);
  }

  @override
  bool shouldRepaint(_ThumbPainter old) => old.effectId != effectId;
}
