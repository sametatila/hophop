#!/usr/bin/env python3
"""HopHop — görüşme sesleri üretir (bağımlılıksız, yalnızca stdlib).

    python3 tools/make_call_tones.py

Üretilenler (assets/sounds/):
  ringback.wav  giden aramada "aranıyor" tonu — döngüye alınır
  connect.wav   görüşme kurulduğunda kısa yükselen iki nota
  end.wav       görüşme bittiğinde kısa alçalan iki nota

NEDEN ÜRETİLİYOR: hazır ses dosyaları lisans taşır ve depoya ikili dosya
eklemek gerekir. Ton üretmek birkaç satır; kaynağı burada durunca sesi
değiştirmek de (frekans/süre) tek satırlık bir iş oluyor.

Ton seçimi: 425 Hz, Türkiye'nin (ve ETSI'nin) santral zil geri dönüş tonu —
kullanıcıya "telefon çalıyor" hissini veren tanıdık ses budur.
"""
import math
import struct
import wave
from pathlib import Path

RATE = 16000  # 425 Hz'lik bir ton için fazlasıyla yeterli, dosya küçük kalır
OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"


def tone(freq: float, seconds: float, amp: float = 0.35) -> list[float]:
    """Tek frekanslı ton. Uçlarda 8 ms'lik rampa var: onsuz her başlangıç ve
    bitiş "tık" diye duyuluyor (dalga sıfırdan kopunca oluşan tıkırtı)."""
    n = int(RATE * seconds)
    ramp = max(1, int(RATE * 0.008))
    out = []
    for i in range(n):
        v = amp * math.sin(2 * math.pi * freq * i / RATE)
        if i < ramp:
            v *= i / ramp
        elif i > n - ramp:
            v *= (n - i) / ramp
        out.append(v)
    return out


def silence(seconds: float) -> list[float]:
    return [0.0] * int(RATE * seconds)


def write(name: str, samples: list[float]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(
            b"".join(
                struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767))
                for s in samples
            )
        )
    print(f"✓ {path.relative_to(OUT.parent.parent)}  "
          f"({path.stat().st_size / 1024:.0f} KB)")


# Zil geri dönüş tonu: 1.5 sn ses + 2.5 sn sessizlik, kesintisiz döngüye uygun.
# Standart 2/4 sn yerine biraz kısaltıldı — 4 saniyelik sessizlik "arama
# düştü mü?" hissi veriyordu.
write("ringback.wav", tone(425, 1.5) + silence(2.5))

# Kuruldu: kısa, yükselen iki nota — "bağlandık".
write("connect.wav", tone(660, 0.08, 0.3) + silence(0.03) + tone(880, 0.12, 0.3))

# Bitti: aynı iki nota tersten — "kapandı".
write("end.wav", tone(660, 0.10, 0.3) + silence(0.03) + tone(440, 0.16, 0.3))
