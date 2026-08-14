import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'effect_painter.dart' show kMagicFx;
import 'fx_frame.dart';

/// Yerel kamera önizlemesinden yüz izleme.
///
/// LiveKit'in kamera karelerine Flutter'dan doğrudan erişim (video processor)
/// henüz olgun olmadığı için pragmatik yol: yerel önizleme widget'ı bir
/// RepaintBoundary ile sarılır, uyarlanır tempoda küçük bir görüntüsü alınır,
/// NV21'e çevrilip ML Kit yüz algılamaya verilir. Efekt kapalıyken maliyet
/// sıfır. Kontur kipi açıktır: 47 seçilmiş nokta + pitch/yaw/roll +
/// gülümseme/göz açıklığı olasılıkları FxFrame'e doldurulur; seyrek kareler
/// FxSmoother ile 60 fps'e yumuşatılır.
class FaceTracker {
  final GlobalKey previewKey;
  final bool mirrorInput; // ön kamera önizlemesi aynalı mı

  FaceTracker({required this.previewKey, this.mirrorInput = true});

  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableContours: true,
      enableClassification: true,
      enableLandmarks: true, // kontur eksik dönerse yedek
    ),
  );

  Timer? _timer;
  bool _busy = false;
  bool _running = false;
  void Function(FxFrame?)? onFace;
  String effect = 'none';

  /// Hedef tempo (güçlü cihaz). Gerçek tempo ölçüme göre yavaşlar.
  static const _minPeriod = Duration(milliseconds: 125);
  static const _maxPeriod = Duration(milliseconds: 500);
  Duration _period = _minPeriod;

  void start() {
    if (_running) return;
    _running = true;
    _schedule();
  }

  /// Sabit periyot yerine kendi kendini ayarlayan zamanlayıcı.
  ///
  /// Bir turun maliyeti cihazdan cihaza çok değişiyor: toImage() GPU'dan geri
  /// okuma yapar, ML Kit ayrı bir kanal turu ister. Zayıf telefonda tur 200 ms
  /// sürerken 125 ms'de bir tetiklemek UI iş parçacığını doyuruyor ve görüntü
  /// donuyordu. Bir sonraki tur, ölçülen sürenin ~2 katı sonrasına kurulur:
  /// hızlı cihazda 8 fps, yavaş cihazda kendiliğinden 2-3 fps. Aradaki
  /// kareleri FxSmoother doldurduğu için düşük tempo da akıcı görünür.
  void _schedule() {
    _timer = Timer(_period, () async {
      if (!_running) return;
      final sw = Stopwatch()..start();
      await _tick();
      sw.stop();
      final target = sw.elapsed * 2;
      _period = target < _minPeriod
          ? _minPeriod
          : (target > _maxPeriod ? _maxPeriod : target);
      if (_running) _schedule();
    });
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _period = _minPeriod;
    onFace?.call(null);
  }

  Future<void> dispose() async {
    stop();
    await _detector.close();
  }

  Future<void> _tick() async {
    if (_busy || effect == 'none') return;
    _busy = true;
    try {
      final captured = await _capture();
      if (captured == null) return;
      final (bytes, width, height) = captured;
      final input = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: ui.Size(width.toDouble(), height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: width,
        ),
      );
      final faces = await _detector.processImage(input);
      if (faces.isEmpty) {
        // Sihir efektleri yüzsüz de akar (kar, konfeti…): yüzsüz kare
        // gönderilir; yüze bağlı efektlerde overlay temizlenir.
        onFace?.call(
            kMagicFx.contains(effect) ? FxFrame.faceless(effect) : null);
        return;
      }
      onFace?.call(_toFrame(faces.first, width.toDouble(), height.toDouble()));
    } catch (_) {
      // izleme hatası görüşmeyi asla bozmasın
    } finally {
      _busy = false;
    }
  }

  /// Önizlemeyi küçük çözünürlükte yakalar, NV21'e çevirir.
  Future<(Uint8List, int, int)?> _capture() async {
    final ctx = previewKey.currentContext;
    final render = ctx?.findRenderObject();
    if (render is! RenderRepaintBoundary || render.size.isEmpty) return null;

    // Hedef genişlik ~224 px — kontur noktalarının hassasiyeti yakalama
    // çözünürlüğüyle sınırlı; 160 px kutu için yeterdi ama dudak/göz
    // konturları 224'te belirgin biçimde oturuyor.
    final ratio = 224 / render.size.width;
    final image = await render.toImage(pixelRatio: ratio.clamp(0.05, 1.0));
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return null;
      // NV21: çift boyutlar gerekir.
      final w = image.width & ~1;
      final h = image.height & ~1;
      return (_rgbaToNv21(data.buffer.asUint8List(), image.width, w, h), w, h);
    } finally {
      image.dispose();
    }
  }

  /// RGBA → NV21.
  ///
  /// Yalnızca parlaklık (Y) düzlemi hesaplanır; renk (UV) düzlemi nötr 128 ile
  /// doldurulur. ML Kit yüz algılama gri tonlama üzerinden çalıştığı için renk
  /// bilgisi sonucu değiştirmiyor — ama piksel başına iki çarpma + iki clamp
  /// daha az iş demek. (NV21 biçimi UV düzleminin var olmasını şart koşar,
  /// içeriğini değil.)
  static Uint8List _rgbaToNv21(Uint8List rgba, int stride, int w, int h) {
    final ySize = w * h;
    final out = Uint8List(ySize + ySize ~/ 2)
      ..fillRange(ySize, ySize + ySize ~/ 2, 128);
    for (var y = 0; y < h; y++) {
      var i = y * stride * 4;
      var o = y * w;
      for (var x = 0; x < w; x++) {
        out[o++] =
            ((66 * rgba[i] + 129 * rgba[i + 1] + 25 * rgba[i + 2] + 128) >> 8) +
                16;
        i += 4;
      }
    }
    return out;
  }

  /// ML Kit yüzünü, yayınlanan (aynasız) kareye normalize edilmiş FxFrame'e
  /// çevirir. Sol/sağ ayrımı ML Kit'in etiketine değil görüntüdeki konuma
  /// (x) göre yapılır — aynalı yakalamada etiketler tersine döner, konum
  /// dönmez.
  FxFrame _toFrame(Face face, double w, double h) {
    Offset np(math.Point<int> p) => Offset(
        (p.x / w).clamp(0.0, 1.0), (p.y / h).clamp(0.0, 1.0));
    List<Offset>? cont(FaceContourType t) {
      final ps = face.contours[t]?.points;
      if (ps == null || ps.isEmpty) return null;
      return [for (final p in ps) np(p)];
    }

    final box = face.boundingBox;
    final cx = (box.center.dx / w).clamp(0.0, 1.0);
    final cy = (box.center.dy / h).clamp(0.0, 1.0);
    final bw = (box.width / w).clamp(0.0, 1.0);
    final bh = (box.height / h).clamp(0.0, 1.0);
    const d2r = math.pi / 180;
    final pitch = (face.headEulerAngleX ?? 0) * d2r;
    final yaw = -(face.headEulerAngleY ?? 0) * d2r;
    final roll = -(face.headEulerAngleZ ?? 0) * d2r;

    final oval = cont(FaceContourType.face);
    final eyeA = cont(FaceContourType.leftEye);
    final eyeB = cont(FaceContourType.rightEye);
    final browA = cont(FaceContourType.leftEyebrowTop);
    final browB = cont(FaceContourType.rightEyebrowTop);
    final lipTT = cont(FaceContourType.upperLipTop);
    final lipTB = cont(FaceContourType.upperLipBottom);
    final lipBT = cont(FaceContourType.lowerLipTop);
    final lipBB = cont(FaceContourType.lowerLipBottom);
    final noseB = cont(FaceContourType.noseBridge);
    final noseBot = cont(FaceContourType.noseBottom);
    final cheekA = cont(FaceContourType.leftCheek);
    final cheekB = cont(FaceContourType.rightCheek);

    FxFrame frame;
    if (oval == null ||
        eyeA == null || eyeB == null ||
        browA == null || browB == null ||
        lipTT == null || lipTB == null ||
        lipBT == null || lipBB == null) {
      // Kontur alınamadı: kutu + eski usul ağız kestirimi ile sentezle.
      final nose = face.landmarks[FaceLandmarkType.noseBase]?.position;
      final mouthB = face.landmarks[FaceLandmarkType.bottomMouth]?.position;
      var mouth = 0.0;
      if (nose != null && mouthB != null && box.height > 0) {
        final d = (mouthB.y - nose.y) / box.height;
        mouth = ((d - 0.30) / 0.15).clamp(0.0, 1.0);
      }
      frame = FxFrame.fromBox(
          effect: effect, cx: cx, cy: cy, w: bw, h: bh,
          roll: roll, mouth: mouth,
          smile: face.smilingProbability ?? 0);
    } else {
      final pts = Float32List(P.count * 2);
      void set(int i, Offset p) {
        pts[i * 2] = p.dx;
        pts[i * 2 + 1] = p.dy;
      }

      // Oval: 36 nokta tepe ortasından saat yönünde gelir → 18'e seyrelt.
      for (var i = 0; i < P.ovalN; i++) {
        set(P.oval + i, oval[(i * oval.length ~/ P.ovalN) % oval.length]);
      }

      // Görüntü-soluna göre ata (etikete güvenme).
      Offset centroid(List<Offset> l) =>
          l.reduce((a, b) => a + b) / l.length.toDouble();
      final aLeft = centroid(eyeA).dx <= centroid(eyeB).dx;
      final eyeL = aLeft ? eyeA : eyeB, eyeR = aLeft ? eyeB : eyeA;
      final bLeft = centroid(browA).dx <= centroid(browB).dx;
      final browL = bLeft ? browA : browB, browR = bLeft ? browB : browA;

      Offset minX(List<Offset> l) => l.reduce((a, b) => a.dx < b.dx ? a : b);
      Offset maxX(List<Offset> l) => l.reduce((a, b) => a.dx > b.dx ? a : b);
      Offset minY(List<Offset> l) => l.reduce((a, b) => a.dy < b.dy ? a : b);
      Offset maxY(List<Offset> l) => l.reduce((a, b) => a.dy > b.dy ? a : b);
      Offset mid(List<Offset> l) => l[l.length ~/ 2];

      // Gözler: (dış köşe, üst, iç köşe, alt).
      set(P.eyeL, minX(eyeL));
      set(P.eyeL + 1, minY(eyeL));
      set(P.eyeL + 2, maxX(eyeL));
      set(P.eyeL + 3, maxY(eyeL));
      set(P.eyeR, maxX(eyeR));
      set(P.eyeR + 1, minY(eyeR));
      set(P.eyeR + 2, minX(eyeR));
      set(P.eyeR + 3, maxY(eyeR));

      // Kaşlar: (dış uç, orta, iç uç).
      set(P.browL, minX(browL));
      set(P.browL + 1, mid(browL));
      set(P.browL + 2, maxX(browL));
      set(P.browR, maxX(browR));
      set(P.browR + 1, mid(browR));
      set(P.browR + 2, minX(browR));

      // Dudaklar: köşeler + orta noktalar.
      set(P.lipT, minX(lipTT));
      set(P.lipT + 1, mid(lipTT));
      set(P.lipT + 2, maxX(lipTT));
      set(P.lipB, minX(lipBB));
      set(P.lipB + 1, mid(lipBB));
      set(P.lipB + 2, maxX(lipBB));
      set(P.lipInT, mid(lipTB));
      set(P.lipInB, mid(lipBT));

      // Burun.
      final bridge = noseB ?? [Offset(cx, cy - bh * 0.08), Offset(cx, cy + bh * 0.09)];
      set(P.noseTop, minY(bridge));
      set(P.noseTip, maxY(bridge));
      final nb = noseBot ??
          [Offset(cx - bw * 0.07, cy + bh * 0.12), Offset(cx, cy + bh * 0.13), Offset(cx + bw * 0.07, cy + bh * 0.12)];
      set(P.noseBotL, minX(nb));
      set(P.noseBotC, mid(nb));
      set(P.noseBotR, maxX(nb));

      // Yanaklar.
      final ca = cheekA?.first ?? Offset(cx - bw * 0.26, cy + bh * 0.10);
      final cb = cheekB?.first ?? Offset(cx + bw * 0.26, cy + bh * 0.10);
      set(P.cheekL, ca.dx <= cb.dx ? ca : cb);
      set(P.cheekR, ca.dx <= cb.dx ? cb : ca);

      // Ağız açıklığı: iç dudaklar arası boşluğun yüz yüksekliğine oranı.
      final gap = (pts[P.lipInB * 2 + 1] - pts[P.lipInT * 2 + 1]) / (bh == 0 ? 1 : bh);
      final mouth = ((gap - 0.015) / 0.09).clamp(0.0, 1.0);

      // Göz olasılıkları: aynalı yakalamada ML Kit'in "sol"u görüntü-sağıdır.
      final probA = face.leftEyeOpenProbability ?? 1.0;
      final probB = face.rightEyeOpenProbability ?? 1.0;

      frame = FxFrame(
        effect: effect,
        hasFace: true,
        cx: cx, cy: cy, w: bw, h: bh,
        pitch: pitch, yaw: yaw, roll: roll,
        mouth: mouth,
        smile: face.smilingProbability ?? 0,
        eyeOpenL: probB, eyeOpenR: probA,
        pts: pts,
      );
    }
    // Yakalama aynalı önizlemeden yapıldıysa yayın koordinatlarına çevir.
    return mirrorInput ? frame.mirrored() : frame;
  }
}
