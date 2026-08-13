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
  static const _storage = FlutterSecureStorage();
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

  /// İki taraf arasında bağlama özel simetrik anahtar türetir:
  /// ECDH(benim özel, karşının açık) → HKDF-SHA256(salt: context).
  Future<SecretKey> _pairwiseKey(String remotePublicKeyB64, String context) async {
    final kp = await _keyPair();
    final shared = await _x25519.sharedSecretKey(
      keyPair: kp,
      remotePublicKey:
          SimplePublicKey(base64Decode(remotePublicKeyB64), type: KeyPairType.x25519),
    );
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return hkdf.deriveKey(
      secretKey: shared,
      nonce: utf8.encode(context),
      info: utf8.encode('hophop-e2ee-v1'),
    );
  }

  final _aes = AesGcm.with256bits();

  Future<String> _sealWith(SecretKey key, List<int> plain) async {
    final box = await _aes.encrypt(plain, secretKey: key);
    return base64Encode(box.concatenation()); // nonce|cipher|mac
  }

  Future<List<int>> _openWith(SecretKey key, String sealedB64) async {
    final box = SecretBox.fromConcatenation(
      base64Decode(sealedB64),
      nonceLength: AesGcm.defaultNonceLength,
      macLength: 16,
    );
    return _aes.decrypt(box, secretKey: key);
  }

  /// Rastgele oda anahtarı (grup aramalar dahil) — arayan üretir,
  /// her katılımcıya o kişiye özel sarılmış (wrap) halde iletilir.
  String generateRoomKey() {
    final bytes = SecretKeyData.random(length: 32).bytes;
    return base64Encode(bytes);
  }

  /// Oda anahtarını karşı tarafa özel sarar. Sunucu bu değeri çözemez.
  Future<String> wrapRoomKey(
          String remotePublicKeyB64, String roomName, String roomKeyB64) =>
      _pairwiseKey(remotePublicKeyB64, 'wrap|$roomName')
          .then((k) => _sealWith(k, base64Decode(roomKeyB64)));

  /// Gelen sarılmış oda anahtarını açar.
  Future<String> unwrapRoomKey(
          String remotePublicKeyB64, String roomName, String wrappedB64) =>
      _pairwiseKey(remotePublicKeyB64, 'wrap|$roomName')
          .then((k) => _openWith(k, wrappedB64))
          .then(base64Encode);

  /// Mesajı uçtan uca şifreler — sunucuda yalnızca bu blob saklanır.
  Future<String> encryptMessage(
          String remotePublicKeyB64, String pairContext, String text) =>
      _pairwiseKey(remotePublicKeyB64, 'msg|$pairContext')
          .then((k) => _sealWith(k, utf8.encode(text)));

  Future<String> decryptMessage(
          String remotePublicKeyB64, String pairContext, String sealedB64) =>
      _pairwiseKey(remotePublicKeyB64, 'msg|$pairContext')
          .then((k) => _openWith(k, sealedB64))
          .then(utf8.decode);
}

final crypto = CryptoService();
