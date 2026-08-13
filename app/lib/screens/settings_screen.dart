import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/auth_service.dart';
import '../services/permission_service.dart';
import '../theme/hop_theme.dart';
import '../widgets/avatar.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

/// Ayarlar: profil, izin durumu (✅/❌ + tek dokunuş Düzelt), çıkış.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<Permission, PermissionStatus> _statuses = {};
  bool _aggressiveOem = false;

  static final _labels = {
    Permission.notification: (
      Icons.notifications_active,
      'Bildirimler',
      'Gelen aramaların çalması için'
    ),
    Permission.camera: (Icons.photo_camera, 'Kamera', 'Görüntülü arama için'),
    Permission.microphone: (Icons.mic, 'Mikrofon', 'Sesin karşıya gitmesi için'),
    Permission.ignoreBatteryOptimizations: (
      Icons.battery_saver,
      'Pil optimizasyonu muafiyeti',
      'Arka planda arama kaçırmamak için'
    ),
  };

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final statuses = await PermissionService.statuses();
    final aggressive = await PermissionService.isAggressiveOem();
    if (mounted) {
      setState(() {
        _statuses = statuses;
        _aggressiveOem = aggressive;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = auth.me;
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (me != null)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Hop.radius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: Hop.gradient
                      .map((c) => c.withValues(alpha: 0.18))
                      .toList(),
                ),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Hero(
                    tag: 'avatar-self', child: Avatar(user: me, radius: 26)),
                title: Text(me.fullName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 17)),
                subtitle: const Text('Profilim — fotoğrafını değiştir'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()));
                  setState(() {});
                },
              ),
            ),
          const SizedBox(height: 16),
          const Text('İzin durumu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._statuses.entries
              .where((e) =>
                  e.key != Permission.ignoreBatteryOptimizations ||
                  _aggressiveOem)
              .map((e) {
            final (icon, title, why) = _labels[e.key]!;
            final ok = e.value.isGranted;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Card(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Icon(icon, size: 30),
                title: Text(title),
                subtitle: Text(why),
                trailing: ok
                    ? const Icon(Icons.check_circle, color: Colors.green, size: 32)
                    : FilledButton(
                        onPressed: () async {
                          await PermissionService.fix(e.key);
                          await _refresh();
                        },
                        child: const Text('Düzelt'),
                      ),
              ),
              ),
            );
          }),
          const SizedBox(height: 24),
          Card(
            color: Colors.blue.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.lock, color: Colors.blueGrey),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Gizlilik: Görüşmelerin ve mesajların uçtan uca şifrelidir. '
                      'Ne sunucular ne de uygulamayı kuran kişi içeriklerini görebilir.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Çıkış yap'),
            onPressed: () async {
              final sure = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Çıkış yapılsın mı?'),
                  content: const Text(
                      'Tekrar girmek için ad, soyad ve doğum tarihi gerekir.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Vazgeç')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Çıkış yap')),
                  ],
                ),
              );
              if (sure == true && context.mounted) {
                await auth.logout();
                if (context.mounted) {
                  // rootNavigator: giriş ekranı sekmenin içinde değil,
                  // uygulamanın kökünde açılmalı.
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
