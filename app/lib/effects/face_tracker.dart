import 'dart:async';
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
/// RepaintBoundary ile sarılır, ~8 fps ile küçük bir görüntüsü alınır,
/// NV21'e çevrilip ML Kit yüz algılamaya verilir. Efekt kapalıyken maliyet sıfır.
class FaceTracker {
  final GlobalKey previewKey;
  final bool mirrorInput; // ön kamera önizlemesi aynalı mı

  FaceTracker({required this.previewKey, this.mirrorInput = true});

  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableLandmarks: true,
      enableTracking: true,
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
  /// donuyordu. Artık bir sonraki tur, ölçülen sürenin ~2 katı sonrasına
  /// kurulur: hızlı cihazda 8 fps, yavaş cihazda kendiliğinden 2-3 fps.
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
        // Sihir efektleri yüzsüz de akar (kar, konfeti…): boş yüzlü kare
        // gönderilir; yüze bağlı efektlerde overlay temizlenir.
        onFace?.call(kMagicFx.contains(effect)
            ? FxFrame(
                effect: effect,
                cx: 0.5, cy: 0.45, w: 0, h: 0, rz: 0, mouth: 0,
                lx: 0, ly: 0, rx: 0, ry: 0, nx: 0, ny: 0)
            : null);
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

    // Hedef genişlik ~160 px — ML Kit'in yüz bulması için fazlasıyla yeter,
    // dönüştürülecek piksel sayısını 192'ye göre üçte bir azaltır.
    final ratio = 160 / render.size.width;
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
    final out = Uint8List(ySize + ySize ~/ 2)..fillRange(ySize, ySize + ySize ~/ 2, 128);
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

  /// ML Kit yüzünü, yayınlanan (aynasız) kareye normalize edilmiş FxFrame'e çevirir.
  FxFrame _toFrame(Face face, double w, double h) {
    double nx(double x) => (x / w).clamp(0.0, 1.0);
    double ny(double y) => (y / h).clamp(0.0, 1.0);

    final box = face.boundingBox;
    final left = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final right = face.landmarks[FaceLandmarkType.rightEye]?.position;
    final nose = face.landmarks[FaceLandmarkType.noseBase]?.position;
    final mouthBottom = face.landmarks[FaceLandmarkType.bottomMouth]?.position;

    // Ağız açıklığı: alt dudak ile burun arası mesafenin yüz yüksekliğine oranı.
    // Kapalı ağızda ~0.28, tam açıkta ~0.45 civarı ölçülür → 0..1'e eşle.
    var mouth = 0.0;
    if (nose != null && mouthBottom != null && box.height > 0) {
      final d = (mouthBottom.y - nose.y) / box.height;
      mouth = ((d - 0.30) / 0.15).clamp(0.0, 1.0);
    }

    final frame = FxFrame(
      effect: effect,
      cx: nx(box.center.dx),
      cy: ny(box.center.dy),
      w: (box.width / w).clamp(0.0, 1.0),
      h: (box.height / h).clamp(0.0, 1.0),
      rz: -(face.headEulerAngleZ ?? 0) * 3.14159 / 180,
      mouth: mouth,
      lx: left != null ? nx(left.x.toDouble()) : 0,
      ly: left != null ? ny(left.y.toDouble()) : 0,
      rx: right != null ? nx(right.x.toDouble()) : 0,
      ry: right != null ? ny(right.y.toDouble()) : 0,
      nx: nose != null ? nx(nose.x.toDouble()) : 0,
      ny: nose != null ? ny(nose.y.toDouble()) : 0,
    );
    // Yakalama aynalı önizlemeden yapıldıysa yayın koordinatlarına çevir.
    return mirrorInput ? frame.mirrored() : frame;
  }
}
