import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../widgets/avatar.dart';

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
                '${entry.user?.firstName ?? ''} artık arkadaşın! Ana ekrandan arayabilirsin 🎉')));
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
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  const Text('📥 Gelen istekler',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (_incoming.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Bekleyen istek yok'),
                    ),
                  ..._incoming.map((e) => Card(
                        child: ListTile(
                          leading:
                              e.user != null ? Avatar(user: e.user!) : null,
                          title: Text(e.user?.fullName ?? '—'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton.filled(
                                onPressed: () => _respond(e, true),
                                icon: const Icon(Icons.check),
                                tooltip: 'Kabul et',
                              ),
                              const SizedBox(width: 4),
                              IconButton.outlined(
                                onPressed: () => _respond(e, false),
                                icon: const Icon(Icons.close),
                                tooltip: 'Reddet',
                              ),
                            ],
                          ),
                        ),
                      )),
                  const SizedBox(height: 24),
                  const Text('📤 Gönderilen istekler',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (_outgoing.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Bekleyen istek yok'),
                    ),
                  ..._outgoing.map((e) => Card(
                        child: ListTile(
                          leading:
                              e.user != null ? Avatar(user: e.user!) : null,
                          title: Text(e.user?.fullName ?? '—'),
                          subtitle: const Text('Cevap bekleniyor…'),
                          trailing: TextButton(
                            onPressed: () => _cancel(e),
                            child: const Text('İptal'),
                          ),
                        ),
                      )),
                ],
              ),
      ),
    );
  }
}
