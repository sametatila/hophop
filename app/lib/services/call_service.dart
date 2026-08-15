import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

/// LiveKit oda bağlantısı — her zaman E2EE açık.
///
/// sharedKeyB64: CryptoService.deriveRoomKey ile iki tarafın da bağımsız
/// türettiği anahtar. Sunucuya asla gönderilmez; SFU medyayı çözemez.
class CallService {
  /// Video 720p'ye sabitlenir (LiveKit ücretsiz kota — plan §6).
  static Future<Room> connect({
    required String url,
    required String token,
    required String sharedKeyB64,
    required bool video,
  }) async {
    final keyProvider = await BaseKeyProvider.create();
    await keyProvider.setSharedKey(sharedKeyB64);

    final room = Room(
      roomOptions: RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultCameraCaptureOptions: const CameraCaptureOptions(
          params: VideoParametersPresets.h720_169,
        ),
        defaultVideoPublishOptions: VideoPublishOptions(
          videoEncoding: VideoParametersPresets.h720_169.encoding,
        ),
        defaultAudioPublishOptions: const AudioPublishOptions(dtx: true),
        e2eeOptions: E2EEOptions(keyProvider: keyProvider),
      ),
    );

    await room.connect(url, token);

    // ODAYA GİRMEK MİKROFONA/KAMERAYA BAĞLI DEĞİL.
    //
    // Eskiden bu iki çağrı doğrudan await ediliyordu ve biri hata verdiğinde
    // KURULMUŞ bağlantı çöpe gidip kullanıcıya "katılamadı" deniyordu. Kamera
    // devri özellikle MIUI'de kırılgan: arama ekranındaki önizleme kamerayı
    // yeni bırakmışken LiveKit'in hemen açması bazen başarısız oluyor.
    // Görüşmeye girmek her şeyden önemli; cihaz açılamazsa kullanıcı ekrandaki
    // düğmeden açar.
    await _tryEnable(
        () async => room.localParticipant?.setMicrophoneEnabled(true),
        'mikrofon');
    if (video) {
      await _tryEnable(
          () async => room.localParticipant?.setCameraEnabled(true), 'kamera');
    }
    return room;
  }

  /// Bir kez daha dener (kamera/mikrofon bırakılması birkaç yüz ms sürebiliyor),
  /// yine olmazsa sessizce geçer — bağlantı ayakta kalır.
  static Future<void> _tryEnable(
      Future<Object?> Function() run, String what) async {
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        await run();
        return;
      } catch (e) {
        debugPrint('HopHop: $what açılamadı (deneme $attempt): $e');
        if (attempt == 1) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
      }
    }
  }
}
