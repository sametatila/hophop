import 'dart:math' as math;
import 'dart:typed_data';
import 'fx_frame.dart';

/// One-Euro düşük geçiren filtre (Casiez et al. 2012).
///
/// Kesim frekansı hıza göre uyarlanır: yüz dururken güçlü yumuşatma
/// (titreme yok), hızlı dönüşte zayıf yumuşatma (gecikme yok). Snapchat
/// benzeri "yapışık" his tam olarak bu dengeden gelir.
class OneEuro {
  final double minCutoff; // Hz — durağan haldeki yumuşatma
  final double beta; // hız katsayısı — büyüdükçe harekete çabuk uyar
  final double dCutoff;

  double? _x;
  double _dx = 0;

  OneEuro({this.minCutoff = 1.2, this.beta = 12.0, this.dCutoff = 1.0});

  static double _alpha(double cutoff, double dt) {
    final tau = 1 / (2 * math.pi * cutoff);
    return 1 / (1 + tau / dt);
  }

  double filter(double x, double dt) {
    final prev = _x;
    if (prev == null || dt <= 0) {
      _x = x;
      return x;
    }
    final dx = (x - prev) / dt;
    _dx = _dx + _alpha(dCutoff, dt) * (dx - _dx);
    final cutoff = minCutoff + beta * _dx.abs();
    final v = prev + _alpha(cutoff, dt) * (x - prev);
    _x = v;
    return v;
  }

  void reset() {
    _x = null;
    _dx = 0;
  }
}

/// Seyrek algılama karelerini (2-8 fps) akıcı 60 fps overlay'e çevirir.
///
/// [feed] her algılamada çağrılır; [sample] her çizim karesinde çağrılır ve
/// son hedefe One-Euro ile yaklaşan ara kare üretir. Böylece yüz kutusu
/// "zıplamaz", efekt yüzü yumuşakça takip eder. Yüz kaybolduğunda kısa bir
/// tolerans süresi son kare korunur (algılama tekleyince efekt yanıp sönmez).
class FxSmoother {
  final _watch = Stopwatch()..start();

  FxFrame? _target;
  double _targetAt = 0;
  double _lastSample = 0;
  String _effect = 'none';

  // Kanal filtreleri: kutu+duruş+olasılıklar (11) ve nokta koordinatları.
  final _scalars = List.generate(11, (_) => OneEuro());
  final _points =
      List.generate(P.count * 2, (_) => OneEuro(minCutoff: 1.0, beta: 10.0));

  /// Yüz yokken karenin asılı kalacağı süre.
  static const _holdSec = 0.6;

  double get _now => _watch.elapsedMicroseconds / 1e6;

  void feed(FxFrame? frame) {
    if (frame == null || frame.effect != _effect) {
      // Efekt değişti ya da izleme durdu: eskisini sürdürme, sıçrayarak başla.
      _reset();
      _effect = frame?.effect ?? 'none';
    }
    if (frame == null) {
      _target = null;
      return;
    }
    if (_target != null && !frame.hasFace && _target!.hasFace) {
      // Yüz tekledi: tolerans süresi boyunca son yüzlü kareyi hedef tut.
      if (_now - _targetAt < _holdSec) return;
    }
    _target = frame;
    _targetAt = _now;
  }

  /// Çizilecek ara kareyi üretir; efekt kapalıysa null.
  FxFrame? sample() {
    final t = _target;
    if (t == null || t.isOff) return null;
    final now = _now;
    if (!t.hasFace) {
      // Yüzsüz kare (sihir): yumuşatılacak geometri yok.
      _lastSample = now;
      return t;
    }
    if (now - _targetAt > _holdSec * 4) {
      // Veri uzun süredir gelmiyor (uzak taraf sustu): overlay'i bırak.
      return null;
    }
    final dt = (now - _lastSample).clamp(0.001, 0.25);
    _lastSample = now;

    double s(int i, double v) => _scalars[i].filter(v, dt);
    final pts = Float32List(P.count * 2);
    for (var i = 0; i < pts.length; i++) {
      pts[i] = _points[i].filter(t.pts[i], dt);
    }
    return FxFrame(
      effect: t.effect,
      hasFace: true,
      cx: s(0, t.cx), cy: s(1, t.cy), w: s(2, t.w), h: s(3, t.h),
      pitch: s(4, t.pitch), yaw: s(5, t.yaw), roll: s(6, t.roll),
      mouth: s(7, t.mouth), smile: s(8, t.smile),
      eyeOpenL: s(9, t.eyeOpenL), eyeOpenR: s(10, t.eyeOpenR),
      pts: pts,
    );
  }

  void _reset() {
    for (final f in _scalars) {
      f.reset();
    }
    for (final f in _points) {
      f.reset();
    }
    _target = null;
  }
}
