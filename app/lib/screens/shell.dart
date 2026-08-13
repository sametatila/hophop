import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'contacts_screen.dart';
import 'requests_screen.dart';
import 'settings_screen.dart';

/// Ana gezinme: Arkadaşlar / Kişiler / İstekler / Ayarlar.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          ContactsScreen(),
          RequestsScreen(),
          SettingsScreen(),
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
