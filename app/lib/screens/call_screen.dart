import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../effects/effect_painter.dart';
import '../effects/fx_controller.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/call_manager.dart';
import '../services/crypto_service.dart';
import '../services/pip_service.dart';
import '../services/update_service.dart';
import '../widgets/avatar.dart';
import '../widgets/hop_ui.dart';

const int maxCallParticipants = 6;

/// Görüşme ekranı: 1:1'de tam ekran, grupta ızgara düzeni.
/// Davet (grup arama), efektler, kontroller — emojisiz, ikonlarla.
class CallScreen extends StatefulWidget {
  final Room room;
  final UserProfile peer;
  final bool videoCall;
  final String roomName;

  /// Kopan bağlantıyı ekranı kapatmadan yeniden kurabilmek için saklanır.
  final String livekitUrl;
  final String livekitToken;

  /// Küçük pencereden dönülüyorsa oradaki durum (süre, mikrofon/kamera/hoparlör).
  /// null → görüşme yeni başlıyor.
  final MinimizedCall? resume;

  const CallScreen({
    super.key,
    required this.room,
    required this.peer,
    required this.videoCall,
    required this.roomName,
    required this.livekitUrl,
    required this.livekitToken,
    this.resume,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with SingleTickerProviderStateMixin {
  final _localPreviewKey = GlobalKey();
  late final FxController _fx;

  /// Animasyonlu efektlerin saati (saniye). Yalnızca animasyonlu bir efekt
  /// görünürken repaint kaynağı olarak bağlanır — statikte 60fps çizim olmaz.
  final _fxClock = ValueNotifier<double>(0);
  Ticker? _fxTicker;
  String _fxCat = 'animal';
  EventsListener<RoomEvent>? _listener;
  late bool _micOn = widget.resume?.micOn ?? true;
  late bool _camOn = widget.resume?.camOn ?? widget.videoCall;
  // Görüntülüde hoparlör varsayılan açık.
  late bool _speakerOn = widget.resume?.speakerOn ?? widget.videoCall;
  bool _showEffects = false;

  /// Görüşmenin gerçek başlangıcı — küçültüp büyütmek sayacı sıfırlamasın.
  late final DateTime _startedAt = widget.resume?.startedAt ?? DateTime.now();

  /// Ekran küçük pencereye devrediliyor: görüşme BİTMİYOR, bu yüzden
  /// dispose'da oda kapatılmaz ve süre sunucuya işlenmez.
  bool _toMini = false;
  bool _reconnecting = false; // zayıf bağlantı: "Yeniden bağlanıyor…" durumu
  bool _peerLost = false; // karşı tarafın bağlantısı gitti (biz iyiyiz)
  bool _recovering = false; // kendi yeniden bağlanma döngümüz sürüyor
  Timer? _clock;
  Timer? _reconnectWatchdog;
  Timer? _peerLostTimer;
  Timer? _emptyRoomGuard;
  List<UserProfile> _friends = [];

  /// Kopan bağlantıyı toparlamak için tanınan süre. Bu sürede ekran açık kalır,
  /// kullanıcı WiFi'ı geri açarsa görüşme kaldığı yerden devam eder.
  static const _recoveryWindow = Duration(seconds: 30);

  /// Karşı taraftan ses/görüntü gelmemeye başladıktan sonra beklenecek süre.
  /// LiveKit sunucusunun kendi zaman aşımı ~45 sn; o kadar beklenirse kullanıcı
  /// donmuş bir görüntüye "görüşme sürüyor" sanarak bakıyor.
  static const _peerLostWindow = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    _fx = FxController(room: widget.room, localPreviewKey: _localPreviewKey);
    _listener = widget.room.createListener()
      // Kopuş: sebebi ağ ise EKRANI KAPATMA — kullanıcıya toparlanma penceresi
      // tanı ve arka planda yeniden bağlanmayı dene. (Önceden her kopuşta anında
      // kapanıyordu: WiFi kapanır kapanmaz görüşme uyarısız bitiyordu.)
      ..on<RoomDisconnectedEvent>((e) {
        // Bunlar "ağ gitti" anlamına gelen, sunucudan değil istemciden doğan
        // sebepler (livekit_client 2.11 DisconnectReason).
        const networkReasons = {
          DisconnectReason.disconnected,
          DisconnectReason.signalingConnectionFailure,
          DisconnectReason.signalClose,
          DisconnectReason.reconnectAttemptsExceeded,
          DisconnectReason.stateMismatch,
          DisconnectReason.unknown,
        };
        if (e.reason == null || networkReasons.contains(e.reason)) {
          _beginRecovery();
        } else {
          // Karşı taraf kapattı, sunucu odayı sildi vb. → gerçekten bitti.
          _leave(dropped: e.reason != DisconnectReason.clientInitiated);
        }
      })
      // Karşı tarafın bağlantısı gitti mi? Sunucunun katılımcıyı düşürmesini
      // (~45 sn) beklemeden bağlantı kalitesinden anlıyoruz.
      ..on<ParticipantConnectionQualityUpdatedEvent>((e) {
        if (e.participant is! RemoteParticipant) return;
        if (e.connectionQuality == ConnectionQuality.lost) {
          if (_peerLostTimer?.isActive ?? false) return;
          if (mounted) setState(() => _peerLost = true);
          _peerLostTimer = Timer(_peerLostWindow, () {
            if (mounted && _peerLost) _leave(dropped: true);
          });
        } else {
          _peerLostTimer?.cancel();
          if (_peerLost && mounted) setState(() => _peerLost = false);
        }
      })
      // Zayıf bağlantı yönetimi (WhatsApp davranışı): SDK kendiliğinden
      // yeniden bağlanmayı dener; biz durumu gösterir ve 30 sn'de toparlanmazsa
      // görüşmeyi düzgünce kapatırız.
      ..on<RoomReconnectingEvent>((_) {
        if (!mounted) return;
        setState(() => _reconnecting = true);
        _reconnectWatchdog?.cancel();
        _reconnectWatchdog = Timer(const Duration(seconds: 30), () {
          if (mounted && _reconnecting) _leave(dropped: true);
        });
      })
      ..on<RoomReconnectedEvent>((_) {
        _reconnectWatchdog?.cancel();
        if (mounted) setState(() => _reconnecting = false);
      })
      ..on<ParticipantDisconnectedEvent>((_) {
        // Grup aramada biri ayrılınca ekran açık kalır; oda boşalınca kapanır.
        if (widget.room.remoteParticipants.isEmpty) {
          _leave();
        } else {
          setState(() {});
        }
      })
      ..on<ParticipantConnectedEvent>((e) {
        _emptyRoomGuard?.cancel();
        setState(() {});
        // Grup arama: davet edilen katılınca herkes görsün.
        if (widget.room.remoteParticipants.length > 1 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${e.participant.name.split(' ').first} katıldı'),
            duration: const Duration(seconds: 2),
          ));
        }
      })
      ..on<TrackSubscribedEvent>((_) => setState(() {}))
      ..on<TrackUnsubscribedEvent>((_) => setState(() {}));
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    // Boş oda korunağı: karşı taraf hiç gelmezse (iptal/kopuş yarışları)
    // "Bağlanıyor"da takılı kalmak yerine kapat ve yeniden aramayı öner.
    _emptyRoomGuard = Timer(const Duration(seconds: 15), () {
      if (mounted && widget.room.remoteParticipants.isEmpty) {
        _leave(dropped: true);
      }
    });
    AuthService.cachedFriends().then((f) => _friends = f);
    _fxTicker = createTicker(
        (elapsed) => _fxClock.value = elapsed.inMilliseconds / 1000)
      ..start();
    WakelockPlus.enable(); // görüşme boyunca ekran kararmasın/kilitlenmesin
    // Kulaklık/Bluetooth takılıysa o öncelikli kalır (force verilmiyor) —
    // kulaklıkla konuşurken sesin hoparlöre kaçmaması için istenen davranış.
    AudioManager.instance.setSpeakerOutputPreferred(_speakerOn);
    _applyProximity();
    // Görüşme boyunca ev tuşu uygulamayı kapatmasın, sistem küçük penceresine
    // geçirsin. Görüşme gerçekten bitince kapatılır (dispose).
    PipService.setEligible(true);
    PipService.inPip.addListener(_onPipChanged);
  }

  /// Ahizeye alındıysa (hoparlör kapalı) yakınlık sensörü devrede: telefon
  /// kulağa götürülünce ekran kapanır. Görüntülüde/hoparlörde kapalı —
  /// yoksa ekran karşındakini izlerken sönerdi.
  void _applyProximity() => UpdateService.setProximity(!_speakerOn);

  void _onPipChanged() {
    if (mounted) setState(() {});
  }

  /// Küçült: görüşme UYGULAMANIN İÇİNDE köşede yüzen pencereye devredilir,
  /// kullanıcı sohbetlerde/kişilerde gezinmeye devam edebilir.
  ///
  /// Eskiden burada sistem PiP'ine geçiliyordu; o kip uygulamayı tamamen arka
  /// plana aldığı için "küçült" pratikte "uygulamadan çık" demek oluyordu.
  /// Sistem PiP'i yerinde duruyor ama artık yalnızca kullanıcı ev tuşuyla
  /// uygulamadan çıkınca devreye giriyor (native onUserLeaveHint).
  void _minimize() {
    if (_toMini || !mounted) return;
    _toMini = true;
    Navigator.of(context).pop(MinimizedCall(
      room: widget.room,
      peer: widget.peer,
      video: widget.videoCall,
      roomName: widget.roomName,
      livekitUrl: widget.livekitUrl,
      livekitToken: widget.livekitToken,
      startedAt: _startedAt,
      micOn: _micOn,
      camOn: _camOn,
      speakerOn: _speakerOn,
    ));
  }

  /// Ağ koptuğunda: ekranı açık tut, "Yeniden bağlanıyor…" göster ve
  /// [_recoveryWindow] boyunca odaya yeniden katılmayı dene. Kullanıcı bu
  /// sürede WiFi'ı geri açarsa görüşme kaldığı yerden sürer.
  Future<void> _beginRecovery() async {
    if (_recovering || !mounted) return;
    _recovering = true;
    setState(() => _reconnecting = true);

    final deadline = DateTime.now().add(_recoveryWindow);
    while (mounted && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 3));
      if (!mounted) break;
      try {
        await widget.room.connect(widget.livekitUrl, widget.livekitToken);
        // Yeni oturumda yayınlar sıfırlanır; mikrofon/kamera geri açılır.
        await widget.room.localParticipant?.setMicrophoneEnabled(_micOn);
        if (widget.videoCall) {
          await widget.room.localParticipant?.setCameraEnabled(_camOn);
        }
        if (!mounted) break;
        _recovering = false;
        setState(() => _reconnecting = false);
        return;
      } catch (_) {
        // Ağ hâlâ yok — süre dolana kadar denemeye devam.
      }
    }
    _recovering = false;
    _leave(dropped: true);
  }

  void _leave({bool dropped = false}) {
    _peerLostTimer?.cancel();
    _reconnectWatchdog?.cancel();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(dropped ? 'dropped' : null);
    }
  }

  @override
  void dispose() {
    // Ekrana ait olanlar her hâlükârda bırakılır; küçük pencereye geçerken
    // bunlar yeniden kurulacak (efekt denetleyicisi, dinleyici, sayaçlar).
    PipService.inPip.removeListener(_onPipChanged);
    _clock?.cancel();
    _reconnectWatchdog?.cancel();
    _peerLostTimer?.cancel();
    _emptyRoomGuard?.cancel();
    _fxTicker?.dispose();
    _fxClock.dispose();
    _listener?.dispose();
    _fx.dispose();
    // Görüşmeye ait olanlar YALNIZCA gerçekten bittiğinde bırakılır. Küçük
    // pencereye geçiyorsak oda bağlı kalmalı; onu CallManager kapatacak.
    if (!_toMini) {
      WakelockPlus.disable();
      UpdateService.setProximity(false);
      PipService.setEligible(false);
      widget.room.disconnect();
      widget.room.dispose();
      // Görüşme süresi sohbet akışındaki arama kaydına işlensin.
      if (_elapsed.inSeconds > 0) {
        api.callEnded(widget.roomName, _elapsed.inSeconds).catchError((_) {});
      }
    } else {
      // Küçük pencerede ekran kapalı değil ama kullanıcı gezmeye devam ediyor —
      // yakınlık sensörü ekranı karartmamalı.
      UpdateService.setProximity(false);
    }
    super.dispose();
  }

  VideoTrack? _videoOf(Participant p) {
    for (final pub in p.videoTrackPublications) {
      final track = pub.track;
      if (track != null && !pub.muted) return track as VideoTrack;
    }
    return null;
  }

  Widget _fxCatChip({
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: selected ? Colors.white24 : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  VideoTrack? get _localVideo {
    final lp = widget.room.localParticipant;
    return lp == null ? null : _videoOf(lp);
  }

  Duration get _elapsed => DateTime.now().difference(_startedAt);

  String get _timer {
    final e = _elapsed;
    final m = e.inMinutes.toString().padLeft(2, '0');
    final s = (e.inSeconds % 60).toString().padLeft(2, '0');
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
        .where(
            (f) => !inCallIds.contains(f.id) && (f.publicKey ?? '').isNotEmpty)
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
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
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
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${friend.firstName} davet edilemedi')));
        }
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${invited.length} kişi aranıyor — katıldıklarında görünecekler')));
    }
  }

  // ---- Görünüm ----

  @override
  Widget build(BuildContext context) {
    final remotes = widget.room.remoteParticipants.values.toList()
      ..sort((a, b) => a.identity.compareTo(b.identity));
    final local = _localVideo;

    // Küçük pencerede yalnızca görüntü/avatar kalır: kontroller, üst bilgi ve
    // efekt paneli gizlenir — o boyutta hepsi okunmaz bir yığına dönüyor.
    final pip = PipService.inPip.value;

    return PopScope(
      // Geri tuşu görüşmeyi BİTİRMEZ; WhatsApp gibi uygulama içi küçük
      // pencereye geçer. Kapatmak kırmızı düğmede.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _minimize();
      },
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
                childAspectRatio: MediaQuery.of(context).size.aspectRatio *
                    (remotes.length <= 2 ? 0.5 : 1),
                children: [for (final p in remotes) _remoteTile(p)],
              ),

            // ---- Küçült (sol üst) ----
            // Geri tuşunun görsel karşılığı: aramayı kapatmadan uygulama içi
            // küçük pencereye geçirir. Sistem PiP'ine bağlı olmadığı için her
            // cihazda çalışır.
            if (!pip)
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 8),
                    child: Pressable(
                      onTap: _minimize,
                      child: GlassPanel(
                        radius: 18,
                        tint: Colors.black26,
                        padding: const EdgeInsets.all(9),
                        child: const Icon(Icons.picture_in_picture_alt,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ),
              ),

            // ---- Üst bilgi ----
            if (!pip)
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
                          Icon(
                            _reconnecting || _peerLost
                                ? Icons.wifi_off
                                : Icons.lock,
                            color: _reconnecting || _peerLost
                                ? Colors.orangeAccent
                                : Colors.greenAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _reconnecting
                                ? 'Yeniden bağlanıyor…'
                                : _peerLost
                                    ? '${widget.peer.firstName} bağlantısını kaybetti…'
                                    : '$_title · $_timer',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                          ),
                          if (_reconnecting || _peerLost) ...[
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white70),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ---- Yerel önizleme (dokun: kamera değiştir) ----
            if (local != null && _camOn && !pip)
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () => _switchCamera(local),
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      width: 110,
                      height: 150,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            RepaintBoundary(
                              key: _localPreviewKey,
                              child: ValueListenableBuilder(
                                valueListenable: _fx.localFx,
                                builder: (context, localFrame, _) =>
                                    CustomPaint(
                                  foregroundPainter: EffectPainter(localFrame,
                                      smoother: _fx.localSmooth,
                                      clock:
                                          localFrame == null ? null : _fxClock),
                                  child: VideoTrackRenderer(local),
                                ),
                              ),
                            ),
                            const Positioned(
                              right: 6,
                              bottom: 6,
                              child: Icon(Icons.cameraswitch,
                                  color: Colors.white70, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ---- Alt katman: efekt seçici + kontroller ----
            if (!pip)
              // Tek bir kolonda ve tek SafeArea içinde duruyorlar: efekt paneli
              // her cihazda kontrollerin TAM ÜSTÜNDE açılır. (Önceden ayrı
              // Align'lardı; sabit 112 px pay jest çubuğu olan telefonlarda
              // yetmiyor, üstelik kontroller sonra çizildiği için paneli
              // örtüyordu.)
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_showEffects)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          constraints: BoxConstraints(
                              maxWidth: (MediaQuery.sizeOf(context).width - 24)
                                  .clamp(0.0, 460.0)),
                          child: GlassPanel(
                            radius: 20,
                            padding: const EdgeInsets.all(8),
                            tint: Colors.black38,
                            child: ValueListenableBuilder(
                              valueListenable: _fx.effect,
                              builder: (context, current, _) => Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Kapat: efekt yok
                                      _fxCatChip(
                                        selected: current == 'none',
                                        icon: Icons.block,
                                        label: 'Yok',
                                        onTap: () => _fx.effect.value = 'none',
                                      ),
                                      for (final cat in fxCategories)
                                        _fxCatChip(
                                          selected: _fxCat == cat.id,
                                          icon: cat.icon,
                                          label: cat.label,
                                          onTap: () =>
                                              setState(() => _fxCat = cat.id),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 68,
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      children: [
                                        for (final e in fxCategories
                                            .firstWhere((c) => c.id == _fxCat)
                                            .effects)
                                          Pressable(
                                            onTap: () =>
                                                _fx.effect.value = e.id,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 3),
                                              decoration: BoxDecoration(
                                                color: current == e.id
                                                    ? Colors.white24
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  EffectThumb(
                                                      effectId: e.id, size: 40),
                                                  const SizedBox(height: 2),
                                                  Text(e.label,
                                                      style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 11)),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // ---- Kontroller: cam panel üzerinde degrade butonlar ----
                      Padding(
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
                                // İkon HEP hoparlör: düğme "hoparlör" düğmesi,
                                // açık/kapalı olduğunu zemin rengi anlatıyor —
                                // diğer düğmeler (mikrofon, kamera) de böyle.
                                // Ahize ikonuna dönüşünce "şimdi hangisi açık?"
                                // sorusu doğuyordu.
                                Icons.volume_up,
                                _speakerOn ? Colors.white38 : Colors.white24,
                                () async {
                                  _speakerOn = !_speakerOn;
                                  _applyProximity();
                                  await AudioManager.instance
                                      .setSpeakerOutputPreferred(_speakerOn);
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
                                () => setState(
                                    () => _showEffects = !_showEffects),
                              ),
                              const SizedBox(width: 4),
                              GradientOrb(
                                icon: Icons.call_end,
                                size: 58,
                                colors: const [
                                  Color(0xFFE85D5D),
                                  Color(0xFFC62839)
                                ],
                                onTap: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
              foregroundPainter: EffectPainter(map[p.identity],
                  smoother: _fx.remoteSmoother(p.identity),
                  clock: map[p.identity] == null ? null : _fxClock),
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

  Future<void> _switchCamera(VideoTrack local) async {
    if (local is! LocalVideoTrack) return;
    try {
      final options = local.currentOptions;
      if (options is CameraCaptureOptions) {
        await local.setCameraPosition(
          options.cameraPosition == CameraPosition.front
              ? CameraPosition.back
              : CameraPosition.front,
        );
      }
    } catch (_) {}
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
