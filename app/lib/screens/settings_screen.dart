import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/auth_service.dart';
import '../services/foreground_service.dart';
import '../services/permission_service.dart';
import '../services/update_service.dart';
import '../theme/hop_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/update_card.dart';
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
  ({int code, String name})? _version;
  bool _checkingUpdate = false;
  bool _bgService = false;

  /// Tam ekran arama izni: null = henüz okunmadı (kartta çark döner).
  bool? _fullScreen;
  bool _checkingFullScreen = false;

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
    UpdateService.installedVersion().then((v) {
      if (mounted) setState(() => _version = v);
    });
    ForegroundService.isEnabled().then((v) {
      if (mounted) setState(() => _bgService = v);
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 4),
    ));
  }

  Future<void> _checkUpdate() async {
    setState(() => _checkingUpdate = true);
    final found = await UpdateService.check(force: true);
    if (!mounted) return;
    setState(() => _checkingUpdate = false);
    _toast(found == null
        ? 'En güncel sürümü kullanıyorsun.'
        : 'Yeni sürüm var: ${found.version}');
  }

  /// Tam ekran arama izni. Verilmişse eklenti anında true döner (hiçbir ekran
  /// açılmaz) — eskiden bu yüzden butona basınca hiçbir şey olmuyor gibi
  /// görünüyordu. Artık sonuç her iki durumda da kullanıcıya yazılır ve
  /// karttaki durum güncellenir.
  Future<void> _fixFullScreen() async {
    setState(() => _checkingFullScreen = true);
    try {
      await FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestFullScreenIntentPermission();
    } catch (_) {/* izin ekranı açılamadı — aşağıdaki okuma yine de doğru */}
    // Sistem ayar ekranından dönüşte gerçek durumu yerel köprüden doğrula:
    // eklentinin cevabı "istek başlatıldı" anlamına da gelebiliyor.
    final granted = await PermissionService.canUseFullScreenIntent();
    if (!mounted) return;
    setState(() {
      _checkingFullScreen = false;
      _fullScreen = granted;
    });
    _toast(granted
        ? 'Tam ekran arama açık: telefon kilitliyken arama ekranı doğrudan açılacak.'
        : 'Tam ekran arama kapalı kaldı. Telefon ayarları → Uygulamalar → '
            'HopHop → Bildirimler → "Tam ekran bildirimler" seçeneğini aç.');
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
    final fullScreen = await PermissionService.canUseFullScreenIntent();
    if (mounted) {
      setState(() {
        _statuses = statuses;
        _aggressiveOem = aggressive;
        _fullScreen = fullScreen;
      });
    }
  }

  /// Listedeki her kutu aynı ritimde dursun: kart + üstünde/altında 4 dp.
  /// (Kartların kendi kenar boşluğu temada sıfırlandığı için burada verilir.)
  Widget _row({required Widget child}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Card(child: child),
      );

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
          const SizedBox(height: 12),
          // Güncelleme varsa kart burada da görünsün — ana ekranı kaçıran olur.
          const UpdateCard(),
          _row(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              leading: const Icon(Icons.system_update, size: 30),
              title: const Text('Uygulama sürümü'),
              subtitle: Text(_version == null
                  ? '—'
                  : '${_version!.name} (${_version!.code})'),
              trailing: _checkingUpdate
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : FilledButton.tonal(
                      onPressed: _checkUpdate,
                      style:
                          FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                      child: const Text('Denetle'),
                    ),
            ),
          ),
          _row(
            child: SwitchListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              secondary: const Icon(Icons.notifications_paused, size: 30),
              title: const Text('Arka planda hazır bekle'),
              // Agresif markalarda (Xiaomi/Oppo/vivo…) sistem uygulamayı
              // durdurabildiği için açmak gerçekten işe yarar; onlara ayrı yazılır.
              subtitle: Text(_aggressiveOem
                  ? 'Kalıcı bir bildirim gösterir. Bu marka telefonlar '
                      'uygulamaları durdurabildiği için açman önerilir.'
                  : 'Kalıcı bir bildirim gösterir. Çoğu telefonda gerekmez; '
                      'aramalar geç geliyorsa aç.'),
              value: _bgService,
              onChanged: (v) async {
                setState(() => _bgService = v);
                await ForegroundService.setEnabled(v);
                _toast(v
                    ? 'Arka planda hazır bekleme açıldı.'
                    : 'Arka planda hazır bekleme kapatıldı.');
              },
            ),
          ),
          const SizedBox(height: 12),
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
            return _row(
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
            );
          }),
          _row(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              leading: const Icon(Icons.fullscreen, size: 30),
              title: const Text('Tam ekran arama'),
              // Diğer izin satırları gibi DURUMU yazar: kullanıcı butona
              // basmadan da açık mı kapalı mı olduğunu görür.
              subtitle: Text(_fullScreen == false
                  ? 'Kapalı — kilitliyken yalnızca bildirim görünür'
                  : 'Kilitliyken arama ekranı doğrudan açılır'),
              trailing: _checkingFullScreen || _fullScreen == null
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : _fullScreen!
                      ? const Icon(Icons.check_circle,
                          color: Colors.green, size: 32)
                      : FilledButton(
                          onPressed: _fixFullScreen,
                          // Tema varsayılanı tam genişlik — trailing içinde
                          // sınırlanmalı.
                          style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 44)),
                          child: const Text('Düzelt'),
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
              // Elle yazılmış sürüm her yayında unutuluyordu — paketten okunur.
              child: Text('HopHop v${_version?.name ?? '—'}',
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
