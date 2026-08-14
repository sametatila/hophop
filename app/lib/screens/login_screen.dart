import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/bootstrap.dart';
import '../theme/hop_theme.dart';
import '../widgets/hop_ui.dart';
import '../widgets/hop_logo.dart';
import 'onboarding_screen.dart';

/// Giriş: ad + soyad + doğum tarihi. Başarılı girişten sonra oturum güvenli
/// depoda saklanır ve bir daha sorulmaz.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  DateTime? _birthDate;
  bool _busy = false;
  String? _error;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 8),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'Doğum tarihini seç',
      locale: const Locale('tr'),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _login() async {
    final bd = _birthDate;
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty || bd == null) {
      setState(() => _error = 'Tüm alanları doldurmalısın');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dateStr =
          '${bd.year.toString().padLeft(4, '0')}-${bd.month.toString().padLeft(2, '0')}-${bd.day.toString().padLeft(2, '0')}';
      await auth.login(_first.text.trim(), _last.text.trim(), dateStr);
      postLoginSetup(); // anahtar + FCM token kaydı arka planda
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    } on ApiException catch (e) {
      setState(() => _error = switch (e.status) {
            401 => 'Bilgiler eşleşmedi. Yazımı kontrol et — kayıt bilgilerinle birebir olmalı.',
            429 => 'Çok fazla deneme oldu, biraz sonra tekrar dene.',
            _ => 'Bir sorun oluştu, tekrar dene.',
          });
    } catch (_) {
      setState(() => _error = 'İnternet bağlantını kontrol et.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const BlobBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Marka: uygulamanın kendi ikonu (telefonun ana
                      // ekranındaki simgeyle birebir aynı tavşan)
                      const HopLogo(size: 132)
                          .animate(
                              onPlay: (c) => c.repeat(reverse: true))
                          .scale(
                              begin: const Offset(1, 1),
                              end: const Offset(1.05, 1.05),
                              duration: 2.seconds,
                              curve: Curves.easeInOut),
                      const SizedBox(height: 20),
                      Text('HopHop',
                          style: theme.textTheme.displaySmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text('Ailenle görüntülü konuş',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: theme.colorScheme.outline)),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _first,
                        textCapitalization: TextCapitalization.words,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.name,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                            labelText: 'Adın',
                            prefixIcon: Icon(Icons.person)),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _last,
                        textCapitalization: TextCapitalization.words,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.name,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                            labelText: 'Soyadın',
                            prefixIcon: Icon(Icons.family_restroom)),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.cake),
                        label: Text(
                          _birthDate == null
                              ? 'Doğum tarihini seç'
                              : '${_birthDate!.day}.${_birthDate!.month}.${_birthDate!.year}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(_error!,
                                style:
                                    TextStyle(color: theme.colorScheme.error),
                                textAlign: TextAlign.center)
                            .animate()
                            .shake(hz: 4, duration: 400.ms),
                      ],
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: _busy ? null : _login,
                        child: _busy
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Hadi başlayalım!'),
                      ),
                    ]
                        .animate(interval: 70.ms)
                        .fadeIn(duration: Hop.normal, curve: Curves.easeOut)
                        .slideY(begin: 0.15, curve: Curves.easeOutCubic),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
