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
            onDestinationSelected: (i) {
              setState(() => _index = i);
              // Ekranlar IndexedStack'te canlı kaldığı için görünür olduklarını
              // ancak buradan öğrenir; bayat verilerini o an tazelerler.
              ActivityStore.visibleTab.value = i;
            },
            // İkonlar sekmenin İŞİNİ anlatır: ev/mektup gibi genel simgeler
            // yerine aramaya, kişi aramaya ve kişi eklemeye karşılık gelenler.
            // Seçiliyken dolu, değilken çizgi hâli (Material 3 alışkanlığı).
            destinations: [
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: total > 0,
                  label: Text('$total'),
                  child: const Icon(Icons.groups_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: total > 0,
                  label: Text('$total'),
                  child: const Icon(Icons.groups),
                ),
                label: 'Arkadaşlar',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_search_outlined),
                selectedIcon: Icon(Icons.person_search),
                label: 'Kişiler',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: ActivityStore.pendingRequests.value > 0,
                  label: Text('${ActivityStore.pendingRequests.value}'),
                  child: const Icon(Icons.person_add_alt),
                ),
                selectedIcon: Badge(
                  isLabelVisible: ActivityStore.pendingRequests.value > 0,
                  label: Text('${ActivityStore.pendingRequests.value}'),
                  child: const Icon(Icons.person_add_alt_1),
                ),
                label: 'İstekler',
              ),
              const NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Ayarlar',
              ),
            ],
          );
        },
      ),
    );
  }
}
