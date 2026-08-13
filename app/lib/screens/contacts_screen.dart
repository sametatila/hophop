import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../widgets/avatar.dart';

/// Kişiler: uygulamadaki tüm profiller + arkadaşlık isteği gönderme.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<UserProfile> _users = [];
  bool _loading = true;
  final _busyIds = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final users = await api.directory();
      if (mounted) {
        setState(() {
          _users = users..sort((a, b) => a.firstName.compareTo(b.firstName));
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendRequest(UserProfile user) async {
    setState(() => _busyIds.add(user.id));
    try {
      await api.sendFriendRequest(user.id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.firstName} kişisine istek gönderildi')),
        );
      }
    } on ApiException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İstek gönderilemedi')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kişiler')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: _users.length,
                itemBuilder: (context, i) {
                  final u = _users[i];
                  return ListTile(
                    leading: Avatar(user: u),
                    title: Text(u.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: switch (u.friendStatus) {
                      'friend' => const Chip(
                          avatar: Icon(Icons.check_circle,
                              color: Colors.green, size: 18),
                          label: Text('Arkadaş'),
                          backgroundColor: Color(0xFFD0F0C0)),
                      'requested' => const Chip(
                          avatar: Icon(Icons.hourglass_top, size: 18),
                          label: Text('İstek gönderildi')),
                      'incoming' => const Chip(
                          avatar: Icon(Icons.mark_email_unread, size: 18),
                          label: Text('Seni ekledi — İstekler\'e bak')),
                      _ => FilledButton.tonalIcon(
                          onPressed: _busyIds.contains(u.id)
                              ? null
                              : () => _sendRequest(u),
                          icon: const Icon(Icons.person_add, size: 18),
                          label: const Text('Arkadaş ekle'),
                        ),
                    },
                  );
                },
              ),
      ),
    );
  }
}
