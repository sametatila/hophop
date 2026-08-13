import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/permission_service.dart';
import '../theme/hop_theme.dart';
import '../widgets/hop_ui.dart';
import 'shell.dart';

/// İlk açılış izin sihirbazı — plan §5.5.
/// Kart kart ilerler; her kart tek dokunuşla sistem diyaloğunu açar.
/// Pil optimizasyonu kartı yalnızca agresif OEM'lerde görünür.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _StepDef {
  final IconData icon;
  final String title, body, button;
  final Future<void> Function() action;
  _StepDef(this.icon, this.title, this.body, this.button, this.action);
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  List<_StepDef>? _steps;

  @override
  void initState() {
    super.initState();
    _buildSteps();
  }

  Future<void> _buildSteps() async {
    final aggressive = await PermissionService.isAggressiveOem();
    setState(() {
      _steps = [
        _StepDef(
          Icons.notifications_active,
          'Bildirimlere izin ver',
          'Seni arayanları duyabilmen için HopHop\'un zil çalması gerekiyor.',
          'İzin ver',
          () async => Permission.notification.request(),
        ),
        _StepDef(
          Icons.photo_camera,
          'Kamera ve mikrofon',
          'Görüntülü konuşabilmek için kameranı ve sesini kullanacağız.',
          'İzin ver',
          () async {
            await Permission.camera.request();
            await Permission.microphone.request();
          },
        ),
        if (aggressive)
          _StepDef(
            Icons.battery_saver,
            'Pil ayarı (önemli!)',
            'Bu telefonun markası, uygulamaları arka planda uyutabiliyor. '
                'Aramaları kaçırmamak için HopHop\'u pil optimizasyonundan çıkar. '
                'Butona bas, açılan soruda "İzin ver" de.',
            'Pil ayarını aç',
            () async => Permission.ignoreBatteryOptimizations.request(),
          ),
      ];
    });
  }

  void _next(int index) {
    final steps = _steps!;
    if (index + 1 >= steps.length) {
      Navigator.of(context)
          .pushReplacement(MaterialPageRoute(builder: (_) => const Shell()));
    } else {
      _controller.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    if (steps == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const BlobBackground(),
          SafeArea(
        child: PageView.builder(
          controller: _controller,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: steps.length,
          itemBuilder: (context, i) {
            final step = steps[i];
            return Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: Hop.gradient),
                    ),
                    child: Icon(step.icon, size: 64, color: Colors.white),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.06, 1.06),
                          duration: 1800.ms,
                          curve: Curves.easeInOut),
                  const SizedBox(height: 24),
                  Text(step.title,
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(step.body,
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 40),
                  FilledButton(
                    onPressed: () async {
                      await step.action();
                      if (mounted) _next(i);
                    },
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56)),
                    child: Text(step.button, style: const TextStyle(fontSize: 18)),
                  ),
                  TextButton(
                    onPressed: () => _next(i),
                    child: const Text('Şimdilik geç'),
                  ),
                  const SizedBox(height: 8),
                  Text('${i + 1} / ${steps.length}',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            );
          },
        ),
          ),
        ],
      ),
    );
  }
}
