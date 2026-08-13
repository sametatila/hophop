import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/call_manager.dart';
import '../widgets/avatar.dart';

/// Ana ekran: arkadaş kartları + yaklaşan doğum günleri şeridi.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<UserProfile> _friends = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Önce önbellek (anında görüntü), sonra ağ.
    final cached = await AuthService.cachedFriends();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _friends = cached;
        _loading = false;
      });
    }
    try {
      final fresh = await api.friends();
      await AuthService.cacheFriends(fresh);
      if (mounted) {
        setState(() {
          _friends = fresh;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = _friends
        .where((f) => (f.daysUntilBirthday ?? 999) <= 30)
        .toList()
      ..sort((a, b) =>
          (a.daysUntilBirthday ?? 999).compareTo(b.daysUntilBirthday ?? 999));

    return Scaffold(
      appBar: AppBar(title: const Text('🐇 HopHop')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _friends.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Henüz arkadaşın yok 🌱\n\n"Kişiler" sekmesinden aileni bul\nve arkadaşlık isteği gönder!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (upcoming.isNotEmpty) _birthdayStrip(upcoming),
                      ..._friends.map(_friendCard),
                    ],
                  ),
      ),
    );
  }

  Widget _birthdayStrip(List<UserProfile> upcoming) {
    return Card(
      color: Colors.amber.shade100,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🎂 Yaklaşan doğum günleri',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: upcoming.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, i) {
                  final f = upcoming[i];
                  final days = f.daysUntilBirthday!;
                  return Column(
                    children: [
                      Avatar(user: f, radius: 24),
                      const SizedBox(height: 4),
                      Text(f.firstName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        days == 0 ? 'BUGÜN! 🎉' : '$days gün kaldı',
                        style: TextStyle(
                          fontSize: 12,
                          color: days == 0 ? Colors.red : Colors.black54,
                          fontWeight:
                              days == 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _friendCard(UserProfile friend) {
    final isBirthday = friend.daysUntilBirthday == 0;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: isBirthday
          ? RoundedRectangleBorder(
              side: const BorderSide(color: Colors.amber, width: 3),
              borderRadius: BorderRadius.circular(12))
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Avatar(user: friend, radius: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isBirthday ? '🎉 ${friend.fullName} 🎂' : friend.fullName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (isBirthday)
                    const Text('Bugün doğum günü! Ara ve kutla!',
                        style: TextStyle(color: Colors.deepOrange)),
                ],
              ),
            ),
            IconButton.filledTonal(
              iconSize: 28,
              tooltip: 'Sesli ara',
              onPressed: () => CallManager.startCall(friend, false),
              icon: const Icon(Icons.call),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              iconSize: 28,
              tooltip: 'Görüntülü ara',
              onPressed: () => CallManager.startCall(friend, true),
              icon: const Icon(Icons.videocam),
            ),
          ],
        ),
      ),
    );
  }
}
