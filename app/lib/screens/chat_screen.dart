import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../theme/hop_theme.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
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
  Timer? _poll;
  bool _sending = false;
  int _lastMs = 0;

  String get _pairContext {
    final ids = [auth.me!.id, widget.friend.id]..sort();
    return ids.join('_');
  }

  @override
  void initState() {
    super.initState();
    _load();
    // Uygulama açıkken gelen mesajlar FCM ile anında düşer; push kaçarsa
    // hafif bir tazeleme döngüsü açığı kapatır.
    _sub = FcmService.messageEvents.stream.listen((m) {
      if (m.data['fromUserId'] == widget.friend.id) _load();
    });
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _poll?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final publicKey = widget.friend.publicKey;
    if (publicKey == null) return;
    try {
      final raw = await api.listMessages(widget.friend.id, afterMs: _lastMs);
      if (raw.isEmpty) return;
      for (final m in raw) {
        String text;
        try {
          text = await crypto.decryptMessage(publicKey, _pairContext, m.ciphertext);
        } catch (_) {
          text = '🔒 (çözülemedi)';
        }
        _messages.add(ChatMessage(
          id: m.id,
          fromUserId: m.fromUserId,
          text: text,
          sentAtMs: m.sentAtMs,
        ));
        if (m.sentAtMs > _lastMs) _lastMs = m.sentAtMs;
      }
      if (mounted) {
        setState(() {});
        _scrollToEnd();
      }
    } catch (_) {/* çevrimdışı — döngü tekrar dener */}
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
    final publicKey = widget.friend.publicKey;
    if (text.isEmpty || publicKey == null || _sending) return;
    setState(() => _sending = true);
    try {
      final sealed = await crypto.encryptMessage(publicKey, _pairContext, text);
      await api.sendMessage(widget.friend.id, sealed);
      _input.clear();
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mesaj gönderilemedi')));
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
                child:
                    Text(widget.friend.fullName, overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Tooltip(
              message: 'Uçtan uca şifreli',
              child: Icon(Icons.lock, size: 18),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.forum,
                            size: 56, color: theme.colorScheme.outline),
                        const SizedBox(height: 8),
                        Text('İlk mesajı sen gönder!',
                            style: TextStyle(color: theme.colorScheme.outline)),
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
                      return Align(
                        alignment:
                            mine ? Alignment.centerRight : Alignment.centerLeft,
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
                              Text(
                                DateFormat('HH:mm').format(
                                    DateTime.fromMillisecondsSinceEpoch(
                                        m.sentAtMs)),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.outline),
                              ),
                            ],
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
