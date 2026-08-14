import 'package:flutter/widgets.dart';
import '../services/activity_store.dart';

/// Sekme ekranlarını taze tutan ortak davranış.
///
/// Gezinme [IndexedStack] kullandığı için dört ekran da bellekte canlı kalır ve
/// hiçbiri yeniden `initState` almaz. Bu yüzden ekranlar iki şeyi dinler:
///
///  * [ActivityStore.socialVersion] — arkadaşlık grafiği değişti (istek
///    gönderildi/kabul edildi, karşı cihazdan bildirim geldi). Koşulsuz tazelenir.
///  * [ActivityStore.visibleTab] — bu sekme görünür oldu. Verisi [staleAfter]
///    süresinden eskiyse tazelenir; peş peşe sekme değiştirmede ağa gidilmez.
mixin TabRefresh<T extends StatefulWidget> on State<T> {
  /// Bu ekranın gezinmedeki sırası (Shell ile aynı olmalı).
  int get tabIndex;

  /// Verileri sunucudan yeniden çeken metot.
  Future<void> reload();

  /// Sekmeye dönüldüğünde bu süreden eski veri tazelenir.
  Duration get staleAfter => const Duration(seconds: 15);

  DateTime? _loadedAt;
  AppLifecycleListener? _lifecycle;

  /// Ekran kendi yüklemesini yaptığında çağırır (elle tazeleme dahil).
  void markLoaded() => _loadedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    ActivityStore.socialVersion.addListener(_onSocialChanged);
    ActivityStore.visibleTab.addListener(_onTabChanged);
    // Uygulama arka plandayken gelen bildirimler ayrı bir isolate'te işlenir;
    // oradaki değişiklikler arayüze yansımaz. Öne dönüşte bayat veri tazelenir.
    _lifecycle = AppLifecycleListener(onResume: _onTabChanged);
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    ActivityStore.socialVersion.removeListener(_onSocialChanged);
    ActivityStore.visibleTab.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onSocialChanged() {
    if (!mounted) return;
    markLoaded();
    reload();
  }

  void _onTabChanged() {
    if (!mounted || ActivityStore.visibleTab.value != tabIndex) return;
    final at = _loadedAt;
    if (at != null && DateTime.now().difference(at) < staleAfter) return;
    markLoaded();
    reload();
  }
}
