import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Yaşa uyarlanan tasarım modu: doğum tarihi 13 yaş altını gösteriyorsa
/// "çocuk" (daha büyük dokunma hedefleri, sıcak canlı renkler, zıplayan
/// animasyonlar), aksi halde "yetişkin" (dingin, fütüristik indigo).
enum HopMode { kid, adult }

/// Girişten sonra doğum tarihine göre ayarlanır; tema canlı olarak değişir.
final appMode = ValueNotifier<HopMode>(HopMode.adult);

HopMode modeForBirthDate(String? birthDate) {
  final bd = birthDate == null ? null : DateTime.tryParse(birthDate);
  if (bd == null) return HopMode.adult;
  final now = DateTime.now();
  var age = now.year - bd.year;
  if (now.month < bd.month || (now.month == bd.month && now.day < bd.day)) {
    age--;
  }
  return age < 13 ? HopMode.kid : HopMode.adult;
}

/// Tasarım belirteçleri — süreler, eğriler, ölçek, degradeler.
class Hop {
  static const fast = Duration(milliseconds: 180);
  static const normal = Duration(milliseconds: 340);
  static const slow = Duration(milliseconds: 600);

  static bool get isKid => appMode.value == HopMode.kid;
  static Curve get curve => isKid ? Curves.easeOutBack : Curves.easeOutCubic;
  static double get scale => isKid ? 1.15 : 1.0;
  static double get radius => isKid ? 26 : 18;

  /// Marka degradesi — arka plan blob'ları ve vurgu yüzeyleri.
  static List<Color> get gradient => isKid
      ? const [Color(0xFFFF8A50), Color(0xFFFF5D8F), Color(0xFF8C6BFA)]
      : const [Color(0xFF5B5BD6), Color(0xFF7A5BE0), Color(0xFF2FA8C9)];

  /// Arama ekranları zemin degradesi (koyu, fütüristik).
  static const callGradient = [Color(0xFF141A2E), Color(0xFF1E2545), Color(0xFF10182B)];
}

ThemeData hopTheme(HopMode mode) {
  final kid = mode == HopMode.kid;
  final scheme = ColorScheme.fromSeed(
    seedColor: kid ? const Color(0xFFFF6D3D) : const Color(0xFF5B5BD6),
    surface: kid ? const Color(0xFFFFF6F0) : const Color(0xFFF6F6FB),
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final text = (kid
          ? GoogleFonts.quicksandTextTheme(base.textTheme)
          : GoogleFonts.manropeTextTheme(base.textTheme))
      .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  final radius = kid ? 26.0 : 18.0;

  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: kid ? 72 : 64,
      titleTextStyle: (kid ? text.headlineMedium : text.headlineSmall)
          ?.copyWith(fontWeight: FontWeight.w800),
      iconTheme: IconThemeData(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: Size.fromHeight(kid ? 60 : 52),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius)),
        textStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: Size.fromHeight(kid ? 60 : 52),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide:
            BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding:
          EdgeInsets.symmetric(horizontal: 18, vertical: kid ? 20 : 16),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: kid ? 84 : 72,
      backgroundColor: scheme.surfaceContainerLowest,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
          text.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
      iconTheme: WidgetStatePropertyAll(
          IconThemeData(size: kid ? 30 : 24)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius)),
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    }),
  );
}
