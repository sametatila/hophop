#!/usr/bin/env bash
# HopHop — yayın imzalama anahtarı üretir (bir kez çalıştırılır).
#
#   cd app && ./make-release-key.sh
#
# Ürettikleri:
#   android/hophop-release.jks   → imzalama anahtarı (GİZLİ, .gitignore'da)
#   android/key.properties       → gradle'ın okuduğu ayar (GİZLİ, .gitignore'da)
#
# ⚠ Bu iki dosyayı KAYBETME. Kaybedersen yeni sürümler kurulu uygulamanın üstüne
#   kurulamaz; herkes uygulamayı silip yeniden kurmak (ve yeniden giriş yapmak)
#   zorunda kalır. Şifre yöneticine yedekle.
set -euo pipefail

cd "$(dirname "$0")"
KEYSTORE="android/hophop-release.jks"
PROPS="android/key.properties"
ALIAS="hophop"

# keytool: PATH'te yoksa Android Studio'nun JDK'sında ara.
# DİKKAT: set -u açık — tanımsız olabilecek değişkenler ${VAR:-} ile okunur.
KEYTOOL="$(command -v keytool || true)"
if [ -z "$KEYTOOL" ]; then
  for c in "${JAVA_HOME:-}/bin/keytool" /opt/android-studio/jbr/bin/keytool \
           "${HOME:-}/android-studio/jbr/bin/keytool" /usr/lib/jvm/*/bin/keytool; do
    if [ -x "$c" ]; then KEYTOOL="$c"; break; fi
  done
fi
[ -n "$KEYTOOL" ] || { echo "✗ keytool bulunamadı. JDK ya da Android Studio kurulu mu?"; exit 1; }

if [ -f "$KEYSTORE" ]; then
  echo "✓ $KEYSTORE zaten var — üzerine yazmıyorum."
  echo "  Gerçekten yenilemek istiyorsan önce dosyayı elle taşı/sil."
  exit 0
fi

echo "HopHop yayın anahtarı üretilecek."
echo "Bir parola belirle (en az 6 karakter). Bunu şifre yöneticine kaydet —"
echo "her yeni sürümü derlerken gerekmeyecek ama anahtarı taşırken gerekecek."
echo
read -rsp "Parola: " PW1; echo
read -rsp "Parola (tekrar): " PW2; echo
[ "$PW1" = "$PW2" ] || { echo "✗ Parolalar aynı değil."; exit 1; }
[ ${#PW1} -ge 6 ] || { echo "✗ Parola en az 6 karakter olmalı."; exit 1; }

"$KEYTOOL" -genkeypair -v \
  -keystore "$KEYSTORE" \
  -alias "$ALIAS" \
  -keyalg RSA -keysize 2048 \
  -validity 10000 \
  -storetype JKS \
  -storepass "$PW1" -keypass "$PW1" \
  -dname "CN=HopHop, OU=Family, O=HopHop, L=-, ST=-, C=TR" >/dev/null

umask 077
cat > "$PROPS" <<EOF
# HopHop yayın imzası — GİZLİ, repoya girmez (.gitignore).
storeFile=$(cd android && pwd)/hophop-release.jks
storePassword=$PW1
keyAlias=$ALIAS
keyPassword=$PW1
EOF
chmod 600 "$PROPS" "$KEYSTORE"

echo
echo "✓ $KEYSTORE üretildi"
echo "✓ $PROPS yazıldı (600)"
echo
echo "Sıradaki: flutter build apk --release"
echo "Doğrula (anahtar parmak izi debug'dan farklı olmalı):"
echo "  \"$KEYTOOL\" -list -v -keystore $KEYSTORE -alias $ALIAS"
echo
echo "⚠ hophop-release.jks + key.properties dosyalarını şifre yöneticine yedekle."
