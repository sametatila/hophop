import { db, messaging } from './firebase.js';
import { FieldValue } from 'firebase-admin/firestore';

/** Bir gönderimin sonucu — arayan tarafa "ulaşabildik mi?" diyebilmek için.
 * devices: kayıtlı cihaz sayısı (0 = kişi uygulamayı hiç açmamış ya da
 * bildirim izni yok), delivered: FCM'in kabul ettiği gönderim sayısı. */
export type PushResult = { devices: number; delivered: number };

/** Sends a high-priority data-only message to every device of a user.
 * Invalid/expired tokens are pruned from the user document. */
export async function pushToUser(
  userId: string,
  data: Record<string, string>,
): Promise<PushResult> {
  const snap = await db().collection('users').doc(userId).get();
  const tokens: string[] = snap.get('fcmTokens') ?? [];
  if (tokens.length === 0) return { devices: 0, delivered: 0 };

  // 'to': bildirimin KİME ait olduğu. Cihazda hesap değiştirildiğinde eski
  // hesabın token'ı (silinmesi başarısız olduysa) hâlâ bu cihaza düşebiliyor;
  // istemci bu alana bakıp kendisine ait olmayan bildirimi atıyor.
  const payload = { ...data, to: userId };

  const results = await Promise.allSettled(
    tokens.map((token) =>
      messaging().send({
        token,
        data: payload,
        android: { priority: 'high', ttl: 45_000 },
      }),
    ),
  );

  const dead = tokens.filter((_, i) => {
    const r = results[i];
    if (r.status === 'fulfilled') return false;
    const code = (r.reason?.errorInfo?.code ?? r.reason?.code ?? '') as string;
    return (
      code.includes('registration-token-not-registered') ||
      code.includes('invalid-argument') ||
      code.includes('invalid-registration-token')
    );
  });
  if (dead.length > 0) {
    await snap.ref.update({ fcmTokens: FieldValue.arrayRemove(...dead) });
  }

  return {
    devices: tokens.length,
    delivered: results.filter((r) => r.status === 'fulfilled').length,
  };
}
