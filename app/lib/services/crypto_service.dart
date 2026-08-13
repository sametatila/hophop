import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// E2EE anahtar yönetimi.
///
/// Her cihaz bir X25519 anahtar çifti üretir; özel anahtar yalnızca cihazda
/// (Keystore destekli secure storage), açık anahtar sunucudaki profilde durur.
/// Oda anahtarı iki tarafın ECDH ortak sırrından HKDF ile türetilir ve hiçbir
/// sunucuya gönderilmez — LiveKit/Vercel/yönetici medyayı çözemez.
class CryptoService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _kPrivate = 'e2ee_private_seed';

  final _x25519 = X25519();

  /// Var olan anahtar çiftini yükler; yoksa üretir. Açık anahtarı (base64) döner.
  Future<String> ensureKeyPair() async {
    final kp = await _keyPair();
    final pub = await kp.extractPublicKey();
    return base64Encode(pub.bytes);
  }

  Future<SimpleKeyPair> _keyPair() async {
    final stored = await _storage.read(key: _kPrivate);
    if (stored != null) {
      return _x25519.newKeyPairFromSeed(base64Decode(stored));
    }
    final kp = await _x25519.newKeyPair();
    final seed = await kp.extractPrivateKeyBytes();
    await _storage.write(key: _kPrivate, value: base64Encode(seed));
    return kp;
  }

  /// Oda anahtarı: ECDH(benim özel, karşının açık) → HKDF-SHA256(salt: odaAdı).
  /// İki taraf da aynı değeri türetir; base64 olarak LiveKit key provider'a verilir.
  Future<String> deriveRoomKey(String remotePublicKeyB64, String roomName) async {
    final kp = await _keyPair();
    final shared = await _x25519.sharedSecretKey(
      keyPair: kp,
      remotePublicKey:
          SimplePublicKey(base64Decode(remotePublicKeyB64), type: KeyPairType.x25519),
    );
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final derived = await hkdf.deriveKey(
      secretKey: shared,
      nonce: utf8.encode(roomName),
      info: utf8.encode('hophop-e2ee-v1'),
    );
    return base64Encode(await derived.extractBytes());
  }
}

final crypto = CryptoService();
