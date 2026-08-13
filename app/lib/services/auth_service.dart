import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import 'api_client.dart';

/// Oturum + yerel önbellek. Oturum JWT'si ve E2EE özel anahtarı
/// flutter_secure_storage (Android Keystore) içinde tutulur — tekrar giriş yok.
class AuthService {
  static const _storage = FlutterSecureStorage();

  static const _kToken = 'session_token';
  static const _kUser = 'me_profile';

  UserProfile? me;

  /// Uygulama açılışında çağrılır. true → oturum var, giriş ekranı atlanır.
  Future<bool> restore() async {
    final token = await _storage.read(key: _kToken);
    if (token == null) return false;
    api.setToken(token);
    final cached = await _storage.read(key: _kUser);
    if (cached != null) {
      me = UserProfile.fromJson(
          jsonDecode(cached) as Map<String, dynamic>, friendStatus: 'self');
    }
    // Arka planda tazele; ağ yoksa önbellekle devam.
    try {
      me = await api.me();
      await _storage.write(key: _kUser, value: jsonEncode(me!.toJson()));
    } on ApiException catch (e) {
      if (e.status == 401) {
        await logout();
        return false;
      }
    } catch (_) {/* çevrimdışı — önbellek yeterli */}
    return me != null;
  }

  Future<UserProfile> login(
      String firstName, String lastName, String birthDate) async {
    final r = await api.login(firstName, lastName, birthDate);
    api.setToken(r.token);
    me = r.user;
    await _storage.write(key: _kToken, value: r.token);
    await _storage.write(key: _kUser, value: jsonEncode(r.user.toJson()));
    return r.user;
  }

  Future<void> updateCachedMe(UserProfile user) async {
    me = user;
    await _storage.write(key: _kUser, value: jsonEncode(user.toJson()));
  }

  Future<void> logout() async {
    api.setToken(null);
    me = null;
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kUser);
  }

  // ---- Arkadaş listesi önbelleği (gelen arama ekranında fotoğraf için) ----

  static Future<File> _friendsCacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/friends_cache.json');
  }

  static Future<void> cacheFriends(List<UserProfile> friends) async {
    final f = await _friendsCacheFile();
    await f.writeAsString(jsonEncode(friends.map((u) => u.toJson()).toList()));
  }

  static Future<List<UserProfile>> cachedFriends() async {
    try {
      final f = await _friendsCacheFile();
      if (!await f.exists()) return [];
      final list = jsonDecode(await f.readAsString()) as List;
      return list
          .map((u) => UserProfile.fromJson(u as Map<String, dynamic>,
              friendStatus: 'friend'))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

final auth = AuthService();
