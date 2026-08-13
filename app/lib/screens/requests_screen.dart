import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../theme/hop_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/hop_ui.dart';

/// İstekler: gelen (kabul/red) ve gönderilen (iptal) bekleyen istekler.
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  List<FriendRequestEntry> _incoming = [];
  List<FriendRequestEntry> _outgoing = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await api.friendRequests();
      if (mounted) {
        setState(() {
          _incoming = r.incoming;
          _outgoing = r.outgoing;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respond(FriendRequestEntry entry, bool accept) async {
    try {
      await api.respondFriendRequest(entry.requestId, accept);
      await _load();
      if (accept && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${entry.user?.firstName ?? ''} artık arkadaşın! Ana ekrandan arayabilirsin')));
      }
    } catch (_) {}
  }

  Future<void> _cancel(FriendRequestEntry entry) async {
    try {
      await api.cancelFriendRequest(entry.requestId);
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İstekler')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_incoming.isEmpty && _outgoing.isEmpty)
                ? ListView(children: const [
                    SizedBox(height: 120),
                    EmptyState(
                        icon: Icons.mark_email_read,
                        title: 'Bekleyen istek yok',
                        subtitle:
                            'Kişiler sekmesinden aileni ekleyebilirsin.'),
                  ])
                : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Icon(Icons.move_to_inbox),
                        SizedBox(width: 8),
                        Text('Gelen istekler',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  if (_incoming.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Bekleyen istek yok'),
                    ),
                  ..._incoming.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 2),
                            leading: e.user != null
                                ? Avatar(user: e.user!, radius: 26)
                                : null,
                            title: Text(e.user?.fullName ?? '—',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            subtitle:
                                const Text('Seninle arkadaş olmak istiyor'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GradientOrb(
                                  icon: Icons.check,
                                  size: 44,
                                  colors: const [
                                    Color(0xFF34B979),
                                    Color(0xFF1F9D8A)
                                  ],
                                  tooltip: 'Kabul et',
                                  onTap: () => _respond(e, true),
                                ),
                                const SizedBox(width: 8),
                                IconButton.outlined(
                                  onPressed: () => _respond(e, false),
                                  icon: const Icon(Icons.close),
                                  tooltip: 'Reddet',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ).animate().fadeIn(duration: Hop.normal).slideX(
                          begin: 0.06, curve: Curves.easeOutCubic)),
                  const Padding(
                    padding: EdgeInsets.only(top: 24, bottom: 10),
                    child: Row(
                      children: [
                        Icon(Icons.outbox),
                        SizedBox(width: 8),
                        Text('Gönderilen istekler',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  if (_outgoing.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Bekleyen istek yok'),
                    ),
                  ..._outgoing.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 2),
                            leading: e.user != null
                                ? Avatar(user: e.user!, radius: 26)
                                : null,
                            title: Text(e.user?.fullName ?? '—',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            subtitle: const Text('Cevap bekleniyor…'),
                            trailing: TextButton(
                              onPressed: () => _cancel(e),
                              child: const Text('İptal'),
                            ),
                          ),
                        ),
                      )),
                ],
              ),
      ),
    );
  }
}
