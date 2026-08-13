import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
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
  void Function(FxFrame?)? onFace;
  String effect = 'none';

  void start() {
    _timer ??= Timer.periodic(const Duration(milliseconds: 125), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
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
        onFace?.call(null);
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

    // Hedef genişlik ~192 px — ML Kit'e yeter, dönüşüm ucuz kalır.
    final ratio = 192 / render.size.width;
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

  static Uint8List _rgbaToNv21(Uint8List rgba, int stride, int w, int h) {
    final out = Uint8List(w * h + (w * h) ~/ 2);
    var uv = w * h;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * stride + x) * 4;
        final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
        out[y * w + x] =
            ((66 * r + 129 * g + 25 * b + 128) >> 8) + 16;
        if (y.isEven && x.isEven) {
          out[uv++] = (((112 * r - 94 * g - 18 * b + 128) >> 8) + 128)
              .clamp(0, 255); // V
          out[uv++] = (((-38 * r - 74 * g + 112 * b + 128) >> 8) + 128)
              .clamp(0, 255); // U
        }
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
