import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/call_manager.dart';
import '../theme/hop_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/hop_ui.dart';
import 'chat_screen.dart';

/// Ana ekran: selamlama + yaklaşan doğum günleri şeridi + arkadaş kartları.
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
    // Önce önbellek (anında görüntü), sonra ağ — spinner ağı BEKLEMEZ.
    final cached = await AuthService.cachedFriends();
    if (mounted) {
      setState(() {
        if (cached.isNotEmpty) _friends = cached;
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
    final theme = Theme.of(context);
    final me = auth.me;
    final upcoming = _friends
        .where((f) => (f.daysUntilBirthday ?? 999) <= 30)
        .toList()
      ..sort((a, b) =>
          (a.daysUntilBirthday ?? 999).compareTo(b.daysUntilBirthday ?? 999));

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    me == null
                                        ? 'Merhaba!'
                                        : 'Merhaba, ${me.firstName}!',
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    'Bugün kiminle konuşmak istersin?',
                                    style: TextStyle(
                                        color: theme.colorScheme.outline,
                                        fontSize: 15),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient:
                                    LinearGradient(colors: Hop.gradient),
                              ),
                              child: const Icon(Icons.cruelty_free,
                                  color: Colors.white, size: 26),
                            ),
                          ],
                        ).animate().fadeIn(duration: Hop.normal),
                      ),
                    ),
                  ),
                  if (upcoming.isNotEmpty)
                    SliverToBoxAdapter(child: _birthdayStrip(upcoming)),
                  if (_friends.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.emoji_people,
                        title: 'Henüz arkadaşın yok',
                        subtitle:
                            '"Kişiler" sekmesinden aileni bul ve arkadaşlık isteği gönder!',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      sliver: SliverList.builder(
                        itemCount: _friends.length,
                        itemBuilder: (context, i) => _friendCard(_friends[i])
                            .animate(delay: (50 * i).ms)
                            .fadeIn(duration: Hop.normal)
                            .slideY(begin: 0.12, curve: Curves.easeOutCubic),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _birthdayStrip(List<UserProfile> upcoming) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Hop.radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              Hop.gradient.map((c) => c.withValues(alpha: 0.16)).toList(),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cake, size: 20),
              SizedBox(width: 6),
              Text('Yaklaşan doğum günleri',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: upcoming.length,
              separatorBuilder: (_, __) => const SizedBox(width: 18),
              itemBuilder: (context, i) {
                final f = upcoming[i];
                final days = f.daysUntilBirthday!;
                final today = days == 0;
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: today
                            ? LinearGradient(colors: Hop.gradient)
                            : null,
                      ),
                      child: Avatar(user: f, radius: 26),
                    ),
                    const SizedBox(height: 5),
                    Text(f.firstName,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      today ? 'BUGÜN!' : '$days gün',
                      style: TextStyle(
                        fontSize: 12,
                        color: today ? Colors.deepOrange : Colors.black54,
                        fontWeight:
                            today ? FontWeight.w800 : FontWeight.normal,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: Hop.normal).slideY(begin: 0.1);
  }

  Widget _friendCard(UserProfile friend) {
    final theme = Theme.of(context);
    final isBirthday = friend.daysUntilBirthday == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Pressable(
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ChatScreen(friend: friend))),
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(Hop.isKid ? 16 : 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isBirthday
                        ? LinearGradient(colors: Hop.gradient)
                        : null,
                  ),
                  child: Hero(
                    tag: 'avatar-${friend.id}',
                    child: Avatar(user: friend, radius: Hop.isKid ? 34 : 30),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isBirthday) ...[
                            const Icon(Icons.cake,
                                color: Colors.deepOrange, size: 20),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              friend.fullName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: Hop.isKid ? 19 : 17,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        isBirthday
                            ? 'Bugün doğum günü — ara ve kutla!'
                            : 'Mesaj için dokun',
                        style: TextStyle(
                            color: isBirthday
                                ? Colors.deepOrange
                                : theme.colorScheme.outline,
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
                GradientOrb(
                  icon: Icons.call,
                  size: Hop.isKid ? 52 : 44,
                  colors: const [Color(0xFF34B979), Color(0xFF1F9D8A)],
                  tooltip: 'Sesli ara',
                  onTap: () => CallManager.startCall(friend, false),
                ),
                const SizedBox(width: 10),
                GradientOrb(
                  icon: Icons.videocam,
                  size: Hop.isKid ? 52 : 44,
                  tooltip: 'Görüntülü ara',
                  onTap: () => CallManager.startCall(friend, true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
