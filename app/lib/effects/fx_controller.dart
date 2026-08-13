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

  /// Uzak videolara çizilecek kareler — katılımcı kimliğine göre
  /// (grup aramada her kişinin kendi efekti kendi karosuna çizilir).
  final remoteFx = ValueNotifier<Map<String, FxFrame>>({});

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
        } else {
          map[identity] = frame;
        }
        remoteFx.value = map;
        // Veri kesilirse eskimiş overlay asılı kalmasın.
        _remoteExpiry[identity]?.cancel();
        _remoteExpiry[identity] = Timer(const Duration(seconds: 2), () {
          final m = Map<String, FxFrame>.from(remoteFx.value)..remove(identity);
          remoteFx.value = m;
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
