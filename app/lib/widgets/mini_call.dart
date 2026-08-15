import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../services/call_manager.dart';
import '../services/pip_service.dart';
import 'avatar.dart';

/// Uygulamanın üstünde yüzen küçük görüşme penceresi (WhatsApp davranışı).
///
/// NEDEN VAR: eskiden küçültmek sistemin Picture-in-Picture kipine geçiriyordu;
/// o kip uygulamanın TAMAMINI arka plana alır, yani görüşürken sohbetlere ya da
/// kişilere bakmak mümkün olmuyordu. Bu pencere Navigator'ın overlay'ine
/// eklendiği için uygulamanın içinde kalır: kullanıcı gezinirken görüşme köşede
/// sürer, dokununca tam ekrana döner.
///
/// Sistem PiP'i kaldırılmadı: kullanıcı ev tuşuyla uygulamadan TAMAMEN çıkarsa
/// hâlâ devreye giriyor. O anda bu pencere tüm ekrana yayılır ([PipService.inPip]),
/// çünkü küçük pencere sistemin küçülttüğü karede okunmaz bir noktaya dönerdi.
class MiniCallWindow extends StatefulWidget {
  final MinimizedCall call;
  const MiniCallWindow({super.key, required this.call});

  @override
  State<MiniCallWindow> createState() => _MiniCallWindowState();
}

class _MiniCallWindowState extends State<MiniCallWindow> {
  static const _width = 132.0;
  static const _margin = 12.0;

  /// Sol üst köşenin konumu. null → ilk karede sağ üste yerleştirilir.
  Offset? _pos;
  Timer? _clock;
  EventsListener<RoomEvent>? _listener;

  double get _height => widget.call.video ? 186 : 132;

  @override
  void initState() {
    super.initState();
    // Süre yazısı için: saniyede bir yeniden çiz.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    PipService.inPip.addListener(_onPipChanged);
    // Küçük pencerede de görüşmenin bittiğini fark etmeliyiz — tam ekrandaki
    // ayrıntılı toparlanma mantığı burada yok, kopan bağlantı görüşmeyi kapatır.
    _listener = widget.call.room.createListener()
      ..on<RoomDisconnectedEvent>((e) {
        CallManager.endMinimized(
            dropped: e.reason != DisconnectReason.clientInitiated);
      })
      ..on<ParticipantDisconnectedEvent>((_) {
        if (widget.call.room.remoteParticipants.isEmpty) {
          CallManager.endMinimized();
        } else if (mounted) {
          setState(() {});
        }
      })
      ..on<TrackSubscribedEvent>((_) {
        if (mounted) setState(() {});
      })
      ..on<TrackUnsubscribedEvent>((_) {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _clock?.cancel();
    PipService.inPip.removeListener(_onPipChanged);
    _listener?.dispose();
    super.dispose();
  }

  void _onPipChanged() {
    if (mounted) setState(() {});
  }

  /// Karşı taraftan gelen ilk açık görüntü (yoksa avatar gösterilir).
  VideoTrack? get _remoteVideo {
    for (final p in widget.call.room.remoteParticipants.values) {
      for (final pub in p.videoTrackPublications) {
        final track = pub.track;
        if (track != null && !pub.muted) return track as VideoTrack;
      }
    }
    return null;
  }

  String get _timer {
    final e = widget.call.elapsed;
    final m = e.inMinutes.toString().padLeft(2, '0');
    final s = (e.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Pencereyi ekranın içinde tutar: sürükleyip kenardan taşırmak mümkün olmasın.
  Offset _clamp(Offset p, Size screen, EdgeInsets safe) {
    return Offset(
      p.dx.clamp(_margin, screen.width - _width - _margin),
      p.dy.clamp(
          safe.top + _margin, screen.height - _height - safe.bottom - _margin),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    // Sistem PiP'indeyken pencere tüm kareyi kaplar — o karede görüşmeden
    // başka bir şey görünmesinin anlamı yok.
    if (PipService.inPip.value) {
      return Positioned.fill(
        child: Container(color: Colors.black, child: _videoOrAvatar()),
      );
    }

    final screen = media.size;
    final safe = media.padding;
    final pos = _clamp(
      _pos ?? Offset(screen.width - _width - _margin, safe.top + _margin),
      screen,
      safe,
    );

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      width: _width,
      height: _height,
      child: GestureDetector(
        onTap: CallManager.restoreMinimized,
        onPanUpdate: (d) => setState(
            () => _pos = _clamp(pos + d.delta, screen, safe)),
        child: Material(
          color: Colors.transparent,
          elevation: 12,
          borderRadius: BorderRadius.circular(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _videoOrAvatar(),
                  // Üstte süre, altta kapat — ikisi de okunabilsin diye
                  // görüntünün üzerine hafif bir karartma konur.
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      color: Colors.black38,
                      child: Text(
                        _timer,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: GestureDetector(
                        // Kapatma dokunuşu pencereyi büyütmesin.
                        onTap: () => CallManager.endMinimized(),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD64550),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.call_end,
                              color: Colors.white, size: 19),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _videoOrAvatar() {
    final track = _remoteVideo;
    if (track != null) {
      // Küçük karede "contain" yanlarda siyah bant bırakıyor — pencere dolsun.
      return VideoTrackRenderer(track, fit: VideoViewFit.cover);
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Avatar(user: widget.call.peer, radius: 26),
          const SizedBox(height: 6),
          Text(
            widget.call.peer.firstName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
