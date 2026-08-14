import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config.dart';

/// Sunucudaki `version.json` kaydı.
class AppUpdate {
  final int versionCode;
  final String version;
  final Uri url;
  final String? notes;
  final int? size;

  const AppUpdate({
    required this.versionCode,
    required this.version,
    required this.url,
    this.notes,
    this.size,
  });

  /// `url` göreli ("/hophop.apk") ya da mutlak (Drive/S3 adresi) olabilir;
  /// böylece APK'yı başka yere taşımak yalnızca version.json'ı değiştirmeyi gerektirir.
  static AppUpdate? tryParse(Map<String, dynamic> json) {
    final code = json['versionCode'];
    final url = json['url'];
    if (code is! int || url is! String || url.isEmpty) return null;
    return AppUpdate(
      versionCode: code,
      version: json['version'] as String? ?? '?',
      url: Uri.parse(apiBaseUrl).resolve(url),
      notes: (json['notes'] as String?)?.trim(),
      size: json['size'] as int?,
    );
  }

  String get sizeLabel =>
      size == null ? '' : '${(size! / 1024 / 1024).toStringAsFixed(1)} MB';
}

/// Uygulama içi güncelleme.
///
/// Uygulama mağazada olmadığı için Play'in güncelleme akışı kullanılamıyor:
/// sunucudaki `version.json` ile kurulu sürüm karşılaştırılır, yenisi varsa APK
/// indirilip **sistem yükleyicisine** devredilir. Kurulum onayını her zaman
/// kullanıcı verir; sessiz kurulum yapılmaz.
class UpdateService {
  static const _channel = MethodChannel('hophop/updater');

  /// Ana ekrandaki güncelleme kartı bunu dinler.
  static final available = ValueNotifier<AppUpdate?>(null);

  static ({int code, String name})? _installed;
  static DateTime? _lastCheck;

  /// Kurulu sürüm (Android paket bilgisinden — pubspec ile senkron kalma derdi yok).
  static Future<({int code, String name})?> installedVersion() async {
    if (_installed != null) return _installed;
    if (!Platform.isAndroid) return null;
    try {
      final r = await _channel.invokeMapMethod<String, dynamic>('versionInfo');
      if (r == null) return null;
      return _installed = (
        code: (r['code'] as num).toInt(),
        name: r['name'] as String? ?? '?',
      );
    } catch (_) {
      return null;
    }
  }

  /// Sunucuya sorar. Yeni sürüm varsa [available] dolar ve döner.
  ///
  /// [force] elle denetim içindir; otomatik çağrılar 6 saatte bir gerçekten ağa çıkar.
  static Future<AppUpdate?> check({bool force = false}) async {
    if (!Platform.isAndroid) return null;
    final last = _lastCheck;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < const Duration(hours: 6)) {
      return available.value;
    }
    final installed = await installedVersion();
    if (installed == null) return null;
    try {
      // Sorgu parametresi CDN önbelleğini dakikada bir tazeler.
      final uri = Uri.parse('$apiBaseUrl/version.json').replace(
          queryParameters: {
            't': '${DateTime.now().millisecondsSinceEpoch ~/ 60000}'
          });
      final res =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      if (body is! Map<String, dynamic>) return null;
      _lastCheck = DateTime.now();
      final update = AppUpdate.tryParse(body);
      available.value =
          (update != null && update.versionCode > installed.code) ? update : null;
      return available.value;
    } catch (_) {
      // Ağ yoksa ya da dosya henüz konmadıysa sessizce geç — güncelleme
      // denetimi hiçbir zaman uygulamanın önüne geçmemeli.
      return null;
    }
  }

  /// APK'yı önbelleğe indirir. [onProgress] 0..1 arası ilerleme verir.
  static Future<File> download(
    AppUpdate update, {
    void Function(double)? onProgress,
    CancelToken? cancel,
  }) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
    await dir.create(recursive: true);
    // Yarım kalmış/eski indirmeler birikmesin.
    for (final f in dir.listSync()) {
      if (f is File && !f.path.endsWith('hophop-${update.versionCode}.apk')) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }

    final target = File('${dir.path}/hophop-${update.versionCode}.apk');
    final temp = File('${target.path}.part');
    final client = http.Client();
    IOSink? sink;
    try {
      final res = await client.send(http.Request('GET', update.url));
      if (res.statusCode != 200) {
        throw HttpException('İndirme başarısız (${res.statusCode})');
      }
      final total = res.contentLength ?? update.size ?? 0;
      var received = 0;
      sink = temp.openWrite();
      await for (final chunk in res.stream) {
        if (cancel?.isCancelled ?? false) {
          throw const _Cancelled();
        }
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      // Yarım inen APK "bozuk paket" hatasıyla biter; baştan yakala.
      if (total > 0 && received != total) {
        throw const HttpException('İndirme yarım kaldı');
      }
      if (await target.exists()) await target.delete();
      return await temp.rename(target.path);
    } catch (_) {
      await sink?.close();
      if (await temp.exists()) await temp.delete();
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Android 8+: "bilinmeyen kaynaklardan kurulum" izni verilmiş mi?
  static Future<bool> canInstall() async {
    try {
      return await _channel.invokeMethod<bool>('canInstall') ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> openInstallSettings() async {
    try {
      await _channel.invokeMethod('openInstallSettings');
    } catch (_) {}
  }

  /// Sistem yükleyicisini açar; onayı kullanıcı verir.
  static Future<void> install(File apk) =>
      _channel.invokeMethod('install', {'path': apk.path});

  /// Ahize kipinde yakınlık sensörünü açar: telefon kulağa götürülünce ekran
  /// kapanır (yanak dokunuşları düğmelere basmasın). Hoparlör/görüntülü kipte
  /// kapatılır. Aynı platform kanalı kullanılır — ek eklenti yok.
  static Future<void> setProximity(bool on) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('proximity', {'on': on});
    } catch (_) {}
  }
}

/// İndirme iptali için minik bayrak (yeni bağımlılık getirmemek için elde yazıldı).
class CancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

class _Cancelled implements Exception {
  const _Cancelled();
  @override
  String toString() => 'İndirme iptal edildi';
}
