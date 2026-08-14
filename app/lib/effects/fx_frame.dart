import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Bir karedeki yüz durumu + seçili efekt (v2).
///
/// v1 yalnızca 4 işaret noktası taşıyordu; v2 ML Kit yüz konturlarından
/// seçilmiş 47 noktayı, üç eksenli kafa duruşunu (pitch/yaw/roll) ve
/// sınıflandırma olasılıklarını (ağız, gülümseme, göz açıklığı) taşır.
/// Koordinatlar 0..1 aralığında, YAYINLANAN (aynalanmamış) kareye göre
/// normalize edilir; yerel önizleme aynalı olduğundan çizimde [mirrored]
/// kullanılır.
///
/// Tel formatı JSON değil kompakt binary'dir (~210 bayt): sürüm baytı ile
/// başlar; eski (v1 JSON) kareler de çözülür ve nokta takımı kutudan
/// sentezlenir — karışık sürümlü aramalar efektsiz kalmaz.

/// Nokta dizilimi — sabit sıra, [FxFrame.pts] içinde (x,y) çiftleri.
/// Sol/sağ HER ZAMAN görüntüdeki konuma göredir (izleyenin solu).
abstract final class P {
  /// Yüz ovali: 18 nokta, tepe ortasından başlar, saat yönünde döner
  /// (tepe → izleyenin sağı → çene [9] → izleyenin solu → tepe).
  static const oval = 0;
  static const ovalN = 18;
  static const chin = oval + 9; // ovalin tepe karşıtı

  /// Kaşlar: (dış uç, orta, iç uç) — dış = yüz kenarına yakın.
  static const browL = 18;
  static const browR = 21;

  /// Gözler: (dış köşe, üst, iç köşe, alt).
  static const eyeL = 24;
  static const eyeR = 28;

  /// Dudak dışı: üst (sol köşe, kupidon, sağ köşe), alt (sol, orta, sağ).
  static const lipT = 32;
  static const lipB = 35;

  /// Dudak içi orta noktalar (ağız boşluğu üstü/altı).
  static const lipInT = 38;
  static const lipInB = 39;

  /// Burun: köprü üstü, köprü altı (uç), taban (sol, orta, sağ).
  static const noseTop = 40;
  static const noseTip = 41;
  static const noseBotL = 42;
  static const noseBotC = 43;
  static const noseBotR = 44;

  /// Yanak merkezleri.
  static const cheekL = 45;
  static const cheekR = 46;

  static const count = 47;
}

class FxFrame {
  final String effect;
  final bool hasFace;
  final double cx, cy; // yüz merkezi
  final double w, h; // yüz kutusu boyutu
  final double pitch, yaw, roll; // radyan (roll: saat yönü +)
  final double mouth; // ağız açıklığı 0..1
  final double smile; // gülümseme olasılığı 0..1
  final double eyeOpenL, eyeOpenR; // göz açıklığı 0..1
  final Float32List pts; // P.count × (x,y), normalize

  const FxFrame({
    required this.effect,
    required this.hasFace,
    required this.cx,
    required this.cy,
    required this.w,
    required this.h,
    required this.pitch,
    required this.yaw,
    required this.roll,
    required this.mouth,
    required this.smile,
    required this.eyeOpenL,
    required this.eyeOpenR,
    required this.pts,
  });

  static final off = FxFrame.faceless('none');

  /// Yüzsüz kare: sihir efektleri yüz algılanmadan da akar.
  factory FxFrame.faceless(String effect) => FxFrame(
        effect: effect,
        hasFace: false,
        cx: 0.5, cy: 0.45, w: 0, h: 0,
        pitch: 0, yaw: 0, roll: 0,
        mouth: 0, smile: 0, eyeOpenL: 1, eyeOpenR: 1,
        pts: Float32List(P.count * 2),
      );

  /// Yalnızca efekt kimliğine bakılır: sihir efektleri yüzsüz de çizilir.
  bool get isOff => effect == 'none';

  Offset pt(int i) => Offset(pts[i * 2], pts[i * 2 + 1]);

  /// Yüz kutusundan makul bir nokta takımı sentezler — küçük resimler,
  /// v1 kareler ve kontur alınamayan kareler için.
  factory FxFrame.fromBox({
    required String effect,
    required double cx,
    required double cy,
    required double w,
    required double h,
    double roll = 0,
    double mouth = 0,
    double smile = 0,
  }) {
    final pts = Float32List(P.count * 2);
    void set(int i, double x, double y) {
      pts[i * 2] = x;
      pts[i * 2 + 1] = y;
    }

    // Oval: elips, tepe ortasından saat yönünde.
    for (var i = 0; i < P.ovalN; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / P.ovalN;
      set(P.oval + i, cx + w * 0.5 * math.cos(a), cy + h * 0.5 * math.sin(a));
    }
    // Kaşlar (dış, orta, iç).
    set(P.browL, cx - w * 0.30, cy - h * 0.17);
    set(P.browL + 1, cx - w * 0.19, cy - h * 0.21);
    set(P.browL + 2, cx - w * 0.08, cy - h * 0.17);
    set(P.browR, cx + w * 0.30, cy - h * 0.17);
    set(P.browR + 1, cx + w * 0.19, cy - h * 0.21);
    set(P.browR + 2, cx + w * 0.08, cy - h * 0.17);
    // Gözler (dış, üst, iç, alt).
    set(P.eyeL, cx - w * 0.28, cy - h * 0.08);
    set(P.eyeL + 1, cx - w * 0.19, cy - h * 0.11);
    set(P.eyeL + 2, cx - w * 0.10, cy - h * 0.08);
    set(P.eyeL + 3, cx - w * 0.19, cy - h * 0.05);
    set(P.eyeR, cx + w * 0.28, cy - h * 0.08);
    set(P.eyeR + 1, cx + w * 0.19, cy - h * 0.11);
    set(P.eyeR + 2, cx + w * 0.10, cy - h * 0.08);
    set(P.eyeR + 3, cx + w * 0.19, cy - h * 0.05);
    // Dudaklar — ağız açıklığı alt dudağı aşağı iter.
    final my = cy + h * 0.24;
    final drop = h * 0.10 * mouth;
    set(P.lipT, cx - w * 0.16, my);
    set(P.lipT + 1, cx, my - h * 0.035);
    set(P.lipT + 2, cx + w * 0.16, my);
    set(P.lipB, cx - w * 0.13, my + h * 0.05 + drop * 0.8);
    set(P.lipB + 1, cx, my + h * 0.065 + drop);
    set(P.lipB + 2, cx + w * 0.13, my + h * 0.05 + drop * 0.8);
    set(P.lipInT, cx, my - h * 0.005);
    set(P.lipInB, cx, my + h * 0.02 + drop * 0.85);
    // Burun.
    set(P.noseTop, cx, cy - h * 0.08);
    set(P.noseTip, cx, cy + h * 0.09);
    set(P.noseBotL, cx - w * 0.07, cy + h * 0.12);
    set(P.noseBotC, cx, cy + h * 0.13);
    set(P.noseBotR, cx + w * 0.07, cy + h * 0.12);
    // Yanaklar.
    set(P.cheekL, cx - w * 0.26, cy + h * 0.10);
    set(P.cheekR, cx + w * 0.26, cy + h * 0.10);

    return FxFrame(
      effect: effect,
      hasFace: w > 0,
      cx: cx, cy: cy, w: w, h: h,
      pitch: 0, yaw: 0, roll: roll,
      mouth: mouth, smile: smile, eyeOpenL: 1, eyeOpenR: 1,
      pts: pts,
    );
  }

  /// X eksenine göre aynalar; sol/sağ grupları anlamlarına göre değiş
  /// tokuş eder ki "sol göz" hep izleyenin solunda kalsın.
  FxFrame mirrored() {
    final m = Float32List(P.count * 2);
    void put(int dst, int src) {
      m[dst * 2] = 1 - pts[src * 2];
      m[dst * 2 + 1] = pts[src * 2 + 1];
    }

    // Oval: tepe sabit, saat yönü tersine döner.
    for (var i = 0; i < P.ovalN; i++) {
      put(P.oval + i, P.oval + (P.ovalN - i) % P.ovalN);
    }
    // Kaş/göz sıraları iki yanda da (dış→iç) tanımlı: gruplar takas edilir.
    for (var j = 0; j < 3; j++) {
      put(P.browL + j, P.browR + j);
      put(P.browR + j, P.browL + j);
    }
    for (var j = 0; j < 4; j++) {
      put(P.eyeL + j, P.eyeR + j);
      put(P.eyeR + j, P.eyeL + j);
    }
    // Dudaklar: sol/sağ köşeler takas.
    put(P.lipT, P.lipT + 2);
    put(P.lipT + 1, P.lipT + 1);
    put(P.lipT + 2, P.lipT);
    put(P.lipB, P.lipB + 2);
    put(P.lipB + 1, P.lipB + 1);
    put(P.lipB + 2, P.lipB);
    put(P.lipInT, P.lipInT);
    put(P.lipInB, P.lipInB);
    put(P.noseTop, P.noseTop);
    put(P.noseTip, P.noseTip);
    put(P.noseBotL, P.noseBotR);
    put(P.noseBotC, P.noseBotC);
    put(P.noseBotR, P.noseBotL);
    put(P.cheekL, P.cheekR);
    put(P.cheekR, P.cheekL);

    return FxFrame(
      effect: effect,
      hasFace: hasFace,
      cx: 1 - cx, cy: cy, w: w, h: h,
      pitch: pitch, yaw: -yaw, roll: -roll,
      mouth: mouth, smile: smile,
      eyeOpenL: eyeOpenR, eyeOpenR: eyeOpenL,
      pts: m,
    );
  }

  // ---- Tel formatı ----

  static const _version = 2;

  Uint8List encode() {
    final eff = ascii.encode(effect);
    final n = hasFace ? P.count : 0;
    final buf = ByteData(3 + eff.length + 8 + 6 + 4 + 1 + n * 4);
    var o = 0;
    buf.setUint8(o++, _version);
    buf.setUint8(o++, hasFace ? 1 : 0);
    buf.setUint8(o++, eff.length);
    for (final b in eff) {
      buf.setUint8(o++, b);
    }
    int q16(double v) => (v.clamp(0.0, 1.0) * 65535).round();
    int a16(double v) => (v.clamp(-3.2, 3.2) * 10000).round();
    int q8(double v) => (v.clamp(0.0, 1.0) * 255).round();
    for (final v in [cx, cy, w, h]) {
      buf.setUint16(o, q16(v));
      o += 2;
    }
    for (final v in [pitch, yaw, roll]) {
      buf.setInt16(o, a16(v));
      o += 2;
    }
    for (final v in [mouth, smile, eyeOpenL, eyeOpenR]) {
      buf.setUint8(o++, q8(v));
    }
    buf.setUint8(o++, n);
    for (var i = 0; i < n * 2; i++) {
      buf.setUint16(o, q16(pts[i]));
      o += 2;
    }
    return buf.buffer.asUint8List();
  }

  static FxFrame? decode(List<int> bytes) {
    if (bytes.isEmpty) return null;
    if (bytes.first == 0x7B) return _decodeLegacyJson(bytes); // '{'
    if (bytes.first != _version) return null;
    try {
      final buf = ByteData.sublistView(Uint8List.fromList(bytes));
      var o = 1;
      final hasFace = buf.getUint8(o++) == 1;
      final effLen = buf.getUint8(o++);
      final effect = ascii.decode(bytes.sublist(o, o + effLen));
      o += effLen;
      double u16() {
        final v = buf.getUint16(o) / 65535;
        o += 2;
        return v;
      }
      double i16() {
        final v = buf.getInt16(o) / 10000;
        o += 2;
        return v;
      }
      double u8() => buf.getUint8(o++) / 255;
      final cx = u16(), cy = u16(), w = u16(), h = u16();
      final pitch = i16(), yaw = i16(), roll = i16();
      final mouth = u8(), smile = u8(), eyeL = u8(), eyeR = u8();
      final n = buf.getUint8(o++);
      final pts = Float32List(P.count * 2);
      for (var i = 0; i < n * 2 && i < pts.length; i++) {
        pts[i] = u16();
      }
      if (n == 0 && w > 0) {
        // Nokta gönderilmemiş: kutudan sentezle.
        return FxFrame.fromBox(
            effect: effect, cx: cx, cy: cy, w: w, h: h,
            roll: roll, mouth: mouth, smile: smile);
      }
      return FxFrame(
        effect: effect, hasFace: hasFace,
        cx: cx, cy: cy, w: w, h: h,
        pitch: pitch, yaw: yaw, roll: roll,
        mouth: mouth, smile: smile, eyeOpenL: eyeL, eyeOpenR: eyeR,
        pts: pts,
      );
    } catch (_) {
      return null;
    }
  }

  /// v1 (JSON) kareleri: eski sürümle karışık aramada efekt yine görünsün.
  static FxFrame? _decodeLegacyJson(List<int> bytes) {
    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final e = json['e'] as String?;
      final f = (json['f'] as List?)?.cast<num>();
      if (e == null || f == null || f.length != 12) return null;
      if (f[2] == 0) return FxFrame.faceless(e);
      return FxFrame.fromBox(
        effect: e,
        cx: f[0].toDouble(), cy: f[1].toDouble(),
        w: f[2].toDouble(), h: f[3].toDouble(),
        roll: f[4].toDouble(), mouth: f[5].toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
