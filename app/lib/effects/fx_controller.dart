import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:livekit_client/livekit_client.dart';
import 'face_tracker.dart';
import 'fx_frame.dart';
import 'fx_smoother.dart';

/// Efekt orkestrasyonu:
/// - yerel yüz izleme (FaceTracker) → yerel önizleme üstüne çizim
/// - yüz verisini LiveKit data channel'dan karşıya gönderme (topic: 'fx')
/// - karşıdan gelen 'fx' verisini uzak video üstüne çizim
///
/// Video karesine hiç dokunulmaz → E2EE bozulmaz, işlem maliyeti düşük.
/// Ham algılama kareleri seyrektir (2-8 fps); hem yerel hem uzak taraf için
/// FxSmoother ara kareleri üretir, EffectPainter her tikte oradan örnekler.
class FxController {
  final Room room;
  final FaceTracker tracker;

  /// Yerel önizlemeye çizilecek ham kare (aynalı koordinatlarda) —
  /// UI yeniden kurulumu ve "efekt aktif mi" kararı için.
  final localFx = ValueNotifier<FxFrame?>(null);

  /// Yerel yumuşatıcı: EffectPainter buradan 60 fps ara kare örnekler.
  final localSmooth = FxSmoother();

  /// Uzak ham kareler — katılımcı kimliğine göre (grup aramada her kişinin
  /// kendi efekti kendi karosuna çizilir).
  final remoteFx = ValueNotifier<Map<String, FxFrame>>({});

  /// Uzak yumuşatıcılar — katılımcı başına bir tane.
  final _remoteSmooth = <String, FxSmoother>{};

  final effect = ValueNotifier<String>('none');

  EventsListener<RoomEvent>? _listener;
  final _remoteExpiry = <String, Timer>{};

  FxController({required this.room, required GlobalKey localPreviewKey})
      : tracker = FaceTracker(previewKey: localPreviewKey) {
    tracker.onFace = _onLocalFace;
    effect.addListener(_onEffectChanged);
    _listener = room.createListener()
      ..on<DataReceivedEvent>((e) {
        if (e.topic != 'fx') return;
        final identity = e.participant?.identity;
        if (identity == null) return;
        final frame = FxFrame.decode(e.data);
        if (frame == null) return;
        final map = Map<String, FxFrame>.from(remoteFx.value);
        if (frame.isOff) {
          map.remove(identity);
          _remoteSmooth[identity]?.feed(null);
        } else {
          map[identity] = frame;
          remoteSmoother(identity).feed(frame);
        }
        remoteFx.value = map;
        // Veri kesilirse eskimiş overlay asılı kalmasın.
        _remoteExpiry[identity]?.cancel();
        _remoteExpiry[identity] = Timer(const Duration(seconds: 2), () {
          final m = Map<String, FxFrame>.from(remoteFx.value)..remove(identity);
          remoteFx.value = m;
          _remoteSmooth[identity]?.feed(null);
        });
      });
  }

  FxSmoother remoteSmoother(String identity) =>
      _remoteSmooth.putIfAbsent(identity, FxSmoother.new);

  void _onEffectChanged() {
    tracker.effect = effect.value;
    if (effect.value == 'none') {
      tracker.stop();
      localFx.value = null;
      localSmooth.feed(null);
      _publish(FxFrame.off); // karşıdaki overlay'i temizle
    } else {
      tracker.start();
    }
  }

  void _onLocalFace(FxFrame? frame) {
    // Yerel önizleme aynalı → çizim için geri aynala.
    final mirrored = frame?.mirrored();
    localFx.value = mirrored;
    localSmooth.feed(mirrored);
    if (frame != null) _publish(frame);
  }

  void _publish(FxFrame frame) {
    // Güvenilmez (lossy) gönderim: canlı izleme verisi, kayıp kare önemsiz.
    room.localParticipant
        ?.publishData(frame.encode(), reliable: false, topic: 'fx')
        .catchError((_) {});
  }

  Future<void> dispose() async {
    effect.removeListener(_onEffectChanged);
    for (final t in _remoteExpiry.values) {
      t.cancel();
    }
    await _listener?.dispose();
    await tracker.dispose();
    localFx.dispose();
    remoteFx.dispose();
    effect.dispose();
  }
}
