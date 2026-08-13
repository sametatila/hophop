import 'package:flutter/material.dart';
import '../services/activity_store.dart';
import 'home_screen.dart';
import 'contacts_screen.dart';
import 'requests_screen.dart';
import 'settings_screen.dart';

/// Ana gezinme: Arkadaşlar / Kişiler / İstekler / Ayarlar.
/// Ayarlar sekmesi kendi Navigator'ını taşır — Profil gibi alt sayfalar
/// sekmenin İÇİNDE açılır, alt gezinme çubuğu kaybolmaz.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;
  final _settingsNav = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const HomeScreen(),
          const ContactsScreen(),
          const RequestsScreen(),
          NavigatorPopHandler(
            onPopWithResult: (_) => _settingsNav.currentState?.maybePop(),
            child: Navigator(
              key: _settingsNav,
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (_) => const SettingsScreen(),
                settings: settings,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: Listenable.merge([
          ActivityStore.unread,
          ActivityStore.missed,
          ActivityStore.pendingRequests,
        ]),
        builder: (context, _) {
          // Cevapsız aramalar da sohbet akışına düştüğü için sunucu tarafı
          // okunmamış sayısına zaten dahil — çift saymamak için yalnız unread.
          final total =
              ActivityStore.unread.value.values.fold(0, (a, b) => a + b);
          return NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: total > 0,
                  label: Text('$total'),
                  child: const Icon(Icons.home),
                ),
                label: 'Arkadaşlar',
              ),
              const NavigationDestination(
                  icon: Icon(Icons.people), label: 'Kişiler'),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: ActivityStore.pendingRequests.value > 0,
                  label: Text('${ActivityStore.pendingRequests.value}'),
                  child: const Icon(Icons.mail),
                ),
                label: 'İstekler',
              ),
              const NavigationDestination(
                  icon: Icon(Icons.settings), label: 'Ayarlar'),
            ],
          );
        },
      ),
    );
  }
}
