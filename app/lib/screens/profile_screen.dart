import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/photo_cache.dart';
import '../widgets/avatar.dart';

/// Profilim: fotoğraf çek/seç (kırpılıp ~20 KB'a sıkıştırılır).
/// Ad-soyad ve doğum tarihi kimliktir, salt okunur.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;

  Future<void> _pickPhoto(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (picked == null) return;
      // 512 px / kalite 80: avatarda da tam ekran görüntüleyicide de net
      // durur (~35-45 KB). Fotoğraf artık listelerde taşınmadığı, ayrı uçtan
      // bir kez inip önbelleğe yazıldığı için bu boyut bedava sayılır.
      final compressed = await FlutterImageCompress.compressWithFile(
        picked.path,
        minWidth: 512,
        minHeight: 512,
        quality: 80,
        format: CompressFormat.jpeg,
      );
      if (compressed == null) return;
      final b64 = base64Encode(compressed);
      await api.updateMe(photoBase64: b64);
      // Sunucudaki sürüm damgasını taze profille al ve önbelleği doğrudan
      // besle — kendi fotoğrafını yükledikten sonra geri indirmek saçma olur.
      final fresh = await api.me();
      if (fresh.photoVersion != null) {
        await PhotoCache.prime(fresh.id, fresh.photoVersion!, compressed);
      }
      await auth.updateCachedMe(fresh);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fotoğraf yüklenemedi')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = auth.me;
    if (me == null) return const Scaffold(body: SizedBox());
    final birthDate = me.birthDate != null
        ? DateFormat('d MMMM y', 'tr').format(DateTime.parse(me.birthDate!))
        : '—';
    return Scaffold(
      appBar: AppBar(title: const Text('Profilim')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Hero(tag: 'avatar-self', child: Avatar(user: me, radius: 64)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: _busy ? null : () => _pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.photo_camera),
                label: const Text('Fotoğraf çek'),
                style:
                    FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Galeriden seç'),
                style:
                    FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Ad Soyad'),
                  subtitle: Text(me.fullName, style: const TextStyle(fontSize: 16)),
                ),
                ListTile(
                  leading: const Icon(Icons.cake),
                  title: const Text('Doğum tarihi'),
                  subtitle: Text(birthDate, style: const TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ad, soyad ve doğum tarihi giriş kimliğindir; değişiklik için uygulamayı kuran kişiyle konuş.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
