import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  /// Basit ebeveyn kapısı: çarpım sorusu (çocuk uygulamalarında standart).
  Future<bool> _parentalGate() async {
    final rnd = Random();
    final a = 6 + rnd.nextInt(4), b = 6 + rnd.nextInt(4);
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Büyüklere soru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Devam etmek için: $a × $b = ?',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Cevap'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim() == '${a * b}'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: const Text('Doğrula'),
          ),
        ],
      ),
    );
    return ok == true;
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
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Card(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
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
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 44)),
                        child: const Text('Düzelt'),
                      ),
              ),
              ),
            );
          }),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Card(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                leading: const Icon(Icons.fullscreen, size: 30),
                title: const Text('Tam ekran arama'),
                subtitle: const Text(
                    'Kilitliyken arama ekranı doğrudan açılsın'),
                trailing: FilledButton.tonal(
                  onPressed: () async {
                    // İzin verilmemişse sistem ayar sayfasını açar.
                    await FlutterLocalNotificationsPlugin()
                        .resolvePlatformSpecificImplementation<
                            AndroidFlutterLocalNotificationsPlugin>()
                        ?.requestFullScreenIntentPermission();
                    await _refresh();
                  },
                  // Tema varsayılanı tam genişlik — trailing içinde sınırlanmalı.
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  child: const Text('Kontrol et'),
                ),
              ),
            ),
          ),
          if (_aggressiveOem) ...[
            const SizedBox(height: 12),
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.rocket_launch, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Otomatik başlatma (önemli)',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bu telefon markası, yeniden başlatmadan sonra uygulamaları '
                      'kendiliğinden çalıştırmayabilir. Aramaları hiç kaçırmamak için '
                      'telefonun ayarlarında HopHop için "Otomatik başlat" iznini aç:\n'
                      '1. Aşağıdaki butonla uygulama ayarlarını aç\n'
                      '2. "Otomatik başlat" / "Autostart" seçeneğini bul ve aç\n'
                      '3. Bulamazsan: Telefon Ayarları → Uygulamalar → HopHop',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: openAppSettings,
                      icon: const Icon(Icons.settings_applications, size: 18),
                      label: const Text('Uygulama ayarlarını aç'),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 44)),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('HopHop v1.0.0',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize: 12)),
            ),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Çıkış yap'),
            onPressed: () async {
              // Çocuk modunda ebeveyn kapısı: çocuk yanlışlıkla oturumu
              // kapatıp aileyi kendisine ulaşılamaz bırakmasın.
              if (Hop.isKid && !await _parentalGate()) return;
              if (!context.mounted) return;
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
