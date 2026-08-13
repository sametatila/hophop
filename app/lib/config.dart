/// Derleme sırasında verilir:
///   flutter build apk --release --dart-define=HOPHOP_API=https://<proje>.vercel.app
const String apiBaseUrl = String.fromEnvironment(
  'HOPHOP_API',
  defaultValue: 'https://hophop.vercel.app',
);

/// Gelen arama bildirimi bu süre sonunda kendini kapatır (arayan tarafta da aynı).
const Duration ringTimeout = Duration(seconds: 45);
