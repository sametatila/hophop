import 'dart:io';

import 'package:flutter/material.dart';

import '../services/update_service.dart';
import '../theme/hop_theme.dart';

/// Ana ekranın üstünde beliren "yeni sürüm var" kartı.
/// Güncelleme yoksa hiç yer kaplamaz.
class UpdateCard extends StatelessWidget {
  const UpdateCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppUpdate?>(
      valueListenable: UpdateService.available,
      builder: (context, update, _) {
        if (update == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _UpdatePanel(update: update),
        );
      },
    );
  }
}

/// Yeni sürüm ilk kez görüldüğünde kullanıcının önüne çıkan diyalog.
///
/// İçeriği ana ekrandaki kartın ta kendisi: indirme ilerlemesi, "bilinmeyen
/// kaynak" izni ve hata/tekrar dene akışı tek yerde kalsın diye kopyalanmadı.
Future<void> showUpdateDialog(BuildContext context, AppUpdate update) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      // double.maxFinite: diyalog kendi genişliğine yayılsın; sabit bir ölçü
      // dar telefonlarda taşardı.
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(child: _UpdatePanel(update: update)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Sonra'),
        ),
      ],
    ),
  );
}

class _UpdatePanel extends StatefulWidget {
  final AppUpdate update;
  const _UpdatePanel({required this.update});

  @override
  State<_UpdatePanel> createState() => _UpdatePanelState();
}

enum _Phase { idle, downloading, ready, error }

class _UpdatePanelState extends State<_UpdatePanel> {
  _Phase _phase = _Phase.idle;
  double _progress = 0;
  String? _error;
  File? _apk;

  Future<void> _start() async {
    // Android 8+ her uygulamadan ayrıca "bu kaynaktan kuruluma izin ver" ister.
    if (!await UpdateService.canInstall()) {
      if (!mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tek seferlik izin'),
          content: const Text(
              'Telefonun, HopHop\'un güncelleme kurmasına izin vermesi gerekiyor.\n\n'
              'Açılacak ekranda "Bu kaynağa izin ver" seçeneğini aç, sonra geri dön.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Vazgeç')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                child: const Text('Ayarları aç')),
          ],
        ),
      );
      if (go == true) await UpdateService.openInstallSettings();
      return;
    }

    setState(() {
      _phase = _Phase.downloading;
      _progress = 0;
      _error = null;
    });
    try {
      final apk = await UpdateService.download(
        widget.update,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() {
        _phase = _Phase.ready;
        _apk = apk;
      });
      await UpdateService.install(apk);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = 'Güncelleme indirilemedi. İnternetini kontrol edip tekrar dene.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final u = widget.update;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Hop.radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: Hop.gradient.map((c) => c.withValues(alpha: 0.20)).toList(),
        ),
        border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.system_update,
                  color: theme.colorScheme.primary, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Yeni sürüm hazır',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    Text(
                      [
                        'Sürüm ${u.version}',
                        if (u.sizeLabel.isNotEmpty) u.sizeLabel,
                      ].join(' · '),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (u.notes != null && u.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(u.notes!, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 12),
          switch (_phase) {
            _Phase.downloading => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                        value: _progress == 0 ? null : _progress,
                        minHeight: 8),
                  ),
                  const SizedBox(height: 6),
                  Text('İndiriliyor… %${(_progress * 100).round()}',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            _Phase.ready => Row(
                children: [
                  Icon(Icons.check_circle,
                      color: Colors.green.shade600, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                      child: Text('İndirildi — kurulum ekranını onayla')),
                  TextButton(
                    onPressed: () {
                      final apk = _apk;
                      if (apk != null) UpdateService.install(apk);
                    },
                    child: const Text('Tekrar aç'),
                  ),
                ],
              ),
            _ => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Text(_error!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.error)),
                    const SizedBox(height: 8),
                  ],
                  FilledButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.download, size: 20),
                    label: Text(_phase == _Phase.error
                        ? 'Tekrar dene'
                        : 'Şimdi güncelle'),
                  ),
                ],
              ),
          },
        ],
      ),
    );
  }
}
