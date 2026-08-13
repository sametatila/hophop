import 'dart:convert';

/// Bir karedeki yüz durumu + seçili efekt.
///
/// Koordinatlar 0..1 aralığında, YAYINLANAN (aynalanmamış) video karesine göre
/// normalize edilir. Yerel önizleme aynalı gösterildiği için yerelde çizerken
/// [mirrored] kullanılır; karşı taraf olduğu gibi çizer.
class FxFrame {
  final String effect; // none | bunny | dog | crown | glasses | mustache
  final double cx, cy; // yüz merkezi
  final double w, h; // yüz kutusu boyutu
  final double rz; // kafa eğimi (radyan, saat yönü +)
  final double mouth; // ağız açıklığı 0..1
  final double lx, ly; // sol göz
  final double rx, ry; // sağ göz
  final double nx, ny; // burun

  const FxFrame({
    required this.effect,
    required this.cx,
    required this.cy,
    required this.w,
    required this.h,
    required this.rz,
    required this.mouth,
    required this.lx,
    required this.ly,
    required this.rx,
    required this.ry,
    required this.nx,
    required this.ny,
  });

  static const off = FxFrame(
    effect: 'none',
    cx: 0, cy: 0, w: 0, h: 0, rz: 0, mouth: 0,
    lx: 0, ly: 0, rx: 0, ry: 0, nx: 0, ny: 0,
  );

  bool get isOff => effect == 'none' || w == 0;

  FxFrame mirrored() => FxFrame(
        effect: effect,
        cx: 1 - cx, cy: cy, w: w, h: h, rz: -rz, mouth: mouth,
        lx: 1 - rx, ly: ry, rx: 1 - lx, ry: ly, nx: 1 - nx, ny: ny,
      );

  Map<String, dynamic> toJson() => {
        'e': effect,
        'f': [cx, cy, w, h, rz, mouth, lx, ly, rx, ry, nx, ny]
            .map((v) => double.parse(v.toStringAsFixed(4)))
            .toList(),
      };

  static FxFrame? fromJson(Map<String, dynamic> json) {
    final e = json['e'] as String?;
    final f = (json['f'] as List?)?.cast<num>();
    if (e == null || f == null || f.length != 12) return null;
    return FxFrame(
      effect: e,
      cx: f[0].toDouble(), cy: f[1].toDouble(),
      w: f[2].toDouble(), h: f[3].toDouble(),
      rz: f[4].toDouble(), mouth: f[5].toDouble(),
      lx: f[6].toDouble(), ly: f[7].toDouble(),
      rx: f[8].toDouble(), ry: f[9].toDouble(),
      nx: f[10].toDouble(), ny: f[11].toDouble(),
    );
  }

  List<int> encode() => utf8.encode(jsonEncode(toJson()));

  static FxFrame? decode(List<int> bytes) {
    try {
      return fromJson(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
