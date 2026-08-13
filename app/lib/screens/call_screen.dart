import 'dart:async';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import '../effects/effect_painter.dart';
import '../effects/fx_controller.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/call_manager.dart';
import '../services/crypto_service.dart';
import '../widgets/avatar.dart';
import '../widgets/hop_ui.dart';

const int maxCallParticipants = 6;

/// Görüşme ekranı: 1:1'de tam ekran, grupta ızgara düzeni.
/// Davet (grup arama), efektler, kontroller — emojisiz, ikonlarla.
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
  List<UserProfile> _friends = [];

  @override
  void initState() {
    super.initState();
    _fx = FxController(room: widget.room, localPreviewKey: _localPreviewKey);
    _listener = widget.room.createListener()
      ..on<RoomDisconnectedEvent>((_) => _leave())
      ..on<ParticipantDisconnectedEvent>((_) {
        // Grup aramada biri ayrılınca ekran açık kalır; oda boşalınca kapanır.
        if (widget.room.remoteParticipants.isEmpty) {
          _leave();
        } else {
          setState(() {});
        }
      })
      ..on<ParticipantConnectedEvent>((_) => setState(() {}))
      ..on<TrackSubscribedEvent>((_) => setState(() {}))
      ..on<TrackUnsubscribedEvent>((_) => setState(() {}));
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
    AuthService.cachedFriends().then((f) => _friends = f);
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

  VideoTrack? _videoOf(Participant p) {
    for (final pub in p.videoTrackPublications) {
      final track = pub.track;
      if (track != null && !pub.muted) return track as VideoTrack;
    }
    return null;
  }

  VideoTrack? get _localVideo {
    final lp = widget.room.localParticipant;
    return lp == null ? null : _videoOf(lp);
  }

  String get _timer {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _title {
    final remotes = widget.room.remoteParticipants.values;
    if (remotes.length <= 1) return widget.peer.firstName;
    return '${remotes.length + 1} kişi';
  }

  // ---- Davet (grup arama) ----

  Future<void> _openInviteSheet() async {
    final active = CallManager.activeCall;
    if (active == null) return;
    final inCallIds = {
      ...widget.room.remoteParticipants.values.map((p) => p.identity),
      auth.me?.id,
    };
    final candidates = _friends
        .where((f) => !inCallIds.contains(f.id) && (f.publicKey ?? '').isNotEmpty)
        .toList();
    final slots =
        maxCallParticipants - (widget.room.remoteParticipants.length + 1);

    if (candidates.isEmpty || slots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(slots <= 0
              ? 'Arama dolu (en fazla $maxCallParticipants kişi)'
              : 'Davet edilecek başka arkadaş yok')));
      return;
    }

    final selected = <String>{};
    final invited = await showModalBottomSheet<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.group_add),
                    const SizedBox(width: 8),
                    Text('Aramaya davet et ($slots kişilik yer var)',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final f in candidates)
                      CheckboxListTile(
                        value: selected.contains(f.id),
                        onChanged: (v) => setSheetState(() {
                          if (v == true) {
                            if (selected.length < slots) selected.add(f.id);
                          } else {
                            selected.remove(f.id);
                          }
                        }),
                        secondary: Avatar(user: f, radius: 20),
                        title: Text(f.fullName),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.pop(context, selected),
                  icon: const Icon(Icons.ring_volume),
                  label: Text('Davet et (${selected.length})'),
                  style:
                      FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (invited == null || invited.isEmpty) return;
    for (final id in invited) {
      final friend = _friends.firstWhere((f) => f.id == id);
      try {
        final wrapped = await crypto.wrapRoomKey(
            friend.publicKey!, 'call', active.roomKeyB64);
        await api.inviteToCall(active.roomName, id, active.video, wrapped);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${friend.firstName} davet edilemedi')));
        }
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${invited.length} kişi aranıyor — katıldıklarında görünecekler')));
    }
  }

  // ---- Görünüm ----

  @override
  Widget build(BuildContext context) {
    final remotes = widget.room.remoteParticipants.values.toList()
      ..sort((a, b) => a.identity.compareTo(b.identity));
    final local = _localVideo;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ---- Uzak katılımcılar ----
            if (remotes.isEmpty)
              _connectingView()
            else if (remotes.length == 1)
              _remoteTile(remotes.first, fullscreen: true)
            else
              GridView.count(
                crossAxisCount: 2,
                childAspectRatio:
                    MediaQuery.of(context).size.aspectRatio * (remotes.length <= 2 ? 0.5 : 1),
                children: [for (final p in remotes) _remoteTile(p)],
              ),

            // ---- Üst bilgi ----
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: GlassPanel(
                    radius: 20,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock,
                            color: Colors.greenAccent, size: 16),
                        const SizedBox(width: 6),
                        Text('$_title · $_timer',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ---- Yerel önizleme ----
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
                  margin: const EdgeInsets.only(bottom: 112),
                  child: GlassPanel(
                    radius: 20,
                    padding: const EdgeInsets.all(8),
                    tint: Colors.black38,
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
                                  EffectThumb(effectId: e.id, size: 36),
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
              ),

            // ---- Kontroller: cam panel üzerinde degrade butonlar ----
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: GlassPanel(
                    radius: 32,
                    tint: Colors.black26,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
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
                          Icons.person_add,
                          Colors.white24,
                          _openInviteSheet,
                        ),
                        _controlButton(
                          Icons.auto_awesome,
                          _showEffects ? Colors.purple : Colors.white24,
                          () => setState(() => _showEffects = !_showEffects),
                        ),
                        const SizedBox(width: 4),
                        GradientOrb(
                          icon: Icons.call_end,
                          size: 58,
                          colors: const [Color(0xFFE85D5D), Color(0xFFC62839)],
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _connectingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Avatar(user: widget.peer, radius: 64),
          const SizedBox(height: 16),
          Text(widget.peer.fullName,
              style: const TextStyle(color: Colors.white, fontSize: 24)),
          const SizedBox(height: 8),
          const Text('Bağlanıyor…', style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _remoteTile(RemoteParticipant p, {bool fullscreen = false}) {
    final video = _videoOf(p);
    final friend = _friends.where((f) => f.id == p.identity).firstOrNull;
    final content = video != null
        ? ValueListenableBuilder(
            valueListenable: _fx.remoteFx,
            builder: (context, map, _) => CustomPaint(
              foregroundPainter: EffectPainter(map[p.identity]),
              child: VideoTrackRenderer(video),
            ),
          )
        : Center(
            child: friend != null
                ? Avatar(user: friend, radius: fullscreen ? 64 : 36)
                : CircleAvatar(
                    radius: fullscreen ? 64 : 36,
                    child: Text(p.name.isNotEmpty ? p.name[0] : '?')),
          );
    if (fullscreen) return content;
    return Container(
      margin: const EdgeInsets.all(2),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(8), child: content),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(p.name.split(' ').first,
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlButton(IconData icon, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Pressable(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          child: Icon(icon, color: Colors.white, size: 25),
        ),
      ),
    );
  }
}
