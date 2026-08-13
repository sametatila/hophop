import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:livekit_client/livekit_client.dart';
import 'face_tracker.dart';
import 'fx_frame.dart';

/// Efekt orkestrasyonu:
/// - yerel yüz izleme (FaceTracker) → yerel önizleme üstüne çizim
/// - yüz verisini LiveKit data channel'dan karşıya gönderme (topic: 'fx')
/// - karşıdan gelen 'fx' verisini uzak video üstüne çizim
///
/// Video karesine hiç dokunulmaz → E2EE bozulmaz, işlem maliyeti düşük.
class FxController {
  final Room room;
  final FaceTracker tracker;

  /// Yerel önizlemeye çizilecek kare (aynalı koordinatlarda).
  final localFx = ValueNotifier<FxFrame?>(null);

  /// Uzak videoya çizilecek kare (karşı tarafın yüzü + efekti).
  final remoteFx = ValueNotifier<FxFrame?>(null);

  final effect = ValueNotifier<String>('none');

  EventsListener<RoomEvent>? _listener;
  Timer? _remoteExpiry;

  FxController({required this.room, required GlobalKey localPreviewKey})
      : tracker = FaceTracker(previewKey: localPreviewKey) {
    tracker.onFace = _onLocalFace;
    effect.addListener(_onEffectChanged);
    _listener = room.createListener()
      ..on<DataReceivedEvent>((e) {
        if (e.topic != 'fx') return;
        final frame = FxFrame.decode(e.data);
        if (frame == null) return;
        remoteFx.value = frame.isOff ? null : frame;
        // Karşı taraf veri kesilirse eskimiş overlay asılı kalmasın.
        _remoteExpiry?.cancel();
        _remoteExpiry = Timer(const Duration(seconds: 2), () {
          remoteFx.value = null;
        });
      });
  }

  void _onEffectChanged() {
    tracker.effect = effect.value;
    if (effect.value == 'none') {
      tracker.stop();
      localFx.value = null;
      _publish(FxFrame.off); // karşıdaki overlay'i temizle
    } else {
      tracker.start();
    }
  }

  void _onLocalFace(FxFrame? frame) {
    // Yerel önizleme aynalı → çizim için geri aynala.
    localFx.value = frame?.mirrored();
    if (frame != null) _publish(frame);
  }

  void _publish(FxFrame frame) {
    // Güvenilmez (lossy) gönderim: canlı izleme verisi, kayıp kare önemsiz.
    room.localParticipant
        ?.publishData(Uint8List.fromList(frame.encode()),
            reliable: false, topic: 'fx')
        .catchError((_) {});
  }

  Future<void> dispose() async {
    effect.removeListener(_onEffectChanged);
    _remoteExpiry?.cancel();
    await _listener?.dispose();
    await tracker.dispose();
    localFx.dispose();
    remoteFx.dispose();
    effect.dispose();
  }
}
