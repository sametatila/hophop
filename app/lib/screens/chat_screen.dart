import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import '../theme/hop_theme.dart';
import '../services/activity_store.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/call_manager.dart';
import '../services/crypto_service.dart';
import '../services/fcm_service.dart';
import '../widgets/avatar.dart';

/// Uçtan uca şifreli birebir sohbet.
/// Sunucuda yalnızca şifreli blob durur; çözme/şifreleme cihazda yapılır.
class ChatScreen extends StatefulWidget {
  final UserProfile friend;
  const ChatScreen({super.key, required this.friend});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messages = <ChatMessage>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  StreamSubscription? _sub;
  StreamSubscription? _typingSub;
  Timer? _poll;
  Timer? _typingExpiry;
  bool _sending = false;
  bool _loading = true; // ilk ağ yüklemesi bitene dek (önbellek varsa anında biter)
  bool _peerTyping = false;
  int _lastMs = 0;
  int _lastTypingSentMs = 0;

  // ---- Yerel sohbet önbelleği: açılışta son konuşma ANINDA görünür ----

  Future<File> _cacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/chat_${widget.friend.id}.json');
  }

  Future<void> _loadCache() async {
    try {
      final f = await _cacheFile();
      if (!await f.exists()) return;
      final list = jsonDecode(await f.readAsString()) as List;
      final cached = list
          .map((m) => ChatMessage(
                id: m['id'] as String,
                fromUserId: m['from'] as String,
                text: m['text'] as String,
                sentAtMs: (m['at'] as num).toInt(),
                deliveredAtMs: (m['dlv'] as num?)?.toInt(),
                kind: (m['k'] as String?) ?? 'msg',
                callType: m['ct'] as String?,
                outcome: m['o'] as String?,
                durationSec: (m['d'] as num?)?.toInt(),
              ))
          .toList();
      if (cached.isNotEmpty && mounted && _messages.isEmpty) {
        setState(() {
          _messages.addAll(cached);
          _loading = false; // önbellek geldi — iskelet yerine gerçek içerik
        });
        _scrollToEnd();
      }
    } catch (_) {}
  }

  Future<void> _saveCache() async {
    try {
      final f = await _cacheFile();
      final data = _messages
          .where((m) => !m.pending)
          .map((m) => {
                'id': m.id,
                'from': m.fromUserId,
                'text': m.text,
                'at': m.sentAtMs,
                'dlv': m.deliveredAtMs,
                'k': m.kind,
                'ct': m.callType,
                'o': m.outcome,
                'd': m.durationSec,
              })
          .toList();
      await f.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  String get _pairContext {
    final ids = [auth.me!.id, widget.friend.id]..sort();
    return ids.join('_');
  }

  @override
  void initState() {
    super.initState();
    _loadCache().then((_) => _load());
    // Uygulama açıkken gelen mesajlar FCM ile anında düşer; push kaçarsa
    // hafif bir tazeleme döngüsü açığı kapatır.
    _sub = FcmService.messageEvents.stream.listen((m) {
      if (m.data['fromUserId'] == widget.friend.id) {
        setState(() => _peerTyping = false); // mesaj geldi → yazıyor söner
        _load();
      }
    });
    _typingSub = FcmService.typingEvents.stream.listen((m) {
      if (m.data['fromUserId'] != widget.friend.id) return;
      setState(() => _peerTyping = true);
      _typingExpiry?.cancel();
      _typingExpiry = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _peerTyping = false);
      });
    });
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  /// Kullanıcı yazarken karşı tarafa kısılmış "yazıyor" sinyali (4 sn'de bir).
  void _onTyping(String _) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTypingSentMs < 4000) return;
    _lastTypingSentMs = now;
    api.sendTyping(widget.friend.id).catchError((_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    _typingSub?.cancel();
    _poll?.cancel();
    _typingExpiry?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  final _decryptCache = <String, String>{};

  Future<void> _load() async {
    final publicKey = widget.friend.publicKey;
    if (publicKey == null) return;
    try {
      // Tam liste çekilir: hem yeni mesajlar gelir hem eskilerin
      // "iletildi" durumu tazelenir (aile sohbeti — hacim küçük).
      final raw = await api.listMessages(widget.friend.id);
      final server = <ChatMessage>[];
      for (final m in raw) {
        String text = '';
        if (m.kind == 'msg') {
          text = _decryptCache[m.id] ?? '';
          if (text.isEmpty) {
            try {
              text = await crypto.decryptMessage(
                  publicKey, _pairContext, m.ciphertext);
            } catch (_) {
              text = '(çözülemedi)';
            }
            _decryptCache[m.id] = text;
          }
        }
        server.add(ChatMessage(
          id: m.id,
          fromUserId: m.fromUserId,
          text: text,
          sentAtMs: m.sentAtMs,
          deliveredAtMs: m.deliveredAtMs,
          kind: m.kind,
          callType: m.callType,
          outcome: m.outcome,
          durationSec: m.durationSec,
        ));
        if (m.sentAtMs > _lastMs) _lastMs = m.sentAtMs;
      }
      // İyimser kopyalar: sunucu kopyası gelmişse (idempotent kimlik eşleşir)
      // ya da bir yarış sonucu sahipsiz kaldıysa listeden düşer — çift mesaj olmaz.
      final serverIds = server.map((m) => m.id).toSet();
      final myId = auth.me?.id ?? '';
      final pendings = _messages
          .where((m) =>
              m.pending && !serverIds.contains('c_${myId}_${m.id}'))
          .toList();
      _messages
        ..clear()
        ..addAll(server)
        ..addAll(pendings);
      await ActivityStore.markRead(widget.friend.id, _lastMs);
      _saveCache();
      if (mounted) {
        setState(() => _loading = false);
        _scrollToEnd();
      }
    } catch (_) {
      // çevrimdışı — önbellek/iskelet yerinde kalır, döngü tekrar dener
      if (mounted && _messages.isNotEmpty) setState(() => _loading = false);
    }
  }

  /// Sohbet akışındaki arama kaydı öğesi (WhatsApp'taki gibi):
  /// cevaplanan → "Sesli/Görüntülü arama"; cevapsız → kırmızı "Cevapsız …".
  String _durationLabel(int sec) {
    final h = sec ~/ 3600, m = (sec % 3600) ~/ 60, s = sec % 60;
    if (h > 0) return '$h sa $m dk';
    if (m > 0) return '$m dk $s sn';
    return '$s sn';
  }

  Widget _callItem(ChatMessage m, bool mine, ThemeData theme) {
    final video = m.callType == 'video';
    final missed = m.outcome == 'missed';
    var label = missed
        ? 'Cevapsız ${video ? 'görüntülü' : 'sesli'} arama'
        : '${video ? 'Görüntülü' : 'Sesli'} arama';
    if (!missed && m.durationSec != null && m.durationSec! > 0) {
      label += ' · ${_durationLabel(m.durationSec!)}';
    }
    final icon = missed
        ? Icons.phone_missed
        : video
            ? Icons.videocam
            : Icons.call;
    final color = missed ? theme.colorScheme.error : theme.colorScheme.outline;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: missed
              ? Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.3))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: missed
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant)),
            const SizedBox(width: 8),
            Text(
              DateFormat('HH:mm')
                  .format(DateTime.fromMillisecondsSinceEpoch(m.sentAtMs)),
              style:
                  TextStyle(fontSize: 11, color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  /// Yüklenirken gösterilen nabızlı iskelet baloncuklar.
  Widget _skeleton(ThemeData theme) {
    final c = theme.colorScheme.surfaceContainerHighest;
    Widget bubble(bool mine, double w) => Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            width: w,
            height: 44,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        bubble(false, 190),
        bubble(true, 150),
        bubble(false, 230),
        bubble(true, 120),
        bubble(false, 170),
      ]
          .animate(onPlay: (ctrl) => ctrl.repeat(reverse: true))
          .fade(begin: 0.45, end: 1.0, duration: 700.ms),
    );
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || widget.friend.publicKey == null || _sending) return;
    _input.clear();
    // İyimser gösterim: mesaj anında baloncuk olur (saat simgesiyle).
    // id = istemci kimliği: tekrar denemeler sunucuda ÇİFT KAYIT oluşturmaz.
    final optimistic = ChatMessage(
      id: 'm${DateTime.now().microsecondsSinceEpoch}',
      fromUserId: auth.me!.id,
      text: text,
      sentAtMs: DateTime.now().millisecondsSinceEpoch,
      pending: true,
    );
    setState(() => _messages.add(optimistic));
    _scrollToEnd();
    await _transmit(optimistic);
  }

  Future<void> _transmit(ChatMessage msg) async {
    final publicKey = widget.friend.publicKey;
    if (publicKey == null || _sending) return;
    setState(() {
      _sending = true;
      msg
        ..failed = false
        ..pending = true;
    });
    try {
      final sealed =
          await crypto.encryptMessage(publicKey, _pairContext, msg.text);
      await api.sendMessage(widget.friend.id, sealed, msg.id);
      _messages.remove(msg); // sunucu kopyası _load ile gelir (✓)
      ActivityStore.bumpActivity(widget.friend.id);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => msg.failed = true); // baloncukta kalır, dokununca dener
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Gönderilemedi — mesaja dokunup tekrar dene')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myId = auth.me?.id;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Avatar(user: widget.friend, radius: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(widget.friend.fullName,
                      overflow: TextOverflow.ellipsis),
                  if (_peerTyping)
                    Text(
                      'yazıyor…',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .fade(begin: 0.5, end: 1, duration: 600.ms),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sesli ara',
            onPressed: () => CallManager.startCall(widget.friend, false),
            icon: const Icon(Icons.call),
          ),
          IconButton(
            tooltip: 'Görüntülü ara',
            onPressed: () => CallManager.startCall(widget.friend, true),
            icon: const Icon(Icons.videocam),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Tooltip(
              message: 'Uçtan uca şifreli',
              child: Icon(Icons.lock, size: 16),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading && _messages.isEmpty
                ? _skeleton(theme) // yüklenirken boş durum DEĞİL, iskelet
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.forum,
                                size: 56, color: theme.colorScheme.outline),
                            const SizedBox(height: 8),
                            Text('İlk mesajı sen gönder!',
                                style: TextStyle(
                                    color: theme.colorScheme.outline)),
                          ],
                        ),
                      )
                    : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final m = _messages[i];
                      final mine = m.fromUserId == myId;
                      if (m.isCall) return _callItem(m, mine, theme);
                      return Align(
                        alignment:
                            mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: GestureDetector(
                          onTap:
                              m.failed ? () => _transmit(m) : null,
                          child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: mine ? null : theme.colorScheme.surfaceContainerHighest,
                            gradient: mine
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: Hop.gradient
                                        .map((c) => c.withValues(alpha: 0.30))
                                        .toList())
                                : null,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(mine ? 18 : 5),
                              bottomRight: Radius.circular(mine ? 5 : 18),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(m.text, style: const TextStyle(fontSize: 16)),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    DateFormat('HH:mm').format(
                                        DateTime.fromMillisecondsSinceEpoch(
                                            m.sentAtMs)),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.outline),
                                  ),
                                  if (mine) ...[
                                    const SizedBox(width: 4),
                                    // ! hata · saat gönderiliyor · ✓ sunucuda · ✓✓ iletildi
                                    Icon(
                                      m.failed
                                          ? Icons.error_outline
                                          : m.pending
                                              ? Icons.schedule
                                              : (m.deliveredAtMs != null
                                                  ? Icons.done_all
                                                  : Icons.done),
                                      size: 14,
                                      color: m.failed
                                          ? theme.colorScheme.error
                                          : m.deliveredAtMs != null
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.outline,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      onChanged: _onTyping,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Mesaj yaz…',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                    iconSize: 26,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
