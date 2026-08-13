import 'package:flutter/material.dart';
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Arkadaşlar'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Kişiler'),
          NavigationDestination(icon: Icon(Icons.mail), label: 'İstekler'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Ayarlar'),
        ],
      ),
    );
  }
}
