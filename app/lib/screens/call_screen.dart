import 'dart:async';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import '../effects/effect_painter.dart';
import '../effects/fx_controller.dart';
import '../models/models.dart';
import '../widgets/avatar.dart';

/// Görüşme ekranı: uzak video (tam ekran) + yerel önizleme (köşe) +
/// kontroller + efekt şeridi. Efekt overlay'leri hem yerelde hem uzakta çizilir.
class CallScreen extends StatefulWidget {
  final Room room;
  final UserProfile peer;
  final bool videoCall;

  const CallScreen({
    super.key,
    required this.room,
    required this.peer,
    required this.videoCall,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _localPreviewKey = GlobalKey();
  late final FxController _fx;
  EventsListener<RoomEvent>? _listener;
  bool _micOn = true;
  late bool _camOn = widget.videoCall;
  bool _showEffects = false;
  Duration _elapsed = Duration.zero;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _fx = FxController(room: widget.room, localPreviewKey: _localPreviewKey);
    _listener = widget.room.createListener()
      ..on<RoomDisconnectedEvent>((_) => _leave())
      ..on<ParticipantDisconnectedEvent>((_) => _leave())
      ..on<TrackSubscribedEvent>((_) => setState(() {}))
      ..on<TrackUnsubscribedEvent>((_) => setState(() {}));
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  void _leave() {
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _listener?.dispose();
    _fx.dispose();
    widget.room.disconnect();
    widget.room.dispose();
    super.dispose();
  }

  VideoTrack? get _remoteVideo {
    for (final p in widget.room.remoteParticipants.values) {
      for (final pub in p.videoTrackPublications) {
        final track = pub.track;
        if (track != null && !pub.muted) return track;
      }
    }
    return null;
  }

  VideoTrack? get _localVideo {
    final lp = widget.room.localParticipant;
    if (lp == null) return null;
    for (final pub in lp.videoTrackPublications) {
      final track = pub.track;
      if (track != null && !pub.muted) return track;
    }
    return null;
  }

  String get _timer {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final remote = _remoteVideo;
    final local = _localVideo;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ---- Uzak video + karşı tarafın efekti ----
            if (remote != null)
              ValueListenableBuilder(
                valueListenable: _fx.remoteFx,
                builder: (context, remoteFrame, _) => CustomPaint(
                  foregroundPainter: EffectPainter(remoteFrame),
                  child: VideoTrackRenderer(remote),
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Avatar(user: widget.peer, radius: 64),
                    const SizedBox(height: 16),
                    Text(widget.peer.fullName,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 24)),
                    const SizedBox(height: 8),
                    const Text('Bağlanıyor…',
                        style: TextStyle(color: Colors.white54)),
                  ],
                ),
              ),

            // ---- Üst bilgi ----
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '🔒 ${widget.peer.firstName} · $_timer',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),

            // ---- Yerel önizleme (efekt yakalama için RepaintBoundary) ----
            if (local != null && _camOn)
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    width: 110,
                    height: 150,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: RepaintBoundary(
                        key: _localPreviewKey,
                        child: ValueListenableBuilder(
                          valueListenable: _fx.localFx,
                          builder: (context, localFrame, _) => CustomPaint(
                            foregroundPainter: EffectPainter(localFrame),
                            child: VideoTrackRenderer(local),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ---- Efekt şeridi ----
            if (_showEffects)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 108),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ValueListenableBuilder(
                    valueListenable: _fx.effect,
                    builder: (context, current, _) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final e in effectCatalog)
                          GestureDetector(
                            onTap: () => _fx.effect.value = e.id,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: current == e.id
                                    ? Colors.white24
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(e.emoji,
                                      style: const TextStyle(fontSize: 28)),
                                  Text(e.label,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

            // ---- Kontroller ----
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _controlButton(
                        _micOn ? Icons.mic : Icons.mic_off,
                        _micOn ? Colors.white24 : Colors.orange,
                        () async {
                          _micOn = !_micOn;
                          await widget.room.localParticipant
                              ?.setMicrophoneEnabled(_micOn);
                          setState(() {});
                        },
                      ),
                      _controlButton(
                        _camOn ? Icons.videocam : Icons.videocam_off,
                        _camOn ? Colors.white24 : Colors.orange,
                        () async {
                          _camOn = !_camOn;
                          await widget.room.localParticipant
                              ?.setCameraEnabled(_camOn);
                          setState(() {});
                        },
                      ),
                      _controlButton(
                        Icons.cameraswitch,
                        Colors.white24,
                        () async {
                          final track = _localVideo;
                          if (track is LocalVideoTrack) {
                            try {
                              final options = track.currentOptions;
                              if (options is CameraCaptureOptions) {
                                await track.setCameraPosition(
                                  options.cameraPosition == CameraPosition.front
                                      ? CameraPosition.back
                                      : CameraPosition.front,
                                );
                              }
                            } catch (_) {}
                          }
                        },
                      ),
                      _controlButton(
                        Icons.auto_awesome,
                        _showEffects ? Colors.purple : Colors.white24,
                        () => setState(() => _showEffects = !_showEffects),
                      ),
                      _controlButton(
                        Icons.call_end,
                        Colors.red,
                        () => Navigator.of(context).pop(),
                        large: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlButton(IconData icon, Color color, VoidCallback onTap,
      {bool large = false}) {
    return FloatingActionButton(
      heroTag: icon.codePoint,
      backgroundColor: color,
      onPressed: onTap,
      child: Icon(icon, color: Colors.white, size: large ? 32 : 26),
    );
  }
}
