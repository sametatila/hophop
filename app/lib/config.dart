/// Varsayılan üretim adresi; farklı ortam için --dart-define=HOPHOP_API=... ile ezilir.
const String apiBaseUrl = String.fromEnvironment(
  'HOPHOP_API',
  defaultValue: 'https://hophop.exfe.me',
);

/// Gelen arama bildirimi bu süre sonunda kendini kapatır (arayan tarafta da aynı).
const Duration ringTimeout = Duration(seconds: 45);
