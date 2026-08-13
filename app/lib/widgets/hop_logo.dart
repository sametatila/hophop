import 'package:flutter/material.dart';

/// HopHop marka işareti — uygulamanın kendi ikonunun ta kendisi.
///
/// Tek kaynak: `brand/hophop-icon.svg` → `brand/render.sh` ile
/// `assets/brand/hophop.png` üretilir. Uygulama içinde başka bir tavşan
/// çizilmez (eskiden giriş ve ana ekranda Material'ın `Icons.cruelty_free`
/// tavşanı vardı; ikonla alakası yoktu).
class HopLogo extends StatelessWidget {
  final double size;

  /// Köşe yuvarlaklığı ikonun kendi squircle oranıyla aynı kalsın diye
  /// boyuta göre ölçeklenir (192 birimde 42).
  const HopLogo({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    // Gölge yalnızca büyük kullanımda (giriş ekranı gibi). Küçük boyutta hale
    // ikonun kendisinden daha çok yer kaplayıp lekeye benziyordu.
    final glow = size >= 64;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 42 / 192),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: const Color(0xFFD861B2).withValues(alpha: 0.28),
                  blurRadius: size * 0.22,
                  offset: Offset(0, size * 0.06),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/brand/hophop.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
