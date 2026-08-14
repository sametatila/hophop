import { AccessToken, RoomServiceClient } from 'livekit-server-sdk';

function roomService(): RoomServiceClient {
  return new RoomServiceClient(
    livekitUrl().replace('wss://', 'https://'),
    process.env.LIVEKIT_API_KEY,
    process.env.LIVEKIT_API_SECRET,
  );
}

/** Odadaki mevcut katılımcı sayısı (oda yoksa 0). Grup sınırı denetimi için. */
export async function participantCount(roomName: string): Promise<number> {
  try {
    return (await roomService().listParticipants(roomName)).length;
  } catch {
    return 0; // oda henüz oluşmamış
  }
}

/** Odadaki katılımcıların adları — davet edilene "kimler var" diyebilmek için.
 * Ad, token üretilirken yazılan görünen addır; yoksa kimlik kullanılır. */
export async function participantNames(roomName: string): Promise<string[]> {
  try {
    const list = await roomService().listParticipants(roomName);
    return list.map((p) => p.name || p.identity).filter(Boolean);
  } catch {
    return [];
  }
}

export async function roomToken(roomName: string, userId: string, name: string): Promise<string> {
  const apiKey = process.env.LIVEKIT_API_KEY;
  const apiSecret = process.env.LIVEKIT_API_SECRET;
  if (!apiKey || !apiSecret) throw new Error('LIVEKIT_API_KEY / LIVEKIT_API_SECRET missing');
  const at = new AccessToken(apiKey, apiSecret, {
    identity: userId,
    name,
    ttl: '2h',
  });
  at.addGrant({ roomJoin: true, room: roomName, canPublish: true, canSubscribe: true, canPublishData: true });
  return at.toJwt();
}

export function livekitUrl(): string {
  const url = process.env.LIVEKIT_URL;
  if (!url) throw new Error('LIVEKIT_URL missing');
  return url;
}
