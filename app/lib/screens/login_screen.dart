import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/bootstrap.dart';
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
      setState(() => _error = 'Tüm alanları doldur 🙂');
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🐇', style: TextStyle(fontSize: 72)),
                Text('HopHop',
                    style: theme.textTheme.displaySmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Ailenle görüntülü konuş!',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 32),
                TextField(
                  controller: _first,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Adın', prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _last,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Soyadın',
                      prefixIcon: Icon(Icons.family_restroom)),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.cake),
                  label: Text(
                    _birthDate == null
                        ? 'Doğum tarihini seç'
                        : '${_birthDate!.day}.${_birthDate!.month}.${_birthDate!.year}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56)),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!,
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.center),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _login,
                  style:
                      FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  child: _busy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Hadi başlayalım! 🎉',
                          style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
