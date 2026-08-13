import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'api_client.dart';

/// Sohbet/arama etkinliği: okunmamış sayaçlar, son etkileşim zamanları ve
/// cevapsız aramalar. Kalıcı durum cihazda dosyada tutulur; okunmamış
/// sayılar sunucudaki şifreli mesaj meta verisinden (summary) türetilir.
class ActivityStore {
  /// friendId → okunmamış mesaj sayısı
  static final unread = ValueNotifier<Map<String, int>>({});

  /// friendId → son etkileşim (mesaj/arama) zamanı ms — ana ekran sıralaması
  static final lastActivity = ValueNotifier<Map<String, int>>({});

  /// friendId → görülmemiş cevapsız arama sayısı
  static final missed = ValueNotifier<Map<String, int>>({});

  static Map<String, int> _lastRead = {};

  static Future<File> _file(String name) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$name.json');
  }

  static Future<Map<String, int>> _load(String name) async {
    try {
      final f = await _file(name);
      if (!await f.exists()) return {};
      return (jsonDecode(await f.readAsString()) as Map)
          .map((k, v) => MapEntry(k as String, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _save(String name, Map<String, int> data) async {
    try {
      await (await _file(name)).writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  /// Açılışta çağrılır: kalıcı durumu yükler, sunucudan özeti tazeler.
  static Future<void> init() async {
    _lastRead = await _load('last_read');
    missed.value = await _load('missed_calls');
    lastActivity.value = await _load('last_activity');
    await refresh();
  }

  /// Sunucudan okunmamış sayıları ve son mesaj zamanlarını çeker.
  static Future<void> refresh() async {
    try {
      final s = await api.messagesSummary(_lastRead);
      final u = <String, int>{};
      final act = Map<String, int>.from(lastActivity.value);
      for (final e in s) {
        if (e.unread > 0) u[e.withUserId] = e.unread;
        if (e.lastMs > (act[e.withUserId] ?? 0)) act[e.withUserId] = e.lastMs;
      }
      unread.value = u;
      lastActivity.value = act;
      await _save('last_activity', act);
    } catch (_) {/* çevrimdışı — mevcut durumla devam */}
  }

  /// Sohbet açıldığında/okunduğunda çağrılır.
  static Future<void> markRead(String friendId, int upToMs) async {
    if (upToMs <= (_lastRead[friendId] ?? 0)) {
      // yine de rozet temizlensin
    } else {
      _lastRead[friendId] = upToMs;
      await _save('last_read', _lastRead);
    }
    if (unread.value.containsKey(friendId)) {
      unread.value = Map.from(unread.value)..remove(friendId);
    }
    bumpActivity(friendId, upToMs);
  }

  static void bumpActivity(String friendId, [int? ms]) {
    final t = ms ?? DateTime.now().millisecondsSinceEpoch;
    if (t > (lastActivity.value[friendId] ?? 0)) {
      lastActivity.value = Map.from(lastActivity.value)..[friendId] = t;
      _save('last_activity', lastActivity.value);
    }
  }

  /// Uygulama açıkken yeni mesaj düştüğünde anında rozet artışı.
  static void onIncomingMessage(String fromUserId) {
    unread.value = Map.from(unread.value)
      ..[fromUserId] = (unread.value[fromUserId] ?? 0) + 1;
    bumpActivity(fromUserId);
  }

  // ---- Cevapsız aramalar ----

  static Future<void> recordMissed(String callerId) async {
    missed.value = Map.from(missed.value)
      ..[callerId] = (missed.value[callerId] ?? 0) + 1;
    await _save('missed_calls', missed.value);
    bumpActivity(callerId);
  }

  static Future<void> clearMissed(String friendId) async {
    if (!missed.value.containsKey(friendId)) return;
    missed.value = Map.from(missed.value)..remove(friendId);
    await _save('missed_calls', missed.value);
  }

  /// Arka plan isolate'i cevapsız aramayı doğrudan dosyaya işler
  /// (bildirim işleyicisinde ValueNotifier'lar yaşamaz).
  static Future<void> recordMissedInBackground(String callerId) async {
    final data = await _load('missed_calls');
    data[callerId] = (data[callerId] ?? 0) + 1;
    await _save('missed_calls', data);
  }
}
