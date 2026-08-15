import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import '../theme/hop_theme.dart';
import 'api_client.dart';
import 'crypto_service.dart';
import 'ring_listener.dart';

/// Oturum + yerel önbellek. Oturum JWT'si ve E2EE özel anahtarı
/// flutter_secure_storage (Android Keystore) içinde tutulur — tekrar giriş yok.
class AuthService {
  static const _storage = FlutterSecureStorage();

  static const _kToken = 'session_token';
  static const _kUser = 'me_profile';

  UserProfile? me;

  /// Arka plan isolate'i için: oturum token'ını doğrudan okur.
  static Future<String?> readToken() => _storage.read(key: _kToken);

  /// Arka plan isolate'i için: oturumdaki kullanıcının kimliği.
  /// Gelen bildirimin bu cihazdaki hesaba ait olup olmadığı buradan denetlenir.
  static Future<String?> readUserId() async {
    try {
      final cached = await _storage.read(key: _kUser);
      if (cached == null) return null;
      return (jsonDecode(cached) as Map<String, dynamic>)['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Uygulama açılışında çağrılır. true → oturum var, giriş ekranı atlanır.
  Future<bool> restore() async {
    final token = await _storage.read(key: _kToken);
    if (token == null) return false;
    api.setToken(token);
    final cached = await _storage.read(key: _kUser);
    if (cached != null) {
      me = UserProfile.fromJson(
          jsonDecode(cached) as Map<String, dynamic>, friendStatus: 'self');
      crypto.bindUser(me?.id); // E2EE anahtarı kullanıcı başına saklanıyor
      appMode.value = modeForBirthDate(me?.birthDate);
    }
    // Arka planda tazele; ağ yoksa önbellekle devam.
    try {
      me = await api.me();
      crypto.bindUser(me?.id);
      appMode.value = modeForBirthDate(me?.birthDate);
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
    crypto.bindUser(r.user.id);
    appMode.value = modeForBirthDate(r.user.birthDate);
    await _storage.write(key: _kToken, value: r.token);
    await _storage.write(key: _kUser, value: jsonEncode(r.user.toJson()));
    return r.user;
  }

  Future<void> updateCachedMe(UserProfile user) async {
    me = user;
    await _storage.write(key: _kUser, value: jsonEncode(user.toJson()));
  }

  /// Tam çıkış: cihaz sistemden düşürülür ve yerel izler temizlenir.
  /// - FCM token sunucudan silinir (eski cihaza arama/mesaj GİTMEZ)
  /// - Firebase oturumu ve zil dinleyicisi kapatılır
  /// - Çözülmüş sohbet önbellekleri ve etkinlik dosyaları diskten silinir
  Future<void> logout() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await api.updateMe(removeFcmToken: token);
    } catch (_) {/* ağ yoksa sunucuda kalır — aşağıdaki silme yine korur */}
    try {
      // Token'ı CİHAZDAN da iptal et. Sunucudan silme başarısız olsa bile bu
      // kayıt geçersizleşir; eski hesaba gönderilen push artık bu cihaza
      // ulaşmaz ve sunucu ölü token'ı ilk denemede temizler. Yeni girişte
      // taze bir token üretilir.
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    await RingListener.stop();
    try {
      final dir = await getApplicationDocumentsDirectory();
      for (final f in dir.listSync()) {
        final name = f.uri.pathSegments.last;
        if (name.startsWith('chat_') ||
            name == 'friends_cache.json' ||
            name == 'last_read.json' ||
            name == 'missed_calls.json' ||
            name == 'last_activity.json') {
          await f.delete();
        }
      }
    } catch (_) {}
    api.setToken(null);
    crypto.bindUser(null);
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
