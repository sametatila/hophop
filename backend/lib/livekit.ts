import { AccessToken } from 'livekit-server-sdk';

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
