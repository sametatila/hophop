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
    await room.localParticipant?.setMicrophoneEnabled(true);
    if (video) {
      await room.localParticipant?.setCameraEnabled(true);
    }
    return room;
  }
}
