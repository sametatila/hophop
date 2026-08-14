import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config.dart';
import 'api_client.dart';

/// Profil fotoğraflarının kalıcı önbelleği.
///
/// Listeler artık fotoğrafı base64 olarak taşımıyor; yalnızca `photoVersion`
/// geliyor. Bayt hâli `/api/users/photo` adresinden bir kez indirilip diske
/// yazılıyor ve sürüm değişene dek bir daha indirilmiyor — her tazelemede
/// herkesin fotoğrafını yeniden çekmenin sonu.
///
/// Sürüm dosya adının parçası olduğu için geçersizleme kendiliğinden olur:
/// yeni sürüm = yeni dosya; eskisi silinir.
class PhotoCache {
  static final Map<String, Uint8List> _memory = {};
  static final Map<String, Future<Uint8List?>> _inFlight = {};
  static Directory? _dir;

  static String _key(String userId, int version) => '${userId}_$version';

  static Future<Directory> _photoDir() async {
    final cached = _dir;
    if (cached != null) return cached;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/photos');
    if (!await dir.exists()) await dir.create(recursive: true);
    return _dir = dir;
  }

  /// Bellekte varsa anında döner — çizim sırasında bekleme olmasın diye.
  static Uint8List? peek(String userId, int? version) =>
      version == null ? null : _memory[_key(userId, version)];

  /// Bellek → disk → ağ sırasıyla getirir. Ulaşılamazsa null (baş harfler çizilir).
  static Future<Uint8List?> load(String userId, int? version) async {
    if (version == null) return null;
    final key = _key(userId, version);
    final mem = _memory[key];
    if (mem != null) return mem;
    // Aynı fotoğraf için koşan birden çok istek tek indirmede birleşsin
    // (liste ekranlarında aynı avatar birkaç kez çizilebiliyor).
    return _inFlight[key] ??= _fetch(userId, version, key)
      ..whenComplete(() => _inFlight.remove(key));
  }

  static Future<Uint8List?> _fetch(
      String userId, int version, String key) async {
    final dir = await _photoDir();
    final file = File('${dir.path}/$key.jpg');
    try {
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        _memory[key] = bytes;
        return bytes;
      }
    } catch (_) {/* bozuk dosya → yeniden indir */}

    try {
      final res = await http.get(
        Uri.parse('$apiBaseUrl/api/users/photo?id=$userId&v=$version'),
        headers: api.authHeaders,
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
      _memory[key] = res.bodyBytes;
      await _writeAndPrune(dir, file, userId, res.bodyBytes);
      return res.bodyBytes;
    } catch (_) {
      return null; // çevrimdışı — baş harflerle idare edilir
    }
  }

  /// Yeni sürümü yazar, aynı kişinin eski sürümlerini siler.
  static Future<void> _writeAndPrune(
      Directory dir, File file, String userId, Uint8List bytes) async {
    try {
      await file.writeAsBytes(bytes, flush: true);
      await for (final f in dir.list()) {
        if (f is File &&
            f.path != file.path &&
            f.uri.pathSegments.last.startsWith('${userId}_')) {
          await f.delete().catchError((_) => f);
        }
      }
    } catch (_) {}
  }

  /// Kendi fotoğrafını yükledikten sonra: sunucudan geri indirmeden göster.
  static Future<void> prime(
      String userId, int version, Uint8List bytes) async {
    final key = _key(userId, version);
    _memory[key] = bytes;
    try {
      final dir = await _photoDir();
      await _writeAndPrune(dir, File('${dir.path}/$key.jpg'), userId, bytes);
    } catch (_) {}
  }
}
